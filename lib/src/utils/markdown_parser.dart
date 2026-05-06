import '../../flutter_pdf_export.dart';

/// Parses a markdown string into a list of [PdfSection]s.
///
/// Handles:
/// - `# H1`, `## H2`, `### H3` headings
/// - `**bold**` inline (preserved in sections; rendered by the builder)
/// - `- item`, `• item`, `* item` bullet lists with depth detection
/// - Empty lines → spacers
/// - Everything else → paragraph
class MarkdownParser {
  MarkdownParser._();

  static List<PdfSection> parse(String markdown) {
    final sections = <PdfSection>[];
    final lines = markdown.split('\n');

    for (final raw in lines) {
      final line = raw.trimRight();

      if (line.isEmpty) {
        sections.add(PdfSection.spacer());
        continue;
      }

      if (line.startsWith('### ')) {
        sections.add(PdfSection.h3(_stripBold(line.substring(4).trim())));
        continue;
      }

      if (line.startsWith('## ')) {
        sections.add(PdfSection.h2(_stripBold(line.substring(3).trim())));
        continue;
      }

      if (line.startsWith('# ')) {
        sections.add(PdfSection.h1(_stripBold(line.substring(2).trim())));
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line.trim())) {
        sections.add(PdfSection.divider());
        continue;
      }

      // Bullet list items — supports indented nesting via leading spaces
      final bulletMatch = RegExp(r'^(\s*)([-•*]|\d+\.)\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1)!.length;
        final text = bulletMatch.group(3)!;
        sections.add(PdfSection.bullet(text, level: indent ~/ 2));
        continue;
      }

      // Plain paragraph
      sections.add(PdfSection.paragraph(line));
    }

    return sections;
  }

  /// Strips `**` markers when the heading itself is wrapped in bold.
  static String _stripBold(String text) => text.replaceAll('**', '');
}
