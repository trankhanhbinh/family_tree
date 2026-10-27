import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familytree/core/errors/app_error_messages.dart';

void main() {
  test('lỗi khóa ngoại 23503 -> câu "dữ liệu liên quan không còn"', () {
    const error = PostgrestException(
      message: 'insert or update on table "parent_child" violates '
          'foreign key constraint',
      code: '23503',
    );
    expect(vietnameseErrorMessage(error), kRelatedDataMissingMessage);
  });
}