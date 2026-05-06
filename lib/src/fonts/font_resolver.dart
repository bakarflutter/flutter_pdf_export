import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Resolves the correct [pw.Font] for any Unicode text.
///
/// Resolution order: **memory cache → disk cache → Google Fonts download**.
///
/// Supports Arabic, Hebrew, Devanagari, Bengali, Gurmukhi, Gujarati, Tamil,
/// Telugu, Kannada, Malayalam, Sinhala, Thai, Lao, Myanmar, Khmer, Ethiopic,
/// Georgian, Armenian, Korean, Chinese, and Latin scripts.
class FontResolver {
  FontResolver._();

  // ── In-memory cache ──────────────────────────────────────────────────────
  static final Map<String, pw.Font> _cache = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the best [pw.Font] for the dominant script in [text].
  static Future<pw.Font> fontFor(String text, {bool bold = false}) {
    final family = familyFor(text);
    return resolveFamily(family, bold: bold);
  }

  /// Returns the Noto font-family key for the dominant script in [text].
  static String familyFor(String text) => _detectFamily(text);

  /// Resolves a [pw.Font] by known [family] key (e.g. `'Noto+Naskh+Arabic'`).
  static Future<pw.Font> resolveFamily(String family, {bool bold = false}) =>
      _resolve(family, bold: bold);

  /// Pre-warms the cache for all unique font families needed by [texts].
  ///
  /// Call this once before building the PDF to avoid sequential downloads.
  static Future<void> preload(List<String> texts, {bool includeBold = true}) {
    final families = texts.map(familyFor).toSet();
    return Future.wait([
      for (final f in families) ...[
        resolveFamily(f),
        if (includeBold) resolveFamily(f, bold: true),
      ],
    ]);
  }

  /// Clears only the in-memory cache (disk cache is preserved).
  static void clearMemoryCache() => _cache.clear();

  // ── Script detection ──────────────────────────────────────────────────────

