## Features

- 🌍 **21 scripts supported** — Arabic, Urdu, Hebrew, Hindi, Bengali, Gujarati, Tamil, Telugu, Kannada, Malayalam, Sinhala, Thai, Lao, Myanmar, Khmer, Ethiopic, Georgian, Armenian, Korean, Chinese, Latin
- 🔤 **Font auto-detection** — resolved per paragraph, not per document
- ↔️ **RTL auto-detection** — Arabic and Hebrew paragraphs are right-aligned automatically
- 🖼 **Image & Logo support** — embed images and brand your document with a logo
- 🎯 **Proper Decoration** — clean bullet starts, multiple bullet shapes (Circle, Square, Dash, Tick), and alignment control
- ⚡ **Simplified API** — generate PDFs directly from `String` or `PdfDocumentData`
- **`**bold**`** **inline formatting** — works in paragraphs and bullets
- 📝 **Enhanced Markdown parser** — cleaner detection of bullets even with "dirty" input
- 🎨 **Premium Styling** — colors, font sizes, margins, header bars, footer text, page formats
- 📦 **4 preset styles** — `PdfStyle.light`, `.dark`, `.minimal`, `.warm`
- 💾 **Disk font cache** — downloaded once, persisted between sessions
- 📄 **Returns `dart:io File`** — integrate with `share_plus`, `open_file`, `file_saver`, or any package

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_pdf_export: ^1.0.0
```

Then run:

```sh
flutter pub get
```

---

### Simplified Usage (via Extensions)

```dart
import 'package:flutter_pdf_export/flutter_pdf_export.dart';

// Convert any markdown string directly to a PDF File
final file = await """
# My Report
This is a **totally clean** PDF with a simple API.

- Proper bullets
- Custom decoration
- Premium feel
""".toPdfFile(
  title: 'My Document',
  style: PdfStyle.light,
);
```

### Advanced Usage (from Markdown)

```dart
final file = await PdfBuilder.generate(
  PdfDocumentData.fromMarkdown(
    title: 'My Report',
    logoBytes: myLogoBytes, // Add your logo!
    markdown: '''
# Introduction
This is **bold** and this is normal.

## Arabic
هذا نص عربي — font and RTL detected automatically.

- Bullet one
- Bullet two
  - Nested bullet
''',
  ),
);
```

### From Structured Sections

```dart
final file = await PdfBuilder.generate(
  PdfDocumentData(
    title: 'My Document',
    author: 'My App',
    style: PdfStyle.light.copyWith(
      footerLeftText: 'My App',
      showPageNumbers: true,
    ),
    sections: [
      // Image — PNG/JPEG bytes from File, image_picker, or assets
      PdfSection.image(
        imageBytes,
        caption: 'Figure 1 — Sample image',
        widthFraction: 0.9,   // 90% of page width
        alignment: 'center',  // 'left' | 'center' | 'right'
      ),

      PdfSection.h1('Hello, PDF!'),
      PdfSection.h2('Sub Heading'),
      PdfSection.paragraph('Regular text with **bold** inline.'),

      // Arabic — RTL detected automatically, no config needed
      PdfSection.paragraph('هذا نص عربي. يتم اكتشاف الخط تلقائيًا.'),

      PdfSection.bullet('First bullet'),
      PdfSection.bullet('Second bullet'),
      PdfSection.bullet('Nested', level: 1),

      PdfSection.divider(),
      PdfSection.paragraph('Done.'),
    ],
  ),
);
```

---

## Providing Image Bytes

```dart
// From flutter assets
final data = await rootBundle.load('assets/my_image.png');
final bytes = data.buffer.asUint8List();

// From a dart:io File (e.g. file_picker, image_picker)
final bytes = await File('/path/to/image.jpg').readAsBytes();

