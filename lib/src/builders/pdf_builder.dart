import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/rtl_utils.dart';
import '../../flutter_pdf_export.dart';

/// Parses a markdown string into a list of [PdfSection]s.
///
/// Handles:
/// - `# H1`, `## H2`, `### H3` headings (with or without trailing **)
/// - `**bold**` inline — preserved for the builder to render
/// - `- item`, `• item`, `* item`, `1. item`, `1) item` bullet/numbered lists
/// - Indented nesting via leading spaces
/// - `---` / `***` / `___` → divider
/// - Empty or whitespace-only lines → spacer
/// - Everything else → paragraph (with all bare * / ** stripped from display)
class MarkdownParser {
  MarkdownParser._();

  // Matches any bullet or numbered list marker at the start of a line
  static final _bulletRe = RegExp(r'^(\s*)([-•*+]|\d+[.)]) +(.+)$');

  // Matches a horizontal rule line
  static final _hrRe = RegExp(r'^(\*{3,}|-{3,}|_{3,})\s*$');

  static List<PdfSection> parse(String markdown) {
    final sections = <PdfSection>[];
    final lines = markdown.split('\n');

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      // ── Empty line → spacer ─────────────────────────────────────────────
      if (trimmed.isEmpty) {
        sections.add(PdfSection.spacer());
        continue;
      }

      // ── Headings ────────────────────────────────────────────────────────
      if (trimmed.startsWith('### ')) {
        sections.add(PdfSection.h3(_cleanHeading(trimmed.substring(4))));
        continue;
      }
      if (trimmed.startsWith('##')) {
        final text = trimmed.replaceFirst(RegExp(r'^##\s*'), '');
        sections.add(PdfSection.h2(_cleanHeading(text)));
        continue;
      }
      if (trimmed.startsWith('#')) {
        final text = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        sections.add(PdfSection.h1(_cleanHeading(text)));
        continue;
      }

      // ── Horizontal rule ─────────────────────────────────────────────────
      if (_hrRe.hasMatch(trimmed)) {
        sections.add(PdfSection.divider());
        continue;
      }

      // ── Bullet / numbered list item ─────────────────────────────────────
      final bulletMatch = _bulletRe.firstMatch(line);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1)!.length;
        final text = _cleanInline(bulletMatch.group(3)!);
        // Skip lines that are only symbols after cleaning
        if (text.trim().isEmpty) continue;
        sections.add(PdfSection.bullet(text, level: indent ~/ 2));
        continue;
      }

      // ── Plain paragraph ─────────────────────────────────────────────────
      // Keep **bold** intact for the builder, but strip loose * symbols
      final paraText = _cleanInline(trimmed);
      if (paraText.trim().isEmpty) continue;
      sections.add(PdfSection.paragraph(paraText));
    }

    return sections;
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  /// Strips all markdown decoration from a heading string.
  static String _cleanHeading(String text) {
    return text
        .replaceAll('**', '') // bold markers
        .replaceAll('*', '') // stray asterisks
        .replaceAll('_', '') // underscore emphasis
        .replaceAll('`', '') // inline code
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // links → label
        .trim();
  }

  /// Cleans inline text:
  /// - Preserves **bold** markers (the builder renders them)
  /// - Strips lone * or _ emphasis markers that aren't part of **...**
  /// - Strips `inline code` backticks
  /// - Strips leading bullet markers that slipped through (- • * +)
  static String _cleanInline(String text) {
    var s = text;

    // Strip leading bullet markers that weren't caught by the bullet regex
    s = s.replaceFirst(RegExp(r'^[\s]*[-•*+]\s+'), '');

    // Strip lone * or _ that are NOT part of ** or __
    // Strategy: temporarily hide **, then strip lone *, then restore
    s = s
        .replaceAll('**', '\x00BOLD\x00') // protect **
        .replaceAll('__', '\x00BOLD\x00') // protect __
        .replaceAll('*', '') // remove lone *
        .replaceAll('_', '') // remove lone _
        .replaceAll('\x00BOLD\x00', '**'); // restore as **

    // Strip inline code backticks but keep the text
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);

    // Strip markdown links [label](url) → label
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );

    return s.trim();
  }
}