  static const _scriptMap = <String, String>{
    // Arabic (incl. Urdu, Persian, Pashto extended blocks)
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]':
        'Noto+Naskh+Arabic',
    r'[\u0590-\u05FF]': 'Noto+Sans+Hebrew',
    r'[\u0900-\u097F]': 'Noto+Sans+Devanagari',
    r'[\u0980-\u09FF]': 'Noto+Sans+Bengali',
    r'[\u0A00-\u0A7F]': 'Noto+Sans+Gurmukhi',
    r'[\u0A80-\u0AFF]': 'Noto+Sans+Gujarati',
    r'[\u0B00-\u0B7F]': 'Noto+Sans+Oriya',
    r'[\u0B80-\u0BFF]': 'Noto+Sans+Tamil',
    r'[\u0C00-\u0C7F]': 'Noto+Sans+Telugu',
    r'[\u0C80-\u0CFF]': 'Noto+Sans+Kannada',
    r'[\u0D00-\u0D7F]': 'Noto+Sans+Malayalam',
    r'[\u0D80-\u0DFF]': 'Noto+Sans+Sinhala',
    r'[\u0E00-\u0E7F]': 'Noto+Sans+Thai',
    r'[\u0E80-\u0EFF]': 'Noto+Sans+Lao',
    r'[\u1000-\u109F]': 'Noto+Sans+Myanmar',
    r'[\u1780-\u17FF]': 'Noto+Sans+Khmer',
    r'[\u1200-\u137F]': 'Noto+Sans+Ethiopic',
    r'[\u10A0-\u10FF]': 'Noto+Sans+Georgian',
    r'[\u0530-\u058F]': 'Noto+Sans+Armenian',
    r'[\u0400-\u04FF]': 'Noto+Sans', // Cyrillic — covered by NotoSans
    r'[\uAC00-\uD7FF\u1100-\u11FF]': 'Noto+Sans+KR',
    r'[\u3000-\u9FFF\uF900-\uFAFF]': 'Noto+Sans+SC',
  };

  static String _detectFamily(String text) {
    for (final entry in _scriptMap.entries) {
      if (RegExp(entry.key).hasMatch(text)) return entry.value;
    }
    return 'Noto+Sans'; // Latin / default
  }

  // ── Resolution: memory → disk → download ─────────────────────────────────

  static Future<pw.Font> _resolve(String family, {bool bold = false}) async {
    final key = bold ? '$family:bold' : family;

    if (_cache.containsKey(key)) return _cache[key]!;

    final file = await _cacheFile(family, bold: bold);
    if (await file.exists()) {
      debugPrint('📂 [FontResolver] Loaded from disk: $key');
      final bytes = await file.readAsBytes();
      final font = pw.Font.ttf(
        bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      return _cache[key] = font;
    }

    debugPrint('⬇️  [FontResolver] Downloading: $key');
    return _download(family, bold: bold, cacheKey: key);
  }

  static Future<pw.Font> _download(
    String family, {
    required bool bold,
    required String cacheKey,
  }) async {
    try {
      final font = await _fromGoogleFonts(family, bold: bold);
      _cache[cacheKey] = font;
      // Persist in background — don't await so we don't slow PDF generation
      _persistToDisk(family, bold: bold).ignore();
      return font;
    } catch (e) {
      debugPrint('⚠️  [FontResolver] Download failed for $cacheKey: $e');
      // Graceful fallback to Noto Sans
      return bold
          ? PdfGoogleFonts.notoSansBold()
          : PdfGoogleFonts.notoSansRegular();
    }
  }

  // ── Google Fonts dispatch ─────────────────────────────────────────────────

  static Future<pw.Font> _fromGoogleFonts(
    String family, {
    bool bold = false,
  }) async {
    if (bold) return _boldFont(family);
    return _regularFont(family);
  }

  static Future<pw.Font> _regularFont(String family) async {
    switch (family) {
      case 'Noto+Naskh+Arabic':
        return PdfGoogleFonts.notoNaskhArabicRegular();
      case 'Noto+Sans+Hebrew':
        return PdfGoogleFonts.notoSansHebrewRegular();
      case 'Noto+Sans+Devanagari':
        return PdfGoogleFonts.notoSansDevanagariRegular();
      case 'Noto+Sans+Bengali':
        return PdfGoogleFonts.notoSansBengaliRegular();
      case 'Noto+Sans+Gurmukhi':
        return PdfGoogleFonts.notoSansGurmukhiRegular();
      case 'Noto+Sans+Gujarati':
        return PdfGoogleFonts.notoSansGujaratiRegular();
      case 'Noto+Sans+Tamil':
        return PdfGoogleFonts.notoSansTamilRegular();
      case 'Noto+Sans+Telugu':
        return PdfGoogleFonts.notoSansTeluguRegular();
      case 'Noto+Sans+Kannada':
        return PdfGoogleFonts.notoSansKannadaRegular();
      case 'Noto+Sans+Malayalam':
        return PdfGoogleFonts.notoSansMalayalamRegular();
      case 'Noto+Sans+Sinhala':
        return PdfGoogleFonts.notoSansSinhalaRegular();
      case 'Noto+Sans+Thai':
        return PdfGoogleFonts.notoSansThaiRegular();
      case 'Noto+Sans+Lao':
        return PdfGoogleFonts.notoSansLaoRegular();
      case 'Noto+Sans+Myanmar':
        return PdfGoogleFonts.notoSansMyanmarRegular();
      case 'Noto+Sans+Khmer':
        return PdfGoogleFonts.notoSansKhmerRegular();
      case 'Noto+Sans+Ethiopic':
        return PdfGoogleFonts.notoSansEthiopicRegular();
      case 'Noto+Sans+Georgian':
        return PdfGoogleFonts.notoSansGeorgianRegular();
      case 'Noto+Sans+Armenian':
        return PdfGoogleFonts.notoSansArmenianRegular();
      case 'Noto+Sans+KR':
        return PdfGoogleFonts.notoSansKRRegular();
      case 'Noto+Sans+SC':
        return PdfGoogleFonts.notoSansSCRegular();
      default:
        return PdfGoogleFonts.notoSansRegular();
    }
  }

  static Future<pw.Font> _boldFont(String family) async {
    switch (family) {
      case 'Noto+Naskh+Arabic':
        return PdfGoogleFonts.notoNaskhArabicBold();
      case 'Noto+Sans+Hebrew':
        return PdfGoogleFonts.notoSansHebrewBold();
      case 'Noto+Sans+Devanagari':
        return PdfGoogleFonts.notoSansDevanagariBold();
      case 'Noto+Sans+Bengali':
        return PdfGoogleFonts.notoSansBengaliBold();
      case 'Noto+Sans+Gurmukhi':
        return PdfGoogleFonts.notoSansGurmukhiBold();
      case 'Noto+Sans+Gujarati':
        return PdfGoogleFonts.notoSansGujaratiBold();
      case 'Noto+Sans+Tamil':
        return PdfGoogleFonts.notoSansTamilBold();
      case 'Noto+Sans+Telugu':
        return PdfGoogleFonts.notoSansTeluguBold();
      case 'Noto+Sans+Kannada':
        return PdfGoogleFonts.notoSansKannadaBold();
      case 'Noto+Sans+Malayalam':
        return PdfGoogleFonts.notoSansMalayalamBold();
      case 'Noto+Sans+Sinhala':
        return PdfGoogleFonts.notoSansSinhalaBold();
      case 'Noto+Sans+Thai':
        return PdfGoogleFonts.notoSansThaiBold();
      case 'Noto+Sans+Lao':
        return PdfGoogleFonts.notoSansLaoBold();
      case 'Noto+Sans+Myanmar':
        return PdfGoogleFonts.notoSansMyanmarBold();
      case 'Noto+Sans+Khmer':
        return PdfGoogleFonts.notoSansKhmerBold();
      case 'Noto+Sans+Ethiopic':
        return PdfGoogleFonts.notoSansEthiopicBold();
      case 'Noto+Sans+Georgian':
        return PdfGoogleFonts.notoSansGeorgianBold();
      case 'Noto+Sans+Armenian':
        return PdfGoogleFonts.notoSansArmenianBold();
      case 'Noto+Sans+KR':
        return PdfGoogleFonts.notoSansKRBold();
      case 'Noto+Sans+SC':
        return PdfGoogleFonts.notoSansSCBold();
      default:
        return PdfGoogleFonts.notoSansBold();
    }
  }

  // ── Disk persistence ──────────────────────────────────────────────────────

  static Future<File> _cacheFile(String family, {bool bold = false}) async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/flutter_pdf_export/fonts');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    final suffix = bold ? '_bold' : '_regular';
    final name = '${family.replaceAll('+', '_').toLowerCase()}$suffix.ttf';
    return File('${cacheDir.path}/$name');
  }

  static Future<void> _persistToDisk(
    String family, {
    bool bold = false,
  }) async {
    try {
      final file = await _cacheFile(family, bold: bold);
      if (await file.exists()) return;

      final weight = bold ? '700' : '400';
      final encodedFamily = Uri.encodeComponent(
        family.replaceAll('+', ' '),
      );
      final cssUrl =
          'https://fonts.googleapis.com/css2?family=$encodedFamily:wght@$weight&display=swap';

      final cssResp = await HttpClient().getUrl(Uri.parse(cssUrl)).then((req) {
        req.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        );
        return req.close();
      });

      final css = await cssResp
          .transform(const SystemEncoding().decoder)
          .join();

      final ttfMatch = RegExp(r'url\((https://[^)]+\.ttf)\)').firstMatch(css);
      if (ttfMatch == null) return;

      final ttfResp = await HttpClient()
          .getUrl(Uri.parse(ttfMatch.group(1)!))
          .then((r) => r.close());

      final List<int> bytes = [];
      await for (final chunk in ttfResp) {
        bytes.addAll(chunk);
      }

      await file.writeAsBytes(bytes, flush: true);
      debugPrint('💾 [FontResolver] Cached to disk: ${file.path}');
    } catch (e) {
      debugPrint('⚠️  [FontResolver] Disk persist failed for $family: $e');
    }
  }
}
