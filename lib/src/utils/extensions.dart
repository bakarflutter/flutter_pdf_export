import 'dart:io';
import '../builders/pdf_builder.dart';
import '../models/pdf_document_data.dart';
import '../models/pdf_style.dart';

/// Simplifies PDF generation by adding extension methods to [String] and [PdfDocumentData].
extension PdfExportExtension on String {
  /// Directly converts a markdown string to a PDF file.
  ///
  /// ```dart
  /// final file = await "# Hello World".toPdfFile(title: 'My Document');
  /// ```
  Future<File> toPdfFile({
    required String title,
    String? subtitle,
    String? author,
    PdfStyle style = const PdfStyle(),
    String? outputFileName,
  }) async {
    final data = PdfDocumentData.fromMarkdown(
      title: title,
      markdown: this,
      subtitle: subtitle,
      author: author,
      style: style,
      outputFileName: outputFileName,
    );
    return PdfBuilder.generate(data);
  }
}

extension PdfDocumentDataExtension on PdfDocumentData {
  /// Convenience method to generate a PDF from the document data.
  ///
  /// ```dart
  /// final data = PdfDocumentData(title: '...', markdownBody: '...');
  /// final file = await data.generate();
  /// ```
  Future<File> generate() {
    return PdfBuilder.generate(this);
  }
}
