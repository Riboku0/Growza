import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:growza/study_database.dart';
import 'package:growza/study_storage.dart';
import 'package:growza/study_data.dart';
import 'package:growza/focus_timer.dart';
import 'package:growza/pdf_topics.dart';
import 'package:growza/account_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native SQLite, PDF extraction, secure vault and resumed focus smoke',
    (t) async {
      expect(
        const bool.fromEnvironment('GROWZA_VERIFICATION'),
        true,
        reason: 'Only use the isolated verification package',
      );
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Growza Verification'))),
      );
      final folder = await getApplicationSupportDirectory();
      final path = '${folder.path}/sqlite-smoke.db';
      await deleteDatabase(path);
      var store = StudyDatabase(path: path);
      final subject = StudySubject('Legacy subject', DateTime(2026, 12, 1), [
        const StudyPart(1, 'Topic', 25),
      ], id: 'legacy-subject');
      final start = DateTime.now();
      final timer = FocusTimer(
        focusLength: const Duration(minutes: 25),
        subjectId: subject.id,
        now: () => start,
        onFocusCompleted: () {},
      );
      timer.toggle();
      final old = StudyWorkspace(
        subjects: [subject],
        activeTimer: {
          'timer': timer.toJson(),
          'session': StudySession(
            subject.name,
            'Topic',
            start,
            25,
            partId: 1,
          ).toJson(),
        },
      );
      timer.dispose();
      final legacy = File('${folder.path}/sqlite-smoke-legacy.json');
      await legacy.writeAsString(const StudyStorage().encode(old));
      final original = await legacy.readAsString();
      String normalize(String? text) =>
          const StudyStorage().encode(const StudyStorage().decode(text!));
      final migrated = await store.readOrMigrate(
        readLegacy: legacy.readAsString,
        normalize: normalize,
      );
      await store.close();
      store = StudyDatabase(path: path);
      expect(
        await store.readOrMigrate(
          readLegacy: () async => throw StateError('must not remigrate'),
          normalize: normalize,
        ),
        migrated,
      );
      expect(await legacy.readAsString(), original);
      final saved = const StudyStorage().decode(migrated);
      final resumed = FocusTimer.restore(
        Map<String, dynamic>.from(saved.activeTimer!['timer']),
        subjectId: subject.id,
        now: () => start.add(const Duration(minutes: 6)),
        onFocusCompleted: () {},
      );
      resumed.refresh();
      final record = resumed.finishFocus();
      expect(record?.focused.inMinutes, 6);
      resumed.dispose();
      await store.close();
      const vault = SecureSessionVault();
      await vault.write('verification-only');
      expect(await vault.read(), 'verification-only');
      await vault.clear();
      expect(await vault.read(), isNull);
      final bookmarks = await extractPdfHeadings(
        base64Decode(bookmarksFixture),
      );
      expect(bookmarks.pageCount, 2);
      expect(bookmarks.text, contains('[1] Integration'));
      expect(bookmarks.text, contains('[2] Applications'));
      final text = await extractPdfHeadings(base64Decode(textFixture));
      expect(text.text, contains('Cells'));
      expect(text.text, contains('Structure and function'));
      await expectLater(
        extractPdfHeadings(base64Decode(scannedFixture)),
        throwsA(
          isA<AccountException>().having((e) => e.code, 'code', 'pdf_no_text'),
        ),
      );
      await legacy.delete();
      await deleteDatabase(path);
    },
  );
}

