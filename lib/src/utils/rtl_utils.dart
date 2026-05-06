/// Utilities for right-to-left text direction detection.
class RtlUtils {
  RtlUtils._();

  static final _rtlPattern = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF'
    r'\uFB50-\uFDFF\uFE70-\uFEFF' // Arabic
    r'\u0590-\u05FF]', // Hebrew
  );

  /// Returns true if [text] contains any RTL characters.
  static bool isRtl(String text) => _rtlPattern.hasMatch(text);
}