/// The main entry-point for generating PDFs.
///
/// ```dart
/// final file = await PdfBuilder.generate(
///   PdfDocumentData.fromMarkdown(
///     title: 'My Report',
///     markdown: markdownString,
///     style: PdfStyle.light,
///   ),
/// );
/// // file is a dart:io File — save, share, or open with file_picker / share_plus
/// ```
class PdfBuilder {
  PdfBuilder._();

  /// Generates a PDF from [data] and returns the resulting [File].
  ///
  /// The [File] is written to the system's temporary directory with a
  /// timestamped name (or [PdfDocumentData.outputFileName] if provided).
  ///
  /// You are responsible for moving / sharing the file using any package
  /// you prefer (e.g. `share_plus`, `file_picker`, `open_file`, etc.).
  static Future<File> generate(PdfDocumentData data) async {
    log('[PdfBuilder] Starting generation: "${data.title}"');

    // 1. Merge structured sections + parsed markdownBody
    final allSections = [
      ...data.sections,
      if (data.markdownBody != null)
        ...MarkdownParser.parse(data.markdownBody!),
    ];

    // 2. Collect all text strings for font preloading
    final allTexts = [
      data.title,
      if (data.subtitle != null) data.subtitle!,
      for (final s in allSections) s.text,
    ];

    // 3. Resolve fonts (parallel, cached)
    log('[PdfBuilder] Preloading fonts for ${allTexts.length} text strings…');
    await FontResolver.preload(allTexts);

    // 4. Build per-family font maps
    final neededFamilies = allTexts.map(FontResolver.familyFor).toSet();
    final fontMap = <String, pw.Font>{};
    final boldMap = <String, pw.Font>{};

    await Future.wait(
      neededFamilies.map((f) async {
        fontMap[f] = await FontResolver.resolveFamily(f);
        boldMap[f] = await FontResolver.resolveFamily(f, bold: true);
      }),
    );

    final defaultFamily = FontResolver.familyFor(data.title);
    final baseFont = fontMap[defaultFamily] ?? fontMap.values.first;
    final baseBoldFont = boldMap[defaultFamily] ?? boldMap.values.first;

    // 5. Build the pw.Document
    final style = data.style;
    final pdf = pw.Document(
      title: data.title,
      author: data.author ?? 'flutter_pdf_export',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: style.pageFormat,
        margin: pw.EdgeInsets.symmetric(
          horizontal: style.horizontalMargin,
          vertical: style.verticalMargin,
        ),
        // ── Header ──────────────────────────────────────────────────────────
        header: (ctx) => _buildHeader(
          ctx,
          data: data,
          style: style,
          baseFont: baseFont,
          baseBoldFont: baseBoldFont,
        ),
        // ── Footer ──────────────────────────────────────────────────────────
        footer: (ctx) => _buildFooter(ctx, style: style, baseFont: baseFont),
        // ── Body ─────────────────────────────────────────────────────────────
        build: (ctx) => _buildBody(
          allSections,
          style: style,
          fontMap: fontMap,
          boldMap: boldMap,
          baseFont: baseFont,
          baseBoldFont: baseBoldFont,
        ),
      ),
    );