const bookmarksFixture =
    'JVBERi0xLjMKJZOMi54gUmVwb3J0TGFiIEdlbmVyYXRlZCBQREYgZG9jdW1lbnQgKG9wZW5zb3VyY2UpCjEgMCBvYmoKPDwKL0YxIDIgMCBSCj4+CmVuZG9iagoyIDAgb2JqCjw8Ci9CYXNlRm9udCAvSGVsdmV0aWNhIC9FbmNvZGluZyAvV2luQW5zaUVuY29kaW5nIC9OYW1lIC9GMSAvU3VidHlwZSAvVHlwZTEgL1R5cGUgL0ZvbnQKPj4KZW5kb2JqCjMgMCBvYmoKPDwKL0NvbnRlbnRzIDExIDAgUiAvTWVkaWFCb3ggWyAwIDAgNTk1LjI3NTYgODQxLjg4OTggXSAvUGFyZW50IDEwIDAgUiAvUmVzb3VyY2VzIDw8Ci9Gb250IDEgMCBSIC9Qcm9jU2V0IFsgL1BERiAvVGV4dCAvSW1hZ2VCIC9JbWFnZUMgL0ltYWdlSSBdCj4+IC9Sb3RhdGUgMCAvVHJhbnMgPDwKCj4+IAogIC9UeXBlIC9QYWdlCj4+CmVuZG9iago0IDAgb2JqCjw8Ci9Db250ZW50cyAxMiAwIFIgL01lZGlhQm94IFsgMCAwIDU5NS4yNzU2IDg0MS44ODk4IF0gL1BhcmVudCAxMCAwIFIgL1Jlc291cmNlcyA8PAovRm9udCAxIDAgUiAvUHJvY1NldCBbIC9QREYgL1RleHQgL0ltYWdlQiAvSW1hZ2VDIC9JbWFnZUkgXQo+PiAvUm90YXRlIDAgL1RyYW5zIDw8Cgo+PiAKICAvVHlwZSAvUGFnZQo+PgplbmRvYmoKNSAwIG9iago8PAovT3V0bGluZXMgNyAwIFIgL1BhZ2VNb2RlIC9Vc2VOb25lIC9QYWdlcyAxMCAwIFIgL1R5cGUgL0NhdGFsb2cKPj4KZW5kb2JqCjYgMCBvYmoKPDwKL0F1dGhvciAoYW5vbnltb3VzKSAvQ3JlYXRpb25EYXRlIChEOjIwMjYxMTE1MDIwMTUwKzAzJzAwJykgL0NyZWF0b3IgKGFub255bW91cykgL0tleXdvcmRzICgpIC9Nb2REYXRlIChEOjIwMjYxMTE1MDIwMTUwKzAzJzAwJykgL1Byb2R1Y2VyIChSZXBvcnRMYWIgUERGIExpYnJhcnkgLSBcKG9wZW5zb3VyY2VcKSkgCiAgL1N1YmplY3QgKHVuc3BlY2lmaWVkKSAvVGl0bGUgKHVudGl0bGVkKSAvVHJhcHBlZCAvRmFsc2UKPj4KZW5kb2JqCjcgMCBvYmoKPDwKL0NvdW50IDIgL0ZpcnN0IDggMCBSIC9MYXN0IDkgMCBSIC9UeXBlIC9PdXRsaW5lcwo+PgplbmRvYmoKOCAwIG9iago8PAovRGVzdCBbIDMgMCBSIC9GaXQgXSAvTmV4dCA5IDAgUiAvUGFyZW50IDcgMCBSIC9UaXRsZSAoSW50ZWdyYXRpb24pCj4+CmVuZG9iago5IDAgb2JqCjw8Ci9EZXN0IFsgNCAwIFIgL0ZpdCBdIC9QYXJlbnQgNyAwIFIgL1ByZXYgOCAwIFIgL1RpdGxlIChBcHBsaWNhdGlvbnMpCj4+CmVuZG9iagoxMCAwIG9iago8PAovQ291bnQgMiAvS2lkcyBbIDMgMCBSIDQgMCBSIF0gL1R5cGUgL1BhZ2VzCj4+CmVuZG9iagoxMSAwIG9iago8PAovRmlsdGVyIFsgL0FTQ0lJODVEZWNvZGUgL0ZsYXRlRGVjb2RlIF0gL0xlbmd0aCAxMzUKPj4Kc3RyZWFtCkdhcFFoMEU9RiwwVVxIM1RccE5ZVF5RS2s/dGM+SVAsO1cjVTFeMjNpaFBFTV8/Q1c0S0lTaTg6YlhnXzpeRzBDZC4jNzA4UExqMS9CUSxeZG82VXA7QChbZVU9S1VFMlJrVENcMFNEVidWbmhTMGVZdGgrTC5sQChlTDF1KEJFUjEsMSR+PmVuZHN0cmVhbQplbmRvYmoKMTIgMCBvYmoKPDwKL0ZpbHRlciBbIC9BU0NJSTg1RGVjb2RlIC9GbGF0ZURlY29kZSBdIC9MZW5ndGggMTA1Cj4+CnN0cmVhbQpHYXBRaDBFPUYsMFVcSDNUXHBOWVReUUtrP3RjPklQLDtXI1UxXjIzaWhQRU1fP0NXNEtJU2k4OmJYZ186XkcwQ2N1Ok5hYU43K04vQlEsXi8oUloqYVxpRGwhXCUxLiFXWFZjJ0A/fj5lbmRzdHJlYW0KZW5kb2JqCnhyZWYKMCAxMwowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwNjEgMDAwMDAgbiAKMDAwMDAwMDA5MiAwMDAwMCBuIAowMDAwMDAwMTk5IDAwMDAwIG4gCjAwMDAwMDA0MDQgMDAwMDAgbiAKMDAwMDAwMDYwOSAwMDAwMCBuIAowMDAwMDAwNjk0IDAwMDAwIG4gCjAwMDAwMDA5NTUgMDAwMDAgbiAKMDAwMDAwMTAyNiAwMDAwMCBuIAowMDAwMDAxMTE1IDAwMDAwIG4gCjAwMDAwMDEyMDUgMDAwMDAgbiAKMDAwMDAwMTI3MSAwMDAwMCBuIAowMDAwMDAxNDk3IDAwMDAwIG4gCnRyYWlsZXIKPDwKL0lEIApbPGI5Zjk0ZGUzNzgyOTUxMzMwMTUxMjA5OGQ3ZGI2MjVlPjxiOWY5NGRlMzc4Mjk1MTMzMDE1MTIwOThkN2RiNjI1ZT5dCiUgUmVwb3J0TGFiIGdlbmVyYXRlZCBQREYgZG9jdW1lbnQgLS0gZGlnZXN0IChvcGVuc291cmNlKQoKL0luZm8gNiAwIFIKL1Jvb3QgNSAwIFIKL1NpemUgMTMKPj4Kc3RhcnR4cmVmCjE2OTMKJSVFT0YK';
