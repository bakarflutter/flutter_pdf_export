import 'dart:typed_data';

/// Represents a discrete content block inside a [PdfDocumentData].
class PdfSection {
  final PdfSectionType type;
  final String text;
  final int level;

  /// For [PdfSectionType.image]: raw image bytes (PNG, JPEG, etc.).
  final Uint8List? imageBytes;

  /// For [PdfSectionType.image]: optional caption below the image.
  final String? caption;

  /// For [PdfSectionType.image]: max width as fraction of page width (0.0–1.0).
  final double imageWidthFraction;

  /// For [PdfSectionType.image]: 'left', 'center', or 'right'.
  final String imageAlignment;

  const PdfSection._({
    required this.type,
    required this.text,
    this.level = 0,
    this.imageBytes,
    this.caption,
    this.imageWidthFraction = 1.0,
    this.imageAlignment = 'center',
  });

  factory PdfSection.h1(String text) =>
      PdfSection._(type: PdfSectionType.h1, text: text);

  factory PdfSection.h2(String text) =>
      PdfSection._(type: PdfSectionType.h2, text: text);

  factory PdfSection.h3(String text) =>
      PdfSection._(type: PdfSectionType.h3, text: text);

  factory PdfSection.heading(String text) =>
      PdfSection._(type: PdfSectionType.h2, text: text);

  factory PdfSection.paragraph(String text) =>
      PdfSection._(type: PdfSectionType.paragraph, text: text);

  factory PdfSection.bullet(String text, {int level = 0}) =>
      PdfSection._(type: PdfSectionType.bullet, text: text, level: level);

  factory PdfSection.divider() =>
      const PdfSection._(type: PdfSectionType.divider, text: '');

  factory PdfSection.spacer() =>
      const PdfSection._(type: PdfSectionType.spacer, text: '');

  factory PdfSection.markdown(String markdown) =>
      PdfSection._(type: PdfSectionType.markdown, text: markdown);

  /// Embeds a raster image (PNG / JPEG) in the PDF.
  ///
  /// [imageBytes]     — raw file bytes; use File.readAsBytes() or image_picker.
  /// [caption]        — optional italic caption below the image.
  /// [widthFraction]  — 0.0–1.0, fraction of page body width (default 1.0).
  /// [alignment]      — 'left' | 'center' | 'right' (default 'center').
  factory PdfSection.image(
    Uint8List imageBytes, {
    String? caption,
    double widthFraction = 1.0,
    String alignment = 'center',
  }) {
    assert(widthFraction > 0 && widthFraction <= 1.0);
    assert(alignment == 'left' || alignment == 'center' || alignment == 'right');
    return PdfSection._(
      type: PdfSectionType.image,
      text: caption ?? '',
      imageBytes: imageBytes,
      caption: caption,
      imageWidthFraction: widthFraction,
      imageAlignment: alignment,
    );
  }
}

enum PdfSectionType {
  h1, h2, h3, paragraph, bullet, divider, spacer, markdown, image,
}