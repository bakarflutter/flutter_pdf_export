
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:flutter_pdf_export/flutter_pdf_export.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  // ── Load a dummy image from assets ──────────────────────────────────────
  // In your real app, use image_picker or File.readAsBytes() instead.
  Future<Uint8List> _loadDummyImage() async {
    final data = await rootBundle.load('assets/sample.png');
    return data.buffer.asUint8List();
  }

  Future<void> _exportPdf() async {
    setState(() => _loading = true);

    try {
      final imageBytes = await _loadDummyImage();

      // ── Build the document ─────────────────────────────────────────────
      final data = PdfDocumentData(
        title: 'My First PDF',
        author: 'My App',
        style: PdfStyle.light.copyWith(
          footerLeftText: 'My App',
          showPageNumbers: true,
        ),
        sections: [
          // ── Image (PNG / JPEG bytes) ───────────────────────────────────
          PdfSection.image(
            imageBytes,
            caption: 'This is a sample image',
            widthFraction: 0.8, // 80% of page width
            alignment: 'center',
          ),

          PdfSection.spacer(),

          // ── Headings ───────────────────────────────────────────────────
          PdfSection.h1('Hello, PDF!'),
          PdfSection.h2('This is a subtitle'),

          // ── Paragraphs — **bold** works inline ─────────────────────────
          PdfSection.paragraph(
            'This is a regular paragraph. You can use **bold text** inline '
            'anywhere. The font is picked automatically for every script.',
          ),

          // ── Arabic / RTL — auto detected, no config needed ─────────────
          PdfSection.h2('Arabic Section'),
          PdfSection.paragraph('هذا نص عربي. يتم اكتشاف الخط تلقائيًا.'),

          // ── Bullet list ────────────────────────────────────────────────
          PdfSection.h2('Features'),
          PdfSection.bullet('Automatic font detection'),
          PdfSection.bullet('RTL support (Arabic, Urdu, Hebrew)'),
          PdfSection.bullet('Bold inline formatting'),
          PdfSection.bullet('  Nested bullet (2-space indent)', level: 1),

          PdfSection.divider(),

          PdfSection.paragraph('That is all! File is ready to share or save.'),
        ],
      );

      // ── Generate → returns a dart:io File in temp dir ──────────────────
      final file = await PdfBuilder.generate(data);

      if (!mounted) return;

      // ── Show preview — user decides to save/share from here ─────────────
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfPreviewScreen(file: file)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Export Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dummy image preview ──────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/sample.png',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 24),

            // ── Dummy content ────────────────────────────────────────────
            const Text(
              'My First PDF',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This example shows how to embed an image and text into a PDF. '
              'Tap Export PDF to generate it and preview it.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'هذا نص عربي — Arabic auto-detected!',
              style: TextStyle(fontSize: 15),
              textDirection: TextDirection.rtl,
            ),

            const Spacer(),

            // ── Export button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _exportPdf,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_loading ? 'Generating…' : 'Export PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview screen — uses printing package's PdfPreview widget
// User can print / share from here using the built-in toolbar
// ─────────────────────────────────────────────────────────────────────────────
class PdfPreviewScreen extends StatelessWidget {
  final dynamic file; // dart:io File

  const PdfPreviewScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: PdfPreview(
        build: (format) => file.readAsBytes(),
        canDebug: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'my_document.pdf',
        // allowPrinting: true  ← user can print from here
        // allowSharing: true   ← user can share from here
        //
        // Or add your own action:
        // actions: [
        //   PdfPreviewAction(
        //     icon: const Icon(Icons.share),
        //     onPressed: (ctx, build, fmt) =>
        //         Share.shareXFiles([XFile(file.path)]),
        //   ),
        // ],
      ),
    );
  }
}