const textFixture =
    'JVBERi0xLjMKJZOMi54gUmVwb3J0TGFiIEdlbmVyYXRlZCBQREYgZG9jdW1lbnQgKG9wZW5zb3VyY2UpCjEgMCBvYmoKPDwKL0YxIDIgMCBSCj4+CmVuZG9iagoyIDAgb2JqCjw8Ci9CYXNlRm9udCAvSGVsdmV0aWNhIC9FbmNvZGluZyAvV2luQW5zaUVuY29kaW5nIC9OYW1lIC9GMSAvU3VidHlwZSAvVHlwZTEgL1R5cGUgL0ZvbnQKPj4KZW5kb2JqCjMgMCBvYmoKPDwKL0NvbnRlbnRzIDcgMCBSIC9NZWRpYUJveCBbIDAgMCA1OTUuMjc1NiA4NDEuODg5OCBdIC9QYXJlbnQgNiAwIFIgL1Jlc291cmNlcyA8PAovRm9udCAxIDAgUiAvUHJvY1NldCBbIC9QREYgL1RleHQgL0ltYWdlQiAvSW1hZ2VDIC9JbWFnZUkgXQo+PiAvUm90YXRlIDAgL1RyYW5zIDw8Cgo+PiAKICAvVHlwZSAvUGFnZQo+PgplbmRvYmoKNCAwIG9iago8PAovUGFnZU1vZGUgL1VzZU5vbmUgL1BhZ2VzIDYgMCBSIC9UeXBlIC9DYXRhbG9nCj4+CmVuZG9iago1IDAgb2JqCjw8Ci9BdXRob3IgKGFub255bW91cykgL0NyZWF0aW9uRGF0ZSAoRDoyMDI2MTExNTAyMDE1MCswMycwMCcpIC9DcmVhdG9yIChhbm9ueW1vdXMpIC9LZXl3b3JkcyAoKSAvTW9kRGF0ZSAoRDoyMDI2MTExNTAyMDE1MCswMycwMCcpIC9Qcm9kdWNlciAoUmVwb3J0TGFiIFBERiBMaWJyYXJ5IC0gXChvcGVuc291cmNlXCkpIAogIC9TdWJqZWN0ICh1bnNwZWNpZmllZCkgL1RpdGxlICh1bnRpdGxlZCkgL1RyYXBwZWQgL0ZhbHNlCj4+CmVuZG9iago2IDAgb2JqCjw8Ci9Db3VudCAxIC9LaWRzIFsgMyAwIFIgXSAvVHlwZSAvUGFnZXMKPj4KZW5kb2JqCjcgMCBvYmoKPDwKL0ZpbHRlciBbIC9BU0NJSTg1RGVjb2RlIC9GbGF0ZURlY29kZSBdIC9MZW5ndGggMTMwCj4+CnN0cmVhbQpHYXBRaDBFPUYsMFVcSDNUXHBOWVReUUtrP3RjPklQLDtXI1UxXjIzaWhQRU1fP0NXNEtJU2k4OmJYZ186XkcwQ2N1O2IpYVhQZT8jZyNzTWRERFgjI2JpZllVbzYsXFVwTU9NK1liVz0rZyFSU1xLaXNxJW5XNWwoQkR1Pys+M34+ZW5kc3RyZWFtCmVuZG9iagp4cmVmCjAgOAowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwNjEgMDAwMDAgbiAKMDAwMDAwMDA5MiAwMDAwMCBuIAowMDAwMDAwMTk5IDAwMDAwIG4gCjAwMDAwMDA0MDIgMDAwMDAgbiAKMDAwMDAwMDQ3MCAwMDAwMCBuIAowMDAwMDAwNzMxIDAwMDAwIG4gCjAwMDAwMDA3OTAgMDAwMDAgbiAKdHJhaWxlcgo8PAovSUQgCls8MDkwMmUxOTNhMWMzYzFjMmU3NWQyYzU1ZjI2N2UyOTQ+PDA5MDJlMTkzYTFjM2MxYzJlNzVkMmM1NWYyNjdlMjk0Pl0KJSBSZXBvcnRMYWIgZ2VuZXJhdGVkIFBERiBkb2N1bWVudCAtLSBkaWdlc3QgKG9wZW5zb3VyY2UpCgovSW5mbyA1IDAgUgovUm9vdCA0IDAgUgovU2l6ZSA4Cj4+CnN0YXJ0eHJlZgoxMDEwCiUlRU9GCg==';
