import 'package:flutter/services.dart';

/// Caps input at a number of *digits*, ignoring formatting separators.
///
/// [LengthLimitingTextInputFormatter] counts characters, so a formatted
/// national number such as `7911 123 456` burns its budget on spaces and gets
/// truncated before the user finishes typing.
class DigitLimitingTextInputFormatter extends TextInputFormatter {
  const DigitLimitingTextInputFormatter(this.maxDigits);

  /// The maximum number of digits allowed, separators excluded.
  final int maxDigits;

  static final RegExp _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final int digitCount = newValue.text.replaceAll(_nonDigit, '').length;
    if (digitCount <= maxDigits) return newValue;
    // Over budget — keep what was already accepted.
    return oldValue;
  }
}
