import 'package:flutter_test/flutter_test.dart';
import 'package:growza/email_validation.dart';

void main() {
  test('Rejects commas, spaces, malformed domains and dot placement', () {
    for (final email in [
      'adsad@gk.co,',
      'a,b@example.com',
      'a b@example.com',
      'a@example.com;',
      'a@@example.com',
      'a@domain',
      'a@domain..com',
      'a@-domain.com',
      'a@domain-.com',
      'a@do_main.com',
      'a@domain.123',
      '.a@example.com',
      'a.@example.com',
      'a..b@example.com',
      'a@.com',
      'a@example.com/path',
      'a@example.com\nBcc:other@example.com',
      '${'a' * 65}@example.com',
      'a@${'b' * 64}.com',
    ]) {
      expect(isValidAccountEmail(email), false, reason: email);
    }
  });
  test(
    'Accepts valid syntax without restricting providers or asserting existence',
    () {
      for (final email in [
        'adsad@gk.co',
        'student@gmail.com',
        'student@outlook.com',
        'first.last+study@sub.university.edu.sa',
        ' Student@Example.COM ',
        'a_b-c@department.example.co.uk',
        "o'connor@example.com",
      ]) {
        expect(isValidAccountEmail(email), true, reason: email);
      }
    },
  );
}