const scannedFixture =
    'JVBERi0xLjMKJZOMi54gUmVwb3J0TGFiIEdlbmVyYXRlZCBQREYgZG9jdW1lbnQgKG9wZW5zb3VyY2UpCjEgMCBvYmoKPDwKL0YxIDIgMCBSCj4+CmVuZG9iagoyIDAgb2JqCjw8Ci9CYXNlRm9udCAvSGVsdmV0aWNhIC9FbmNvZGluZyAvV2luQW5zaUVuY29kaW5nIC9OYW1lIC9GMSAvU3VidHlwZSAvVHlwZTEgL1R5cGUgL0ZvbnQKPj4KZW5kb2JqCjMgMCBvYmoKPDwKL0NvbnRlbnRzIDcgMCBSIC9NZWRpYUJveCBbIDAgMCA1OTUuMjc1NiA4NDEuODg5OCBdIC9QYXJlbnQgNiAwIFIgL1Jlc291cmNlcyA8PAovRm9udCAxIDAgUiAvUHJvY1NldCBbIC9QREYgL1RleHQgL0ltYWdlQiAvSW1hZ2VDIC9JbWFnZUkgXQo+PiAvUm90YXRlIDAgL1RyYW5zIDw8Cgo+PiAKICAvVHlwZSAvUGFnZQo+PgplbmRvYmoKNCAwIG9iago8PAovUGFnZU1vZGUgL1VzZU5vbmUgL1BhZ2VzIDYgMCBSIC9UeXBlIC9DYXRhbG9nCj4+CmVuZG9iago1IDAgb2JqCjw8Ci9BdXRob3IgKGFub255bW91cykgL0NyZWF0aW9uRGF0ZSAoRDoyMDI2MTExNTAyMDE1MCswMycwMCcpIC9DcmVhdG9yIChhbm9ueW1vdXMpIC9LZXl3b3JkcyAoKSAvTW9kRGF0ZSAoRDoyMDI2MTExNTAyMDE1MCswMycwMCcpIC9Qcm9kdWNlciAoUmVwb3J0TGFiIFBERiBMaWJyYXJ5IC0gXChvcGVuc291cmNlXCkpIAogIC9TdWJqZWN0ICh1bnNwZWNpZmllZCkgL1RpdGxlICh1bnRpdGxlZCkgL1RyYXBwZWQgL0ZhbHNlCj4+CmVuZG9iago2IDAgb2JqCjw8Ci9Db3VudCAxIC9LaWRzIFsgMyAwIFIgXSAvVHlwZSAvUGFnZXMKPj4KZW5kb2JqCjcgMCBvYmoKPDwKL0ZpbHRlciBbIC9BU0NJSTg1RGVjb2RlIC9GbGF0ZURlY29kZSBdIC9MZW5ndGggNzcKPj4Kc3RyZWFtCkdhcFFoMEU9RiwwVVxIM1RccE5ZVF5RS2s/dGM+SVAsO1cjVTFeMjNpaFBFTV9OaCQsQyZnU1QicVklKFdvMFxsVjgqNjdTWEJuYX4+ZW5kc3RyZWFtCmVuZG9iagp4cmVmCjAgOAowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwNjEgMDAwMDAgbiAKMDAwMDAwMDA5MiAwMDAwMCBuIAowMDAwMDAwMTk5IDAwMDAwIG4gCjAwMDAwMDA0MDIgMDAwMDAgbiAKMDAwMDAwMDQ3MCAwMDAwMCBuIAowMDAwMDAwNzMxIDAwMDAwIG4gCjAwMDAwMDA3OTAgMDAwMDAgbiAKdHJhaWxlcgo8PAovSUQgCls8YWIyMDYzOTYyMzc4MWUxNDAzNTEwZmI2YmZjOGVhNjg+PGFiMjA2Mzk2MjM3ODFlMTQwMzUxMGZiNmJmYzhlYTY4Pl0KJSBSZXBvcnRMYWIgZ2VuZXJhdGVkIFBERiBkb2N1bWVudCAtLSBkaWdlc3QgKG9wZW5zb3VyY2UpCgovSW5mbyA1IDAgUgovUm9vdCA0IDAgUgovU2l6ZSA4Cj4+CnN0YXJ0eHJlZgo5NTYKJSVFT0YK';
