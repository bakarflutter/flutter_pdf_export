import 'package:pdf/pdf.dart';

/// Shape of the bullet point markers.
enum BulletShape { circle, square, dash, tick }

/// Alignment for text in the document.
enum PdfTextAlign { left, center, right, justify }

/// Controls every visual aspect of the generated PDF.
///
/// All fields have sensible defaults so you can start with `PdfStyle()` and
/// only override what you need.
class PdfStyle {
  // ── Page layout ──────────────────────────────────────────────────────────

  /// The page format (default: A4).
  final PdfPageFormat pageFormat;

  /// Horizontal margin in points.
  final double horizontalMargin;

  /// Vertical margin in points.
  final double verticalMargin;

  // ── Colors ───────────────────────────────────────────────────────────────

  /// Primary accent color (used for H1 headings and decorative bar).
  final PdfColor accentColor;

  /// Main body text color.
  final PdfColor textColor;

  /// Subtitle / H3 heading color.
  final PdfColor subtitleColor;

  /// Divider / separator line color.
  final PdfColor dividerColor;

  /// Footer text color.
  final PdfColor footerColor;

  /// Bullet marker color.
  final PdfColor bulletColor;

  /// Page background color (default: white).
  final PdfColor backgroundColor;

  /// Whether to use a gradient-like header background (simulated).
  final bool useHeaderGradient;

  // ── Typography ───────────────────────────────────────────────────────────

  /// Font size for H1 headings.
  final double h1FontSize;

  /// Font size for H2 headings.
  final double h2FontSize;

  /// Font size for H3 headings.
  final double h3FontSize;

  /// Font size for body text.
  final double bodyFontSize;

  /// Font size for footer text.
  final double footerFontSize;

  /// Line height multiplier for body text.
  final double bodyLineHeight;

  /// Line height multiplier for bullet items.
  final double bulletLineHeight;

  // ── Header / Footer ──────────────────────────────────────────────────────

  /// Whether to show the accent-color bar at the top of each page.
  final bool showHeaderBar;

  /// Height of the header accent bar in points.
  final double headerBarHeight;

  /// Whether to show the document title in the header.
  final bool showHeaderTitle;

  /// Whether to show page numbers in the footer.
  final bool showPageNumbers;

  /// Custom footer left text (e.g. your app name). Pass null to hide.
  final String? footerLeftText;

  // ── Spacing ──────────────────────────────────────────────────────────────

  /// Vertical spacing after each paragraph / block.
  final double paragraphSpacing;

  /// Extra top padding before headings.
  final double headingTopPadding;

  /// Indent per level for nested bullets (in points).
  final double bulletIndentPerLevel;

  /// Bullet dot size in points.
  final double bulletDotSize;

  /// Shape of the bullet points.
  final BulletShape bulletShape;

  /// Alignment for headings (H1, H2, H3).
  final PdfTextAlign headingAlignment;

  /// Alignment for body text paragraphs.
  final PdfTextAlign paragraphAlignment;

  /// Whether to show a logo in the header (requires logoBytes in PdfDocumentData).
  final bool showLogo;

  /// Size of the logo in points.
  final double logoSize;

  const PdfStyle({
    this.pageFormat = PdfPageFormat.a4,
    this.horizontalMargin = 48,
    this.verticalMargin = 52,
    this.accentColor = const PdfColor.fromInt(0xFF1565C0), // More premium blue
    this.textColor = const PdfColor.fromInt(0xFF212121),
    this.subtitleColor = const PdfColor.fromInt(0xFF616161),
    this.dividerColor = const PdfColor.fromInt(0xFFE0E0E0),
    this.footerColor = const PdfColor.fromInt(0xFF9E9E9E),
    this.bulletColor = const PdfColor.fromInt(0xFF212121),
    this.backgroundColor = PdfColors.white,
    this.useHeaderGradient = false,
    this.h1FontSize = 24,
    this.h2FontSize = 20,
    this.h3FontSize = 16,
    this.bodyFontSize = 13,
    this.footerFontSize = 9,
    this.bodyLineHeight = 1.6,
    this.bulletLineHeight = 1.4,
    this.showHeaderBar = true,
    this.headerBarHeight = 3,
    this.showHeaderTitle = true,
    this.showPageNumbers = true,
    this.footerLeftText,
    this.paragraphSpacing = 6,
    this.headingTopPadding = 12,
    this.bulletIndentPerLevel = 14,
    this.bulletDotSize = 4,
    this.bulletShape = BulletShape.circle,
    this.headingAlignment = PdfTextAlign.left,
    this.paragraphAlignment = PdfTextAlign.left,
    this.showLogo = false,
    this.logoSize = 40,
  });

