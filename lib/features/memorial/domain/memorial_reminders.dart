import 'package:familytree/features/memorial/domain/upcoming_memorials.dart';
import 'package:familytree/features/person/domain/memorial_labels.dart';
import 'package:familytree/features/person/domain/person.dart';

/// Nhắc trước ngày giỗ bao nhiêu ngày.
const int kMemorialReminderLeadDays = 3;

/// Giờ nhắc (giờ Việt Nam): buổi tối muộn nhưng KHÔNG quá 21:00.
const int kMemorialReminderHour = 20;
const int kMemorialReminderMinute = 30;

/// Tối đa số lịch nhắc cùng lúc (máy Samsung giới hạn khoảng 500 báo thức).
const int kMaxMemorialReminders = 60;

/// Việt Nam là UTC+7, không có giờ mùa hè.
const int kVietnamUtcOffsetHours = 7;

/// Lịch nhắc phải cách bây giờ ít nhất chừng này mới được đặt.
const Duration kMemorialReminderMinLead = Duration(minutes: 1);

/// Dải mã thông báo dành riêng cho nhắc giỗ, để chỉ hủy đúng các nhắc này
/// (không đụng thông báo đề xuất, vốn dùng mã lớn hơn nhiều).
const int kMemorialReminderIdBase = 1000000;
const int kMemorialReminderIdLimit = 2000000;
const int kMemorialTestReminderId = kMemorialReminderIdLimit - 1;

const String kMemorialChannelId = 'memorial_reminders';
const String kMemorialChannelName = 'Nhắc ngày giỗ';
const String kMemorialChannelDescription = 'Nhắc trước ngày giỗ trong dòng họ';

const String kMemorialReminderTitle = 'Sắp đến ngày giỗ';

/// Bấm vào nhắc thì mở màn Ngày giỗ.
const String kMemorialReminderPayload = '/memorials';

/// Một lần nhắc đã lên kế hoạch. Nội dung KHÔNG chứa tên người.
class MemorialReminder {
  const MemorialReminder({
    required this.id,
    required this.fireAtVietnam,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;

  /// Thời điểm nhắc theo giờ Việt Nam (chỉ là ngày giờ trên đồng hồ tường).
  final DateTime fireAtVietnam;

  final String title;
  final String body;
  final String payload;

  /// Cùng thời điểm đó quy ra giờ UTC (để hẹn giờ không cần dữ liệu múi giờ).
  DateTime get fireAtUtc {
    return DateTime.utc(
      fireAtVietnam.year,
      fireAtVietnam.month,
      fireAtVietnam.day,
      fireAtVietnam.hour - kVietnamUtcOffsetHours,
      fireAtVietnam.minute,
    );
  }
}

/// Mã có thuộc dải nhắc giỗ hay không.
bool isMemorialReminderId(int id) {
  return id >= kMemorialReminderIdBase && id < kMemorialReminderIdLimit;
}

/// Mã nhắc cho một ngày giỗ: mỗi ngày dương lịch một mã duy nhất.
int memorialReminderIdFor(DateTime memorialDate) {
  final days = DateTime.utc(
    memorialDate.year,
    memorialDate.month,
    memorialDate.day,
  ).difference(DateTime.utc(1970)).inDays;
  return kMemorialReminderIdBase + days;
}

/// Đồng hồ tường ở Việt Nam tại thời điểm [now].
DateTime vietnamWallClock(DateTime now) {
  final shifted = now.toUtc().add(
    const Duration(hours: kVietnamUtcOffsetHours),
  );
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
  );
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Ngày dương lịch dạng dd/MM/yyyy.
String formatReminderSolarDate(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String _bodyFor(UpcomingMemorial item) {
  final lunar = formatMemorialLunar(
    day: item.lunarDay,
    month: item.lunarMonth,
    isLeap: item.isLeap,
  );
  final solar = formatReminderSolarDate(item.date);
  return 'Còn $kMemorialReminderLeadDays ngày nữa là ngày giỗ: $lunar, '
      'tức ngày $solar dương lịch.';
}

/// Lập danh sách nhắc từ dữ liệu người trong dòng họ.
/// - [nowVietnam]: đồng hồ tường Việt Nam hiện tại (xem [vietnamWallClock]).
/// - Mỗi NGÀY giỗ chỉ một lần nhắc, dù có nhiều người cùng ngày.
/// - Lần nhắc đã qua (hoặc sắp tới trong vòng 1 phút) thì bỏ.
/// - Kết quả xếp theo thời điểm nhắc tăng dần, tối đa [kMaxMemorialReminders].
List<MemorialReminder> planMemorialReminders({
  required List<Person> people,
  required DateTime nowVietnam,
}) {
  final upcoming = buildUpcomingMemorials(
    people: people,
    today: nowVietnam,
    withinDays: kMemorialLookaheadDays + kMemorialReminderLeadDays,
  );

  final seenIds = <int>{};
  final reminders = <MemorialReminder>[];
  for (final item in upcoming.items) {
    final id = memorialReminderIdFor(item.date);
    if (!seenIds.add(id)) {
      continue;
    }
    final fireAt = DateTime(
      item.date.year,
      item.date.month,
      item.date.day - kMemorialReminderLeadDays,
      kMemorialReminderHour,
      kMemorialReminderMinute,
    );
    if (!fireAt.isAfter(nowVietnam.add(kMemorialReminderMinLead))) {
      continue;
    }
    reminders.add(
      MemorialReminder(
        id: id,
        fireAtVietnam: fireAt,
        title: kMemorialReminderTitle,
        body: _bodyFor(item),
        payload: kMemorialReminderPayload,
      ),
    );
    if (reminders.length >= kMaxMemorialReminders) {
      break;
    }
  }
  return reminders;
}
