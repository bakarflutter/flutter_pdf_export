import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../fonts/font_resolver.dart';
import '../models/pdf_document_data.dart';
import '../models/pdf_section.dart';
import '../models/pdf_style.dart';
import '../utils/markdown_parser.dart';
import '../utils/rtl_utils.dart';

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
    final style = data.style;

    // 1. Flatten all sections (handle markdown type)
    final allSections = <PdfSection>[];
    for (final s in data.sections) {
      if (s.type == PdfSectionType.markdown) {
        allSections.addAll(MarkdownParser.parse(s.text));
      } else {
        allSections.add(s);
      }
    }
    if (data.markdownBody != null) {
      allSections.addAll(MarkdownParser.parse(data.markdownBody!));
    }

    // 2. Collect all text strings for font preloading
    final allTexts = <String>[
      data.title,
      if (data.subtitle != null) data.subtitle!,
      if (data.author != null) data.author!,
      if (style.footerLeftText != null) style.footerLeftText!,
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

    final defaultFamily = FontResolver.familyFor(data.title.isNotEmpty ? data.title : 'A');
    final baseFont = fontMap[defaultFamily] ?? (fontMap.isNotEmpty ? fontMap.values.first : await FontResolver.resolveFamily('Noto+Sans'));
    final baseBoldFont = boldMap[defaultFamily] ?? (boldMap.isNotEmpty ? boldMap.values.first : await FontResolver.resolveFamily('Noto+Sans', bold: true));

    // 5. Build the pw.Document
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
    if (!style.showHeaderBar && !style.showHeaderTitle && !style.showLogo) {
      return pw.SizedBox.shrink();
    }

    final titleRtl = RtlUtils.isRtl(data.title);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (style.showHeaderBar)
          pw.Container(
            height: style.headerBarHeight,
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: style.accentColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
        if (style.showHeaderBar) pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (style.showLogo && data.logoBytes != null)
              pw.Image(
                pw.MemoryImage(data.logoBytes!),
                height: style.logoSize,
                width: style.logoSize,
              ),
            if (style.showHeaderTitle)
              pw.Expanded(
                child: pw.Text(
                  data.title,
                  textDirection:
                      titleRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  textAlign: titleRtl ? pw.TextAlign.right : pw.TextAlign.left,
                  style: pw.TextStyle(
                    font: baseBoldFont,
                    fontSize: style.h2FontSize,
                    color: style.textColor,
                  ),
                ),
              ),
          ],
        ),
        if (style.showHeaderTitle || style.showLogo) pw.SizedBox(height: 8),
        pw.Divider(color: style.dividerColor, thickness: 0.5),
        pw.SizedBox(height: 8),
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
          final font = _font(section.text, fontMap, baseFont);
          final bold = _font(section.text, boldMap, baseBoldFont);
          final rtl = RtlUtils.isRtl(section.text);
          widgets
            ..add(
              _richText(
                section.text,
                font: font,
                boldFont: bold,
                size: style.bodyFontSize,
                color: style.textColor,
                lineHeight: style.bodyLineHeight,
                rtl: rtl,
                textAlign: style.paragraphAlignment,
              ),
            )
            ..add(pw.SizedBox(height: style.paragraphSpacing));
          break;

        case PdfSectionType.bullet:
          if (section.text.trim().isEmpty) break;
          
          // Clean up text — strip leading bullet markers if they were passed manually
          var cleanText = section.text.trim();
          final bulletStripRegex = RegExp(r'^([-•*+]|\d+\.)\s*');
          cleanText = cleanText.replaceFirst(bulletStripRegex, '');

          final font = _font(cleanText, fontMap, baseFont);
          final bold = _font(cleanText, boldMap, baseBoldFont);
          final rtl = RtlUtils.isRtl(cleanText);
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
                    cleanText,
                    font: font,
                    boldFont: bold,
                    size: style.bodyFontSize,
                    color: style.textColor,
                    lineHeight: style.bulletLineHeight,
                    rtl: rtl,
                    textAlign: style.paragraphAlignment,
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

        // markdown sections are already flattened in generate()
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
    final alignment = _convertAlignment(style.headingAlignment, rtl);
    final textAlign = _convertTextAlign(style.headingAlignment, rtl);

    return [
      pw.SizedBox(height: style.headingTopPadding),
      pw.Align(
        alignment: alignment,
        child: pw.Text(
          text,
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: textAlign,
          style: pw.TextStyle(
            font: font,
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ),
      pw.SizedBox(height: 6),
    ];
  }

  static pw.Widget _bulletRow(
    pw.Widget child, {
    required PdfStyle style,
    required bool rtl,
  }) {
    pw.Widget marker;

    switch (style.bulletShape) {
      case BulletShape.square:
        marker = pw.Container(
          width: style.bulletDotSize,
          height: style.bulletDotSize,
          decoration: pw.BoxDecoration(
            color: style.bulletColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
          ),
        );
        break;
      case BulletShape.dash:
        marker = pw.Container(
          width: style.bulletDotSize * 1.5,
          height: 1.5,
          color: style.bulletColor,
        );
        break;
      case BulletShape.tick:
        marker = pw.Text(
          '✓',
          style: pw.TextStyle(
            color: style.bulletColor,
            fontSize: style.bodyFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        );
        break;
      case BulletShape.circle:
        marker = pw.Container(
          width: style.bulletDotSize,
          height: style.bulletDotSize,
          decoration: pw.BoxDecoration(
            color: style.bulletColor,
            shape: pw.BoxShape.circle,
          ),
        );
    }

    final bulletMarker = pw.Padding(
      padding: pw.EdgeInsets.only(top: style.bulletShape == BulletShape.tick ? 0 : 6),
      child: marker,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rtl
          ? [pw.Expanded(child: child), pw.SizedBox(width: 8), bulletMarker]
          : [bulletMarker, pw.SizedBox(width: 8), pw.Expanded(child: child)],
    );
  }

  /// Builds a [pw.RichText] that renders **bold** inline markers.
  static pw.Widget _richText(
    String raw, {
    required pw.Font font,
    required pw.Font boldFont,
    required double size,
    required PdfColor color,
    required double lineHeight,
    required bool rtl,
    PdfTextAlign textAlign = PdfTextAlign.left,
  }) {
    final spans = <pw.TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;

    for (final match in boldRegex.allMatches(raw)) {
      if (match.start > cursor) {
        spans.add(
          pw.TextSpan(
            text: raw.substring(cursor, match.start),
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

    if (cursor < raw.length) {
      spans.add(
        pw.TextSpan(
          text: raw.substring(cursor),
          style: pw.TextStyle(font: font, fontSize: size, color: color),
        ),
      );
    }

    return pw.RichText(
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: _convertTextAlign(textAlign, rtl),
      text: pw.TextSpan(children: spans),
    );
  }

  static pw.TextAlign _convertTextAlign(PdfTextAlign align, bool rtl) {
    switch (align) {
      case PdfTextAlign.center:
        return pw.TextAlign.center;
      case PdfTextAlign.right:
        return pw.TextAlign.right;
      case PdfTextAlign.justify:
        return pw.TextAlign.justify;
      case PdfTextAlign.left:
        return rtl ? pw.TextAlign.right : pw.TextAlign.left;
    }
  }

  static pw.Alignment _convertAlignment(PdfTextAlign align, bool rtl) {
    switch (align) {
      case PdfTextAlign.center:
        return pw.Alignment.center;
      case PdfTextAlign.right:
        return pw.Alignment.centerRight;
      case PdfTextAlign.justify:
      case PdfTextAlign.left:
        return rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
    }
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
