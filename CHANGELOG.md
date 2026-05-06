## [1.0.0] - 2026-05-06

### ✨ Initial Stable Release

- **PdfBuilder.generate(PdfDocumentData)** — single public entry point; returns `File`
- **PdfDocumentData**:
  - structured sections
  - markdown support
  - plain text support
- **PdfSection**:
  - headings (H1, H2, H3)
  - paragraphs with bold support
  - nested bullet lists
  - images with captions
  - dividers and spacing
- **PdfStyle**:
  - 25+ customizable properties
  - built-in presets: light, minimal, warm
- **FontResolver**:
  - automatic Noto font resolution for 20+ scripts
  - Arabic, Urdu, Chinese, Hindi, etc.
- RTL auto-detection
- Font caching (memory + disk)
- Markdown parsing support
- Multi-language document support