// From image_picker
final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
final bytes = await xfile!.readAsBytes();
```

---

## Styles

### Use a preset

```dart
style: PdfStyle.dark     // charcoal background, white text
style: PdfStyle.light    // clean white, blue accent
style: PdfStyle.minimal  // no bar, wide margins
style: PdfStyle.warm     // parchment background
```

### Customise with `copyWith`

```dart
style: PdfStyle.light.copyWith(
  accentColor: const PdfColor.fromInt(0xFF6200EE),
  footerLeftText: 'My App',
  showHeaderBar: true,
  showPageNumbers: true,
  bodyFontSize: 14,
  horizontalMargin: 56,
),
```

### Build from scratch

```dart
style: const PdfStyle(
  pageFormat: PdfPageFormat.letter,
  accentColor: PdfColor.fromInt(0xFF1565C0),
  textColor: PdfColor.fromInt(0xFF212121),
  backgroundColor: PdfColors.white,
  h1FontSize: 26,
  h2FontSize: 20,
  bodyFontSize: 13,
  bodyLineHeight: 1.8,
  showHeaderBar: true,
  headerBarHeight: 5,
  footerLeftText: 'Company Name',
  showPageNumbers: true,
  horizontalMargin: 48,
  verticalMargin: 52,
),
```

---

## PdfSection Reference

| Factory                                                      | Description                          |
| ------------------------------------------------------------ | ------------------------------------ |
| `PdfSection.h1(text)`                                        | H1 heading — accent color            |
| `PdfSection.h2(text)`                                        | H2 heading — body color              |
| `PdfSection.h3(text)`                                        | H3 heading — subtitle color          |
| `PdfSection.heading(text)`                                   | Alias for `h2`                       |
| `PdfSection.paragraph(text)`                                 | Body text, supports `**bold**`       |
| `PdfSection.bullet(text, level: 0)`                          | Bullet item, `level` = nesting depth |
| `PdfSection.image(bytes, caption, widthFraction, alignment)` | Embedded image                       |
| `PdfSection.divider()`                                       | Horizontal rule                      |
| `PdfSection.spacer()`                                        | Vertical whitespace                  |
| `PdfSection.markdown(text)`                                  | Raw markdown, parsed automatically   |

---

| Property               | Type                   | Default    | Description                        |
| ---------------------- | ---------------------- | ---------- | ---------------------------------- |
| `pageFormat`           | `PdfPageFormat`        | A4         | Page size                          |
| `horizontalMargin`     | `double`               | 48         | Left/right margin in points        |
| `verticalMargin`       | `double`               | 52         | Top/bottom margin in points        |
| `accentColor`          | `PdfColor`             | Blue       | H1 heading + header bar + bullets  |
| `textColor`            | `PdfColor`             | Near-black | Body text and H2 color             |
| `subtitleColor`        | `PdfColor`             | Grey       | H3 and caption color               |
| `backgroundColor`      | `PdfColor`             | White      | Page background                    |
| `h1FontSize`           | `double`               | 24         | H1 font size in points             |
| `h2FontSize`           | `double`               | 20         | H2 font size in points             |
| `h3FontSize`           | `double`               | 16         | H3 font size in points             |
| `bodyFontSize`         | `double`               | 13         | Paragraph and bullet font size     |
| `bodyLineHeight`       | `double`               | 1.6        | Line height multiplier             |
| `showHeaderBar`        | `bool`                 | true       | Accent bar at top of each page     |
| `headerBarHeight`      | `double`               | 3          | Bar height in points               |
| `showHeaderTitle`      | `bool`                 | true       | Show document title in header      |
| `showLogo`             | `bool`                 | false      | Enable logo in header              |
| `logoSize`             | `double`               | 40         | Logo height/width                  |
| `headingAlignment`     | `PdfHeadingAlignment`  | Left/Auto  | Left, Center, or Right             |
| `bulletShape`          | `BulletShape`          | Circle     | Circle, Square, Dash, or Tick      |
| `showPageNumbers`      | `bool`                 | true       | Page N / Total in footer           |
| `footerLeftText`       | `String?`              | null       | Left footer text (e.g. app name)   |
| `bulletIndentPerLevel` | `double`               | 16         | Points of indent per nesting level |

---

## Supported Scripts

| Script                       | Font Used            |
| ---------------------------- | -------------------- |
| Latin, Cyrillic              | Noto Sans            |
| Arabic, Urdu, Persian        | Noto Naskh Arabic    |
| Hebrew                       | Noto Sans Hebrew     |
| Hindi / Marathi (Devanagari) | Noto Sans Devanagari |
| Bengali                      | Noto Sans Bengali    |
| Punjabi (Gurmukhi)           | Noto Sans Gurmukhi   |
| Gujarati                     | Noto Sans Gujarati   |
| Tamil                        | Noto Sans Tamil      |
| Telugu                       | Noto Sans Telugu     |
| Kannada                      | Noto Sans Kannada    |
| Malayalam                    | Noto Sans Malayalam  |
| Sinhala                      | Noto Sans Sinhala    |
| Thai                         | Noto Sans Thai       |
| Lao                          | Noto Sans Lao        |
| Myanmar                      | Noto Sans Myanmar    |
| Khmer                        | Noto Sans Khmer      |
| Ethiopic                     | Noto Sans Ethiopic   |
| Georgian                     | Noto Sans Georgian   |
| Armenian                     | Noto Sans Armenian   |
| Korean                       | Noto Sans KR         |
| Chinese (Simplified)         | Noto Sans SC         |

Fonts are downloaded from Google Fonts on first use, then cached to disk permanently.

---

## Advanced: FontResolver

```dart
// Detect which font family a string needs
final family = FontResolver.familyFor('مرحبا'); // 'Noto+Naskh+Arabic'

// Pre-warm the cache before building a PDF (parallel downloads)
await FontResolver.preload(['Hello', 'مرحبا', 'こんにちは']);

// Resolve a font directly (useful for custom pw.Document builds)
final font = await FontResolver.resolveFamily('Noto+Sans+Devanagari', bold: true);
```

---

## Showing a Preview

Use the `printing` package's `PdfPreview` widget (already a transitive dependency):

```dart
import 'package:printing/printing.dart';

Navigator.push(context, MaterialPageRoute(
  builder: (_) => Scaffold(
    appBar: AppBar(title: const Text('Preview')),
    body: PdfPreview(
      build: (format) => file.readAsBytes(),
      pdfFileName: 'my_document.pdf',
    ),
  ),
));
```

---

## Dependencies

| Package         | Version | Purpose                            |
| --------------- | ------- | ---------------------------------- |
| `pdf`           | ^3.10.8 | PDF generation engine              |
| `printing`      | ^5.13.1 | Google Fonts download + PdfPreview |
| `path_provider` | ^2.1.3  | Disk font cache directory          |

---

## License

MIT © 2025 — see [LICENSE](LICENSE)

## Developed by ABOU BAKAR - ab.dev.pk@gmail.com
