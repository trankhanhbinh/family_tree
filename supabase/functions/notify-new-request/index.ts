// supabase/functions/notify-new-request/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const MAX_BUNDLES = 20;
const MAX_NICKNAME_CHARS = 30;
const FALLBACK_NICKNAME = "Một người đóng góp";

type Bundle = { nickname: string; count: number };

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type SendResult = {
  ok: boolean;
  status: number;
  code: string;
  dead: boolean;
};

let cachedToken: { value: string; expiresAt: number } | null = null;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function safeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const x = encoder.encode(a);
  const y = encoder.encode(b);
  if (x.length !== y.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < x.length; i++) {
    diff |= x[i] ^ y[i];
  }
  return diff === 0;
}

function base64ToBytes(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function textToBase64Url(text: string): string {
  return bytesToBase64Url(new TextEncoder().encode(text));
}

function loadServiceAccount(): ServiceAccount {
  const b64 = Deno.env.get("FCM_SERVICE_ACCOUNT_B64");
  if (!b64) {
    throw new Error("Thiếu secret FCM_SERVICE_ACCOUNT_B64");
  }
  const parsed = JSON.parse(new TextDecoder().decode(base64ToBytes(b64.trim())));
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("Service account thiếu trường bắt buộc");
  }
  return parsed as ServiceAccount;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  return await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(body),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const nowMs = Date.now();
  if (cachedToken && cachedToken.expiresAt > nowMs + 60_000) {
    return cachedToken.value;
  }
  const iat = Math.floor(nowMs / 1000);
  const header = textToBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = textToBase64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: FCM_SCOPE,
      aud: TOKEN_URL,
      iat,
      exp: iat + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const key = await importPrivateKey(account.private_key);
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${bytesToBase64Url(signature)}`;

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    throw new Error(`Không lấy được access token (HTTP ${response.status})`);
  }
  const data = await response.json();
  const expiresInSeconds = Number(data.expires_in) || 3000;
  cachedToken = {
    value: data.access_token as string,
    expiresAt: nowMs + expiresInSeconds * 1000,
  };
  return cachedToken.value;
}

function createAdminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  let key: string | undefined;
  const keysJson = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (keysJson) {
    try {
      key = JSON.parse(keysJson)["default"];
    } catch {
      key = undefined;
    }
  }
  key ??= Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Thiếu SUPABASE_URL hoặc khóa server");
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

function parseBundles(payload: unknown): Bundle[] | null {
  if (typeof payload !== "object" || payload === null) {
    return null;
  }
  const raw = (payload as { bundles?: unknown }).bundles;
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_BUNDLES) {
    return null;
  }
  const bundles: Bundle[] = [];
  for (const item of raw) {
    if (typeof item !== "object" || item === null) {
      return null;
    }
    const nicknameRaw = (item as { nickname?: unknown }).nickname;
    const countRaw = (item as { count?: unknown }).count;
    const trimmed = typeof nicknameRaw === "string" ? nicknameRaw.trim() : "";
    const nickname = trimmed === ""
      ? FALLBACK_NICKNAME
      : Array.from(trimmed).slice(0, MAX_NICKNAME_CHARS).join("");
    const count =
      typeof countRaw === "number" && Number.isInteger(countRaw) &&
        countRaw >= 1 && countRaw <= 1000
        ? countRaw
        : 1;
    bundles.push({ nickname, count });
  }
  return bundles;
}

async function sendOne(
  projectId: string,
  accessToken: string,
  fid: string,
  title: string,
  body: string,
): Promise<SendResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          fid,
          notification: { title, body },
          data: { route: "/admin/requests" },
          android: { priority: "HIGH" },
        },
      }),
      signal: AbortSignal.timeout(10_000),
    },
  );
  if (response.ok) {
    return { ok: true, status: response.status, code: "OK", dead: false };
  }
  let code = "UNKNOWN";
  let dead = false;
  try {
    const errorBody = await response.json();
    code = String(errorBody?.error?.status ?? "UNKNOWN");
    const details = errorBody?.error?.details;
    if (Array.isArray(details)) {
      for (const detail of details) {
        if (detail?.errorCode === "UNREGISTERED") {
          code = "UNREGISTERED";
          dead = true;
        }
      }
    }
  } catch {
    // Giữ nguyên code = UNKNOWN.
  }
  // Chỉ coi là "FID đã chết" khi FCM nói rõ UNREGISTERED: lỗi cấu hình
  // (sai project, thiếu quyền...) không được làm mất dòng trong admin_devices.
  return { ok: false, status: response.status, code, dead };
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const expected = Deno.env.get("WEBHOOK_TOKEN") ?? "";
  const given = req.headers.get("x-webhook-token") ?? "";
  if (expected === "" || !safeEqual(given, expected)) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const bundles = parseBundles(payload);
  if (bundles === null) {
    return json({ error: "invalid_payload" }, 400);
  }

  try {
    const supabase = createAdminClient();
    const { data: rows, error } = await supabase
      .from("admin_devices")
      .select("fcm_token");
    if (error) {
      throw new Error(`Không đọc được admin_devices: ${error.message}`);
    }
    const fids = (rows ?? [])
      .map((row) => String(row.fcm_token ?? ""))
      .filter((fid) => fid.length > 0);

    const summary = {
      devices: fids.length,
      sent: 0,
      failed: 0,
      removed: 0,
      errors: [] as { status: number; code: string }[],
    };
    if (fids.length === 0) {
      return json(summary);
    }

    const account = loadServiceAccount();
    const accessToken = await getAccessToken(account);
    const dead = new Set<string>();

    for (const bundle of bundles) {
      const body = `${bundle.nickname} gửi ${bundle.count} thay đổi, bấm để xem`;
      const targets = fids.filter((fid) => !dead.has(fid));
      const results = await Promise.all(
        targets.map(async (fid) => ({
          fid,
          result: await sendOne(
            account.project_id,
            accessToken,
            fid,
            "Có đề xuất mới",
            body,
          ),
        })),
      );
      for (const { fid, result } of results) {
        if (result.ok) {
          summary.sent++;
          continue;
        }
        summary.failed++;
        if (result.dead) {
          dead.add(fid);
        }
        const known = summary.errors.some(
          (e) => e.status === result.status && e.code === result.code,
        );
        if (!known) {
          summary.errors.push({ status: result.status, code: result.code });
        }
      }
    }

    if (dead.size > 0) {
      const { error: deleteError } = await supabase
        .from("admin_devices")
        .delete()
        .in("fcm_token", [...dead]);
      if (deleteError) {
        console.error("Không xóa được FID chết:", deleteError.message);
      } else {
        summary.removed = dead.size;
      }
    }

    return json(summary);
  } catch (error) {
    console.error(
      "notify-new-request lỗi:",
      error instanceof Error ? error.message : String(error),
    );
    return json({ error: "internal" }, 500);
  }
});