import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:growza/pdf_topics.dart';
import 'package:growza/growth_rules.dart';
import 'package:growza/account_service.dart';

void main() {
  setUpAll(() => Pdfrx.cacheDirectoryPath = Directory.systemTemp.path);
  test(
    'Real PDF outline extraction retains page numbers and headings',
    () async {
      final doc = await extractPdfHeadings(
        await File('test/fixtures/pdf/outlined-chapters.pdf').readAsBytes(),
      );
      expect(doc.pageCount, 3);
      expect(doc.text, '[1] Cells\n[2] DNA\n[3] Energy');
      expect(doc.truncated, isFalse);
    },
  );
  test('Real PDF without bookmarks falls back to page headings', () async {
    final doc = await extractPdfHeadings(
      await File('test/fixtures/pdf/page-headings.pdf').readAsBytes(),
    );
    expect(doc.pageCount, 2);
    expect(doc.text, contains('[1] Introduction'));
    expect(doc.text, contains('[2] Exercises'));
  });
  test(
    'Drawing-only PDF fails visibly instead of manufacturing AI topics',
    () async {
      await expectLater(
        extractPdfHeadings(
          await File('test/fixtures/pdf/no-text.pdf').readAsBytes(),
        ),
        throwsA(
          isA<AccountException>().having((e) => e.code, 'code', 'pdf_no_text'),
        ),
      );
    },
  );
  test('Oversized PDF is rejected before opening a parser', () async {
    await expectLater(
      extractPdfHeadings(Uint8List(GrowthRules.pdfMaxBytes + 1)),
      throwsA(
        isA<AccountException>().having((e) => e.code, 'code', 'pdf_large'),
      ),
    );
  });
}
