import 'dart:math';

import 'package:flutter/services.dart';
import 'package:intl_phone_number_input/src/utils/phone_number/phone_number_util.dart';
import 'package:intl_phone_number_input/src/utils/trunk_prefix.dart';

typedef OnInputFormatted<T> = void Function(T value);

/// [AsYouTypeFormatter] is a custom formatter that extends [TextInputFormatter]
/// which provides as you type validation and formatting for phone number inputted.
class AsYouTypeFormatter extends TextInputFormatter {
  /// Contains characters allowed as seperators.
  final RegExp separatorChars = RegExp(r'[^\d]+');

  /// The [allowedChars] contains [RegExp] for allowable phone number characters.
  final RegExp allowedChars = RegExp(r'[\d+]');

  final RegExp bracketsBetweenDigitsOrSpace =
      RegExp(r'(?![\s\d])([()])(?=[\d\s])');

  /// The [isoCode] of the [Country] formatting the phone number to
  final String isoCode;

  /// The [dialCode] of the [Country] formatting the phone number to
  final String dialCode;

  /// [onInputFormatted] is a callback that passes the formatted phone number
  final OnInputFormatted<TextEditingValue> onInputFormatted;

  /// Whether to drop a national trunk prefix as soon as it is unambiguously
  /// redundant — a Ghanaian `0241234567` becomes `241234567`.
  ///
  /// See [TrunkPrefix] for the countries this affects and the safety rules.
  final bool stripNationalPrefix;

  AsYouTypeFormatter(
      {required this.isoCode,
      required this.dialCode,
      required this.onInputFormatted,
      this.stripNationalPrefix = true});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    int oldValueLength = oldValue.text.length;
    int newValueLength = newValue.text.length;

    if (newValueLength > 0 && newValueLength > oldValueLength) {
      String newValueText = newValue.text;
      String rawText = newValueText.replaceAll(separatorChars, '');

      int rawCursorPosition = newValue.selection.end;

      int digitsBeforeCursor = 0, digitsAfterCursor = 0;

      if (rawCursorPosition > 0 && rawCursorPosition <= newValueText.length) {
        final rawTextBeforeCursor = newValueText
            .substring(0, rawCursorPosition)
            .replaceAll(separatorChars, '');
        final rawTextAfterCursor = newValueText
            .substring(rawCursorPosition)
            .replaceAll(separatorChars, '');

        digitsBeforeCursor = rawTextBeforeCursor.length;
        digitsAfterCursor = rawTextAfterCursor.length;
      }

      if (stripNationalPrefix) {
        final String corrected = TrunkPrefix.strip(rawText, isoCode);
        if (corrected.length < rawText.length) {
          // Keep the caret over the same digit it was over before the
          // prefix vanished from in front of it.
          digitsBeforeCursor =
              max(0, digitsBeforeCursor - (rawText.length - corrected.length));
          rawText = corrected;
        }
      }

      String textToParse = dialCode + rawText;

      formatAsYouType(input: textToParse).then(
        (String? value) {
          String parsedText = parsePhoneNumber(value);

          int newCursorPosition = 0;

          if (digitsBeforeCursor > 0 || digitsAfterCursor > 0) {
            for (var i = 0; i < parsedText.length; i++) {
              final startCursor = i;

              if (allowedChars.hasMatch(parsedText[startCursor])) {
                if (digitsBeforeCursor > 0) {
                  digitsBeforeCursor--;
                } else {
                  newCursorPosition = startCursor + 1;
                  break;
                }
              }

              final endCursor = parsedText.length - 1 - i;

              if (allowedChars.hasMatch(parsedText[endCursor])) {
                if (digitsAfterCursor > 0) {
                  digitsAfterCursor--;
                } else {
                  newCursorPosition = endCursor + 1;
                  break;
                }
              }
            }
          }

          newCursorPosition = min(max(newCursorPosition, 0), parsedText.length);

          this.onInputFormatted(
            TextEditingValue(
              text: parsedText,
              selection: TextSelection.collapsed(offset: newCursorPosition),
            ),
          );
        },
      );
    }

    return newValue;
  }

  /// Accepts [input], unformatted phone number and
  /// returns a [Future<String>] of the formatted phone number.
  Future<String?> formatAsYouType({required String input}) async {
    try {
      String? formattedPhoneNumber = await PhoneNumberUtil.formatAsYouType(
          phoneNumber: input, isoCode: isoCode);
      return formattedPhoneNumber;
    } on Exception {
      return '';
    }
  }

  /// Accepts a formatted [phoneNumber]
  /// returns a [String] of `phoneNumber` with the dialCode replaced with an empty String
  String parsePhoneNumber(String? phoneNumber) {
    final filteredPhoneNumber =
        phoneNumber?.replaceAll(bracketsBetweenDigitsOrSpace, '');

    if (dialCode.length > 4) {
      if (isPartOfNorthAmericanNumberingPlan(dialCode)) {
        String northAmericaDialCode = '+1';
        String countryDialCodeWithSpace = northAmericaDialCode +
            ' ' +
            dialCode.replaceFirst(northAmericaDialCode, '');

        return filteredPhoneNumber!
            .replaceFirst(countryDialCodeWithSpace, '')
            .replaceFirst(separatorChars, '')
            .trim();
      }
    }
    return filteredPhoneNumber!.replaceFirst(dialCode, '').trim();
  }

  /// Accepts a [dialCode]
  /// returns a [bool], true if the `dialCode` is part of North American Numbering Plan
  bool isPartOfNorthAmericanNumberingPlan(String dialCode) {
    return dialCode.contains('+1');
  }
}
