import 'dart:convert';
import 'dart:ui' show Rect;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:fiber_capstone/services/data_service.dart';

Future<Uint8List> _createTextPdf() async {
  final document = PdfDocument();
  final page = document.pages.add();
  page.graphics.drawString(
    'Pond managers monitor water quality daily. '
    'Healthy fish require oxygen for growth. '
    'Farmers adjust feeding schedules to support aquatic life. '
    'Regular aeration prevents stress during warm weather.',
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(20, 20, 520, 200),
  );
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

Future<Uint8List> _createQuestionBankPdf() async {
  final document = PdfDocument();
  final page = document.pages.add();
  page.graphics.drawString(
    '1. Term used for lost or abandoned fishing gear that continues to catch fish?\n'
    'a. mirage fishing\n'
    'b. pirate fishing\n'
    'c. unsustainable fishing\n'
    'd. ghost fishing\n'
    'Answer: D\n'
    '2. IUU fishing means what?\n'
    'a. Illegal, Unreported and Unregulated\n'
    'b. Inefficient, Uncontrolled and Unreasonable\n'
    'c. Immediate, Undermanned and Unassisted\n'
    'd. Irresponsible, Unmitigated and Unrecorded\n'
    '3. Which fishing practice is correct?\n'
    'a. mirage fishing\n'
    'b. pirate fishing\n'
    'c. unsustainable fishing\n'
    'd. ghost fishing\n'
    'Answer: pirate fishing',
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(20, 20, 520, 400),
  );
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

Future<Uint8List> _createInlineQuestionBankPdfWithAnswerKey() async {
  final document = PdfDocument();
  final page = document.pages.add();
  page.graphics.drawString(
    '1. Which option is first?\n'
    'a. Alpha b. Beta\n'
    'c. Gamma d. Delta\n'
    '2. Which option is second?\n'
    'a. North b. South\n'
    'c. East d. West\n'
    'Answer Key\n'
    '1. b 2. c',
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(20, 20, 520, 200),
  );
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

Future<Uint8List> _createQuestionBankPdfWithVariantAnswerKey() async {
  final document = PdfDocument();
  final page = document.pages.add();
  page.graphics.drawString(
    '1. Which option is first?\n'
    'A. Alpha\n'
    'B. Beta\n'
    'C. Gamma\n'
    'D. Delta\n'
    '2. Which option is second?\n'
    'A. North\n'
    'B. South\n'
    'C. East\n'
    'D. West\n'
    'Answers: Q1 - B; (2) D',
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(20, 20, 520, 300),
  );
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

Future<Uint8List> _createPdfWithAnswerKeyAfterPageLimit() async {
  final document = PdfDocument();
  for (var pageNumber = 1; pageNumber <= 41; pageNumber++) {
    final page = document.pages.add();
    if (pageNumber == 1) {
      page.graphics.drawString(
        '1. Which option is correct?\n'
        'A. Alpha\n'
        'B. Beta\n'
        'C. Gamma\n'
        'D. Delta',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 20, 520, 200),
      );
    } else if (pageNumber == 41) {
      page.graphics.drawString(
        'Answer Key\n1. C',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 20, 520, 200),
      );
    }
  }
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

Uint8List _createQuestionBankDocx() {
  const paragraphs = [
    '1. Term used for lost or abandoned fishing gear that continues to catch fish?',
    'a. mirage fishingb. pirate fishing',
    'c. unsustainable fishingd. ghost fishing',
    '2. IUU fishing means what?',
    'a. Illegal, Unreported and Unregulatedb. Inefficient, Uncontrolled and Unreasonable',
    'c. Immediate, Undermanned and Unassistedd. Irresponsible, Unmitigated and Unrecorded',
    'Answer Key',
    '1. D 2. C',
  ];
  final body = paragraphs
      .map(
        (text) =>
            '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>',
      )
      .join();
  final documentXml = utf8.encode(
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:body>$body</w:body></w:document>',
  );
  final archive = Archive()
    ..addFile(
      ArchiveFile('word/document.xml', documentXml.length, documentXml),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF quiz and mock exam drafts generate questions', () async {
    final bytes = await _createTextPdf();

    for (final category in ['quiz', 'mock_exam']) {
      final draft = await DataService.prepareModuleDraft(
        title: 'Pond Management',
        fileName: 'pond-management.pdf',
        category: category,
        bytes: bytes,
      );

      expect(draft.questions, isNotEmpty, reason: category);
    }
  });

  test(
    'PDF module drafts do not generate questions or replace the PDF',
    () async {
      final bytes = await _createTextPdf();
      final draft = await DataService.prepareModuleDraft(
        title: 'Pond Management',
        fileName: 'pond-management.pdf',
        category: 'module',
        bytes: bytes,
      );

      expect(draft.questions, isEmpty);
      expect(draft.fileUrl, startsWith('data:application/pdf;base64,'));
      expect(draft.fileUrl!.split(',').last, equals(base64Encode(bytes)));
    },
  );

  test(
    'PDF quiz drafts keep source questions and choices without guessing keys',
    () async {
      final draft = await DataService.prepareModuleDraft(
        title: 'Fishing Quiz',
        fileName: 'fishing-quiz.pdf',
        category: 'quiz',
        bytes: await _createQuestionBankPdf(),
      );

      expect(draft.questions, hasLength(3));
      expect(
        draft.questions[0].question,
        'Term used for lost or abandoned fishing gear that continues to catch fish?',
      );
      expect(draft.questions[0].choices, [
        'mirage fishing',
        'pirate fishing',
        'unsustainable fishing',
        'ghost fishing',
      ]);
      expect(draft.questions[0].correctIndex, 3);
      expect(draft.questions[1].question, 'IUU fishing means what?');
      expect(draft.questions[1].choices, [
        'Illegal, Unreported and Unregulated',
        'Inefficient, Uncontrolled and Unreasonable',
        'Immediate, Undermanned and Unassisted',
        'Irresponsible, Unmitigated and Unrecorded',
      ]);
      expect(draft.questions[1].correctIndex, -1);
      expect(draft.questions[2].correctIndex, 1);
    },
  );

  test(
    'PDF quiz drafts parse inline choices and a separate numbered answer key',
    () async {
      final draft = await DataService.prepareModuleDraft(
        title: 'Inline Quiz',
        fileName: 'inline-quiz.pdf',
        category: 'quiz',
        bytes: await _createInlineQuestionBankPdfWithAnswerKey(),
      );

      expect(draft.questions, hasLength(2));
      expect(draft.questions.first.choices, [
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
      ]);
      expect(draft.questions.first.correctIndex, 1);
      expect(draft.questions.last.choices, ['North', 'South', 'East', 'West']);
      expect(draft.questions.last.correctIndex, 2);
    },
  );

  test(
    'PDF quizzes and mock exams parse varied numbered answer key formats',
    () async {
      final bytes = await _createQuestionBankPdfWithVariantAnswerKey();

      for (final category in ['quiz', 'mock_exam']) {
        final draft = await DataService.prepareModuleDraft(
          title: 'Variant Answer Key',
          fileName: 'variant-answer-key.pdf',
          category: category,
          bytes: bytes,
        );

        expect(draft.questions, hasLength(2), reason: category);
        expect(draft.questions[0].correctIndex, 1, reason: category);
        expect(draft.questions[1].correctIndex, 3, reason: category);
      }
    },
  );

  test('PDF extraction reads answer keys after page 40', () async {
    final draft = await DataService.prepareModuleDraft(
      title: 'Long Quiz',
      fileName: 'long-quiz.pdf',
      category: 'quiz',
      bytes: await _createPdfWithAnswerKeyAfterPageLimit(),
    );

    expect(draft.questions, hasLength(1));
    expect(draft.questions.single.correctIndex, 2);
  });

  test(
    'DOCX quiz drafts keep source questions, choices and answer key',
    () async {
      final draft = await DataService.prepareModuleDraft(
        title: 'Fishing Quiz',
        fileName: 'fishing-quiz.docx',
        category: 'quiz',
        bytes: _createQuestionBankDocx(),
      );

      expect(draft.questions, hasLength(2));
      expect(
        draft.questions.first.question,
        'Term used for lost or abandoned fishing gear that continues to catch fish?',
      );
      expect(draft.questions.first.choices, [
        'mirage fishing',
        'pirate fishing',
        'unsustainable fishing',
        'ghost fishing',
      ]);
      expect(draft.questions.first.correctIndex, 3);
      expect(draft.questions.last.choices, [
        'Illegal, Unreported and Unregulated',
        'Inefficient, Uncontrolled and Unreasonable',
        'Immediate, Undermanned and Unassisted',
        'Irresponsible, Unmitigated and Unrecorded',
      ]);
      expect(draft.questions.last.correctIndex, 2);
    },
  );
}