    // 6. Save to temp dir
    final dir = await getTemporaryDirectory();
    final fileName = data.outputFileName != null
        ? '${data.outputFileName}.pdf'
        : 'pdf_export_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    log('[PdfBuilder] Saved → ${file.path}');
    return file;
  }

  // ── Header builder ────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    pw.Context ctx, {
    required PdfDocumentData data,
    required PdfStyle style,
    required pw.Font baseFont,
    required pw.Font baseBoldFont,
  }) {
    if (!style.showHeaderBar && !style.showHeaderTitle) {
      return pw.SizedBox.shrink();
    }

    final titleRtl = RtlUtils.isRtl(data.title);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (style.showHeaderBar)
          pw.Container(
            height: style.headerBarHeight,
            decoration: pw.BoxDecoration(color: style.accentColor),
          ),
        if (style.showHeaderBar) pw.SizedBox(height: 10),
        if (style.showHeaderTitle)
          pw.Text(
            data.title,
            textDirection: titleRtl
                ? pw.TextDirection.rtl
                : pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: baseBoldFont,
              fontSize: style.h2FontSize,
              color: style.textColor,
            ),
          ),
        if (style.showHeaderTitle) pw.SizedBox(height: 4),
        pw.Divider(color: style.dividerColor, thickness: 0.5),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Footer builder ────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(
    pw.Context ctx, {
    required PdfStyle style,
    required pw.Font baseFont,
  }) {
    if (!style.showPageNumbers && style.footerLeftText == null) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      children: [
        pw.Divider(color: style.dividerColor, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (style.footerLeftText != null)
              pw.Text(
                style.footerLeftText!,
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: style.footerFontSize,
                  color: style.footerColor,
                  fontStyle: pw.FontStyle.italic,
                ),
              )
            else
              pw.SizedBox.shrink(),
            if (style.showPageNumbers)
              pw.Text(
                '${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: style.footerFontSize,
                  color: style.footerColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Body builder ──────────────────────────────────────────────────────────

  static List<pw.Widget> _buildBody(
    List<PdfSection> sections, {
    required PdfStyle style,
    required Map<String, pw.Font> fontMap,
    required Map<String, pw.Font> boldMap,
    required pw.Font baseFont,
    required pw.Font baseBoldFont,
  }) {
    final widgets = <pw.Widget>[];

    for (final section in sections) {
      switch (section.type) {
        case PdfSectionType.divider:
          widgets
            ..add(pw.SizedBox(height: 8))
            ..add(pw.Divider(color: style.dividerColor, thickness: 0.5))
            ..add(pw.SizedBox(height: 8));
          break;

        case PdfSectionType.spacer:
          widgets.add(pw.SizedBox(height: style.paragraphSpacing * 2));
          break;

        case PdfSectionType.h1:
          widgets.addAll(
            _heading(
              section.text,
              style,
              fontMap,
              boldMap,
              size: style.h1FontSize,
              color: style.accentColor,
            ),
          );
          break;

        case PdfSectionType.h2:
          widgets.addAll(
            _heading(
              section.text,
              style,
              fontMap,
              boldMap,
              size: style.h2FontSize,
              color: style.textColor,
            ),
          );
          break;

        case PdfSectionType.h3:
          widgets.addAll(
            _heading(
              section.text,
              style,
              fontMap,
              boldMap,
              size: style.h3FontSize,
              color: style.subtitleColor,
            ),
          );
          break;

        case PdfSectionType.paragraph:
          if (section.text.trim().isEmpty) break;
          // Sanitize first so font detection uses clean text
          final cleanPara = _sanitize(section.text);
          if (cleanPara.isEmpty) break;
          final font = _font(cleanPara, fontMap, baseFont);
          final bold = _font(cleanPara, boldMap, baseBoldFont);
          final rtl = RtlUtils.isRtl(cleanPara);
          widgets
            ..add(
              _richText(
                cleanPara,
                font: font,
                boldFont: bold,
                size: style.bodyFontSize,
                color: style.textColor,
                lineHeight: style.bodyLineHeight,
                rtl: rtl,
              ),
            )
            ..add(pw.SizedBox(height: style.paragraphSpacing));
          break;

        case PdfSectionType.bullet:
          if (section.text.trim().isEmpty) break;
          // Sanitize — strip any leading markers + stray * symbols
          final cleanBullet = _sanitize(section.text);
          if (cleanBullet.isEmpty) break;
          final font = _font(cleanBullet, fontMap, baseFont);
          final bold = _font(cleanBullet, boldMap, baseBoldFont);
          final rtl = RtlUtils.isRtl(cleanBullet);
          final indent = section.level * style.bulletIndentPerLevel;

          widgets
            ..add(
              pw.Padding(
                padding: pw.EdgeInsets.only(
                  left: rtl ? 0 : indent,
                  right: rtl ? indent : 0,
                ),
                child: _bulletRow(
                  _richText(
                    cleanBullet,
                    font: font,
                    boldFont: bold,
                    size: style.bodyFontSize,
                    color: style.textColor,
                    lineHeight: style.bulletLineHeight,
                    rtl: rtl,
                  ),
                  style: style,
                  rtl: rtl,
                ),
              ),
            )
            ..add(pw.SizedBox(height: style.paragraphSpacing));
          break;

        case PdfSectionType.image:
          if (section.imageBytes == null) break;
          final image = pw.MemoryImage(section.imageBytes!);
          final pageWidth =
              style.pageFormat.availableWidth - style.horizontalMargin * 2;
          final imgWidth = pageWidth * section.imageWidthFraction;

          pw.Alignment alignment;
          switch (section.imageAlignment) {
            case 'left':
              alignment = pw.Alignment.centerLeft;
              break;
            case 'right':
              alignment = pw.Alignment.centerRight;
              break;
            default:
              alignment = pw.Alignment.center;
          }

          widgets
            ..add(pw.SizedBox(height: style.paragraphSpacing))
            ..add(
              pw.Align(
                alignment: alignment,
                child: pw.Image(image, width: imgWidth),
              ),
            );

          if (section.caption != null && section.caption!.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  section.caption!,
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: style.bodyFontSize - 2,
                    color: style.subtitleColor,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: style.paragraphSpacing));
          break;

        // markdown sections are pre-parsed before reaching here
        case PdfSectionType.markdown:
          break;
      }
    }

    return widgets;
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  static List<pw.Widget> _heading(
    String text,
    PdfStyle style,
    Map<String, pw.Font> fontMap,
    Map<String, pw.Font> boldMap, {
    required double size,
    required PdfColor color,
  }) {
    final font = _font(text, boldMap, fontMap.values.first);
    final rtl = RtlUtils.isRtl(text);

    return [
      pw.SizedBox(height: style.headingTopPadding),
      pw.Align(
        alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: font,
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ),
      pw.SizedBox(height: 4),
    ];
  }

  static pw.Widget _bulletRow(
    pw.Widget child, {
    required PdfStyle style,
    required bool rtl,
  }) {
    final dot = pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Container(
        width: style.bulletDotSize,
        height: style.bulletDotSize,
        decoration: pw.BoxDecoration(
          color: style.textColor,
          shape: pw.BoxShape.circle,
        ),
      ),
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rtl
          ? [pw.Expanded(child: child), pw.SizedBox(width: 6), dot]
          : [dot, pw.SizedBox(width: 6), pw.Expanded(child: child)],
    );
  }

  // ── Text sanitizer ───────────────────────────────────────────────────────

  /// Strips all visible markdown symbols except **bold** markers.
  /// Removes stray * _ ` markers, leading bullet/numbered markers, and links.
  static String _sanitize(String text) {
    var s = text;
    // Strip leading bullet / numbered-list markers that slipped through
    s = s.replaceFirst(RegExp(r'^[\s]*[-•*+]\s+'), '');
    s = s.replaceFirst(RegExp(r'^[\s]*\d+[.)]\s+'), '');
    // Protect ** so lone * can be safely stripped
    s = s
        .replaceAll('**', '\x00BOLD\x00')
        .replaceAll('__', '\x00BOLD\x00')
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('\x00BOLD\x00', '**');
    // Strip inline code backticks, keep content
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
    // Strip markdown links [label](url) → label
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );
    return s.trim();
  }

  /// Builds a [pw.RichText] that renders **bold** inline markers.
  /// All other markdown symbols are stripped before rendering.
  static pw.Widget _richText(
    String raw, {
    required pw.Font font,
    required pw.Font boldFont,
    required double size,
    required PdfColor color,
    required double lineHeight,
    required bool rtl,
  }) {
    final text = _sanitize(raw);
    final spans = <pw.TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          pw.TextSpan(
            text: text.substring(cursor, match.start),
            style: pw.TextStyle(font: font, fontSize: size, color: color),
          ),
        );
      }
      spans.add(
        pw.TextSpan(
          text: match.group(1)!,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(
        pw.TextSpan(
          text: text.substring(cursor),
          style: pw.TextStyle(font: font, fontSize: size, color: color),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(
        pw.TextSpan(
          text: text,
          style: pw.TextStyle(font: font, fontSize: size, color: color),
        ),
      );
    }

    return pw.RichText(
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      text: pw.TextSpan(children: spans),
    );
  }

  static pw.Font _font(
    String text,
    Map<String, pw.Font> map,
    pw.Font fallback,
  ) {
    final family = FontResolver.familyFor(text);
    return map[family] ?? fallback;
  }
}
