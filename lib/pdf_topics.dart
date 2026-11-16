import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'account_service.dart';
import 'growth_rules.dart';

class PdfHeadings {
  const PdfHeadings(this.text, this.pageCount, {this.truncated = false});
  final String text;
  final int pageCount;
  final bool truncated;
}

class SuggestedTopic {
  const SuggestedTopic(this.title, this.startPage, this.endPage);
  final String title;
  final int startPage, endPage;
  int get minutes => (endPage - startPage + 1) * GrowthRules.pdfMinutesPerPage;
  Map<String, Object> toJson() => {
    'title': title,
    'startPage': startPage,
    'endPage': endPage,
  };
  static List<SuggestedTopic> parse(List<dynamic> values, int pageCount) {
    final result = <SuggestedTopic>[];
    final seen = <String>{};
    for (final value in values.take(GrowthRules.pdfMaxTopics)) {
      if (value is! Map ||
          value['title'] is! String ||
          value['startPage'] is! int ||
          value['endPage'] is! int) {
        continue;
      }
      final title = (value['title'] as String)
          .replaceAll(RegExp(r'[\x00-\x1f\u202a-\u202e\u2066-\u2069]'), ' ')
          .trim();
      final start = value['startPage'] as int, end = value['endPage'] as int;
      if (title.isEmpty ||
          title.length > GrowthRules.pdfMaxTitleCharacters ||
          RegExp(
            r'https?:|www\.|<[^>]+>',
            caseSensitive: false,
          ).hasMatch(title) ||
          start < 1 ||
          end < start ||
          end > pageCount) {
        continue;
      }
      final key = '${title.toLowerCase()}:$start:$end';
      if (seen.add(key)) result.add(SuggestedTopic(title, start, end));
    }
    if (result.isEmpty) throw const AccountException('invalid_response');
    return result;
  }
}

abstract class TopicProvider {
  Future<List<SuggestedTopic>> suggest(PdfHeadings document);
}

class WorkerTopicProvider implements TopicProvider {
  WorkerTopicProvider(this.accounts);
  final AccountService accounts;
  @override
  Future<List<SuggestedTopic>> suggest(PdfHeadings document) async =>
      SuggestedTopic.parse(
        await accounts.suggest(
          text: document.text,
          pageCount: document.pageCount,
        ),
        document.pageCount,
      );
}

Future<PdfHeadings> extractPdfHeadings(Uint8List bytes) async {
  if (bytes.length > GrowthRules.pdfMaxBytes) {
    throw const AccountException('pdf_large');
  }
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(
    bytes,
    sourceName: 'selected-study-document',
    passwordProvider: () => null,
  );
  try {
    final count = document.pages.length;
    if (count < 1 || count > GrowthRules.pdfMaxPages) {
      throw const AccountException('pdf_large');
    }
    final lines = <String>[];
    var length = 0;
    bool truncated = false;
    void add(String title, int page) {
      title = title.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
      if (title.isEmpty || page < 1 || page > count) return;
      final line =
          '[$page] ${title.length > GrowthRules.pdfMaxHeadingCharacters ? title.substring(0, GrowthRules.pdfMaxHeadingCharacters) : title}';
      if (length + line.length + 1 > GrowthRules.pdfMaxTextCharacters) {
        truncated = true;
        return;
      }
      lines.add(line);
      length += line.length + 1;
    }

    void walk(List<PdfOutlineNode> nodes, int depth) {
      if (depth > GrowthRules.pdfMaxOutlineDepth ||
          length >= GrowthRules.pdfMaxTextCharacters) {
        return;
      }
      for (final node in nodes) {
        if (node.dest case final dest?) add(node.title, dest.pageNumber);
        walk(node.children, depth + 1);
      }
    }

    walk(await document.loadOutline(), 0);
    if (lines.isEmpty) {
      for (final page in document.pages.take(GrowthRules.pdfScanPages)) {
        final text = await page.loadStructuredText();
        final headings = text.fullText
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .take(GrowthRules.pdfHeadingsPerPage)
            .join(' · ');
        add(headings, page.pageNumber);
        if (truncated) break;
      }
      if (count > GrowthRules.pdfScanPages) truncated = true;
    }
    if (lines.isEmpty) throw const AccountException('pdf_no_text');
    return PdfHeadings(lines.join('\n'), count, truncated: truncated);
  } finally {
    await document.dispose();
  }
}
