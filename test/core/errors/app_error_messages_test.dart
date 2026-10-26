import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/core/errors/app_error_messages.dart';

const List<String> _knownCodes = [
  'REQUEST_LIMIT_REACHED',
  'CYCLE_DETECTED',
  'HAS_DESCENDANTS',
  'BRANCH_NOT_EMPTY',
  'ALREADY_REVIEWED',
  'REQUEST_NOT_FOUND',
  'ENTITY_NOT_FOUND',
  'FORBIDDEN',
  'INVALID_PAYLOAD_KEY',
  'INVALID_PAYLOAD',
  'EMPTY_PAYLOAD',
  'INVALID_ACTION',
  'PHOTO_FILE_MISSING',
];

String _msgOf(String code) {
  return vietnameseErrorMessage(PostgrestException(message: code));
}

void main() {
  group('13 mã lỗi đã biết', () {
    for (final code in _knownCodes) {
      test(code, () {
        final msg = vietnameseErrorMessage(
          PostgrestException(message: code, code: 'P0001'),
        );
        expect(msg, isNotEmpty);
        expect(msg, isNot(kGenericErrorMessage));
        expect(msg, isNot(kNetworkErrorMessage));
      });
    }

    test('13 câu khác nhau từng đôi một', () {
      final messages = _knownCodes.map(_msgOf).toSet();
      expect(messages.length, _knownCodes.length);
    });

    test('INVALID_PAYLOAD_KEY không bị nhầm với INVALID_PAYLOAD', () {
      expect(_msgOf('INVALID_PAYLOAD_KEY'), isNot(_msgOf('INVALID_PAYLOAD')));
    });
  });

  group('cách mã lỗi xuất hiện trong lỗi', () {
    test('mã nằm giữa câu dài', () {
      final msg = vietnameseErrorMessage(
        PostgrestException(message: 'ERROR: CYCLE_DETECTED: ancestor loop'),
      );
      expect(msg, _msgOf('CYCLE_DETECTED'));
    });

    test('mã nằm trong details', () {
      final msg = vietnameseErrorMessage(
        PostgrestException(message: 'Có lỗi', details: 'HAS_DESCENDANTS'),
      );
      expect(msg, _msgOf('HAS_DESCENDANTS'));
    });

    test('mã Postgres 42501 (RLS chặn) -> câu FORBIDDEN', () {
      final msg = vietnameseErrorMessage(
        PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      );
      expect(msg, _msgOf('FORBIDDEN'));
    });
  });

  group('mã lạ', () {
    test('mã lạ -> câu chung', () {
      final msg = vietnameseErrorMessage(
        PostgrestException(message: 'SOMETHING_WEIRD'),
      );
      expect(msg, kGenericErrorMessage);
    });

    test('lỗi bất kỳ -> câu chung', () {
      expect(vietnameseErrorMessage(Exception('boom')), kGenericErrorMessage);
    });
  });

  group('lỗi mạng', () {
    test('SocketException', () {
      expect(
        vietnameseErrorMessage(const SocketException('Failed host lookup')),
        kNetworkErrorMessage,
      );
    });

    test('TimeoutException', () {
      expect(
        vietnameseErrorMessage(TimeoutException('quá hạn')),
        kNetworkErrorMessage,
      );
    });

    test('ClientException dạng chữ', () {
      expect(
        vietnameseErrorMessage(
          Exception('ClientException with SocketException: Failed host lookup'),
        ),
        kNetworkErrorMessage,
      );
    });
  });
}