  /// Creates a copy of this style with the given fields replaced.
  PdfStyle copyWith({
    PdfPageFormat? pageFormat,
    double? horizontalMargin,
    double? verticalMargin,
    PdfColor? accentColor,
    PdfColor? textColor,
    PdfColor? subtitleColor,
    PdfColor? dividerColor,
    PdfColor? footerColor,
    PdfColor? bulletColor,
    PdfColor? backgroundColor,
    double? h1FontSize,
    double? h2FontSize,
    double? h3FontSize,
    double? bodyFontSize,
    double? footerFontSize,
    double? bodyLineHeight,
    double? bulletLineHeight,
    bool? showHeaderBar,
    double? headerBarHeight,
    bool? showHeaderTitle,
    bool? showPageNumbers,
    String? footerLeftText,
    double? paragraphSpacing,
    double? headingTopPadding,
    double? bulletIndentPerLevel,
    double? bulletDotSize,
    BulletShape? bulletShape,
    PdfTextAlign? headingAlignment,
    PdfTextAlign? paragraphAlignment,
    bool? showLogo,
    double? logoSize,
    bool? useHeaderGradient,
  }) {
    return PdfStyle(
      pageFormat: pageFormat ?? this.pageFormat,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      verticalMargin: verticalMargin ?? this.verticalMargin,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      dividerColor: dividerColor ?? this.dividerColor,
      footerColor: footerColor ?? this.footerColor,
      bulletColor: bulletColor ?? this.bulletColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      useHeaderGradient: useHeaderGradient ?? this.useHeaderGradient,
      h1FontSize: h1FontSize ?? this.h1FontSize,
      h2FontSize: h2FontSize ?? this.h2FontSize,
      h3FontSize: h3FontSize ?? this.h3FontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      footerFontSize: footerFontSize ?? this.footerFontSize,
      bodyLineHeight: bodyLineHeight ?? this.bodyLineHeight,
      bulletLineHeight: bulletLineHeight ?? this.bulletLineHeight,
      showHeaderBar: showHeaderBar ?? this.showHeaderBar,
      headerBarHeight: headerBarHeight ?? this.headerBarHeight,
      showHeaderTitle: showHeaderTitle ?? this.showHeaderTitle,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      footerLeftText: footerLeftText ?? this.footerLeftText,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      headingTopPadding: headingTopPadding ?? this.headingTopPadding,
      bulletIndentPerLevel: bulletIndentPerLevel ?? this.bulletIndentPerLevel,
      bulletDotSize: bulletDotSize ?? this.bulletDotSize,
      bulletShape: bulletShape ?? this.bulletShape,
      headingAlignment: headingAlignment ?? this.headingAlignment,
      paragraphAlignment: paragraphAlignment ?? this.paragraphAlignment,
      showLogo: showLogo ?? this.showLogo,
      logoSize: logoSize ?? this.logoSize,
    );
  }

  // ── Preset styles ─────────────────────────────────────────────────────────

  /// Clean light theme with a blue accent.
  static const PdfStyle light = PdfStyle(
    accentColor: PdfColor.fromInt(0xFF1565C0),
    textColor: PdfColor.fromInt(0xFF212121),
    subtitleColor: PdfColor.fromInt(0xFF616161),
    showHeaderBar: true,
  );

  /// Dark theme (charcoal background, white text).
  static const PdfStyle dark = PdfStyle(
    backgroundColor: PdfColor.fromInt(0xFF1E1E1E),
    accentColor: PdfColor.fromInt(0xFF00BCD4),
    textColor: PdfColors.white,
    subtitleColor: PdfColor.fromInt(0xFFB0BEC5),
    dividerColor: PdfColor.fromInt(0xFF424242),
    footerColor: PdfColor.fromInt(0xFF757575),
    showHeaderBar: true,
  );

  /// Minimal style — no decorative bar, generous whitespace.
  static const PdfStyle minimal = PdfStyle(
    showHeaderBar: false,
    horizontalMargin: 72,
    verticalMargin: 72,
    accentColor: PdfColor.fromInt(0xFF212121),
    bodyLineHeight: 1.8,
    paragraphSpacing: 10,
  );

  /// Warm parchment style for documents and reports.
  static const PdfStyle warm = PdfStyle(
    backgroundColor: PdfColor.fromInt(0xFFFFF8F0),
    accentColor: PdfColor.fromInt(0xFF8B4513),
    textColor: PdfColor.fromInt(0xFF3E2723),
    subtitleColor: PdfColor.fromInt(0xFF6D4C41),
    dividerColor: PdfColor.fromInt(0xFFD7C4A3),
    footerColor: PdfColor.fromInt(0xFF8D6E63),
  );
}
