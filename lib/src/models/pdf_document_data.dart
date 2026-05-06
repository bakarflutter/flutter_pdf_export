import 'pdf_section.dart';
import 'pdf_style.dart';

/// The top-level data object passed to [PdfBuilder.generate].
///
/// You can either:
/// 1. Provide structured [sections] for full control over every block.
/// 2. Provide raw [markdownBody] and let the builder parse it for you.
///
/// Both can be combined — [markdownBody] is appended after [sections].
class PdfDocumentData {
  /// Document title — shown in PDF metadata and optionally in the header.
  final String title;

  /// Optional subtitle displayed below the title on the first page.
  final String? subtitle;

  /// Optional author name stored in PDF metadata.
  final String? author;

  /// Structured content sections.
  final List<PdfSection> sections;

  /// Convenience: raw markdown string appended after [sections].
  ///
  /// Supports: `# H1`, `## H2`, `### H3`, `**bold**`, `- bullet`, `• bullet`.
  final String? markdownBody;

  /// Visual style for this document. Defaults to [PdfStyle()].
  final PdfStyle style;

  /// Optional file name (without extension) for the output file.
  /// Defaults to a timestamp-based name if not provided.
  final String? outputFileName;

  const PdfDocumentData({
    required this.title,
    this.subtitle,
    this.author,
    this.sections = const [],
    this.markdownBody,
    this.style = const PdfStyle(),
    this.outputFileName,
  }) : assert(
          sections.length > 0 || markdownBody != null,
          'Provide at least one section or markdownBody.',
        );

  /// Quick constructor: pass a title + raw markdown string, nothing else.
  factory PdfDocumentData.fromMarkdown({
    required String title,
    required String markdown,
    String? subtitle,
    String? author,
    PdfStyle style = const PdfStyle(),
    String? outputFileName,
  }) {
    return PdfDocumentData(
      title: title,
      subtitle: subtitle,
      author: author,
      markdownBody: markdown,
      style: style,
      outputFileName: outputFileName,
    );
  }

  /// Quick constructor: pass a title + plain text body.
  ///
  /// Each newline becomes a new paragraph.
  factory PdfDocumentData.fromPlainText({
    required String title,
    required String body,
    String? subtitle,
    String? author,
    PdfStyle style = const PdfStyle(),
    String? outputFileName,
  }) {
    final sections = body
        .split('\n')
        .map((line) => PdfSection.paragraph(line))
        .toList();

    return PdfDocumentData(
      title: title,
      subtitle: subtitle,
      author: author,
      sections: sections,
      style: style,
      outputFileName: outputFileName,
    );
  }
}
