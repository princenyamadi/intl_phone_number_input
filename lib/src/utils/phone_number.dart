import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dlibphonenumber/dlibphonenumber.dart' as p;
import 'package:equatable/equatable.dart';
import 'package:intl_phone_number_input/src/models/country_list.dart';
import 'package:intl_phone_number_input/src/utils/phone_number/phone_number_util.dart';

/// Types of phone numbers as defined by libphonenumber.
///
/// These types help categorize phone numbers based on their intended use
/// and billing characteristics.
enum PhoneNumberType {
  /// Fixed line phones (landlines)
  FIXED_LINE, // : 0,

  /// Mobile/cellular phones
  MOBILE, //: 1,

  /// Numbers that could be either fixed line or mobile
  FIXED_LINE_OR_MOBILE, //: 2,

  /// Toll-free numbers (typically free to call)
  TOLL_FREE, //: 3,

  /// Premium rate numbers (typically expensive to call)
  PREMIUM_RATE, //: 4,

  /// Shared cost numbers (caller and receiver share the cost)
  SHARED_COST, //: 5,

  /// Voice over IP numbers
  VOIP, //: 6,

  /// Personal numbers (typically redirect to user's actual number)
  PERSONAL_NUMBER, //: 7,

  /// Pager numbers
  PAGER, //: 8,

  /// Universal Access Numbers (company numbers that route to local offices)
  UAN, //: 9,

  /// Voicemail access numbers
  VOICEMAIL, //: 10,

  /// Unknown or unrecognized number type
  UNKNOWN, //: -1
}

/// Represents a phone number with its associated country and formatting information.
///
/// This class encapsulates all the necessary information about a phone number
/// including the number itself, its country code, dial code, and provides
/// methods for validation and formatting.
///
/// ## Example Usage
/// ```dart
/// // Create a phone number
/// PhoneNumber number = PhoneNumber(
///   phoneNumber: '+1234567890',
///   isoCode: 'US',
///   dialCode: '+1',
/// );
///
/// // Get region info from a phone number string
/// PhoneNumber info = await PhoneNumber.getRegionInfoFromPhoneNumber(
///   '+1234567890',
///   'US'
/// );
///
/// // Get a parsable number format
/// String parsable = await PhoneNumber.getParsableNumber(number);
/// ```
class PhoneNumber extends Equatable {
  /// The phone number string, either formatted or unformatted.
  ///
  /// This can contain the full international number (e.g., '+1234567890')
  /// or just the national number (e.g., '234567890') depending on context.
  final String? phoneNumber;

  /// The international dialing code for the country (e.g., '+1' for US/Canada).
  ///
  /// This includes the plus sign and represents the country calling code
  /// that must be dialed before the national number when calling internationally.
  final String? dialCode;

  /// The ISO 3166-1 alpha-2 country code (e.g., 'US', 'GB', 'FR').
  ///
  /// This is a two-letter country code that uniquely identifies the country
  /// associated with this phone number.
  final String? isoCode;

  /// Internal hash value used for object comparison.
  ///
  /// This is automatically generated when the object is created and is used
  /// internally for equality comparisons and debugging.
  final int _hash;

  /// Returns the hash value for this phone number instance.
  ///
  /// This hash is generated when the object is created and can be used
  /// to compare different instances of [PhoneNumber] objects.
  int get hash => _hash;

  @override
  List<Object?> get props => [phoneNumber, isoCode, dialCode];

  /// Creates a new [PhoneNumber] instance.
  ///
  /// All parameters are optional and can be null. The hash value is automatically
  /// generated for object comparison purposes.
  ///
  /// Example:
  /// ```dart
  /// PhoneNumber number = PhoneNumber(
  ///   phoneNumber: '+1234567890',
  ///   dialCode: '+1',
  ///   isoCode: 'US',
  /// );
  /// ```
  PhoneNumber({
    this.phoneNumber,
    this.dialCode,
    this.isoCode,
  }) : _hash = 1000 + Random().nextInt(99999 - 1000);

  @override
  String toString() {
    return 'PhoneNumber(phoneNumber: $phoneNumber, dialCode: $dialCode, isoCode: $isoCode)';
  }

  /// Extracts region information from a phone number string.
  ///
  /// This static method takes a phone number string and an optional ISO code,
  /// then returns a [PhoneNumber] object with complete region information
  /// including the proper formatting and country details.
  ///
  /// ## Parameters
  /// * [phoneNumber] - The phone number string to analyze (required)
  /// * [isoCode] - The ISO country code hint (optional, defaults to empty string)
  ///
  /// ## Returns
  /// A [Future<PhoneNumber>] containing the parsed phone number with region info.
  ///
  /// ## Throws
  /// * [AssertionError] if phoneNumber is empty
  /// * [Exception] if the phone number format is invalid or unrecognized
  ///
  /// ## Example
  /// ```dart
  /// try {
  ///   PhoneNumber result = await PhoneNumber.getRegionInfoFromPhoneNumber(
  ///     '+1234567890',
  ///     'US' // Optional hint
  ///   );
  ///   print('Country: ${result.isoCode}');
  ///   print('Dial Code: ${result.dialCode}');
  ///   print('Formatted: ${result.phoneNumber}');
  /// } catch (e) {
  ///   print('Invalid phone number: $e');
  /// }
  /// ```
  ///
  /// ## Note
  /// It's recommended to provide the [isoCode] parameter when possible,
  /// as it helps with accurate parsing of ambiguous number formats.
  static Future<PhoneNumber> getRegionInfoFromPhoneNumber(
    String phoneNumber, [
    String isoCode = '',
  ]) async {
    RegionInfo regionInfo = await PhoneNumberUtil.getRegionInfo(
        phoneNumber: phoneNumber, isoCode: isoCode);

    String? internationalPhoneNumber =
        await PhoneNumberUtil.normalizePhoneNumber(
      phoneNumber: phoneNumber,
      isoCode: regionInfo.isoCode ?? isoCode,
    );

    return PhoneNumber(
      phoneNumber: internationalPhoneNumber,
      dialCode: regionInfo.regionPrefix,
      isoCode: regionInfo.isoCode,
    );
  }

  /// Converts a [PhoneNumber] object to a formatted parsable string.
  ///
  /// This static method takes a [PhoneNumber] object and returns a formatted
  /// phone number string that can be easily parsed and used in forms or displays.
  /// The returned string excludes the country dial code.
  ///
  /// ## Parameters
  /// * [phoneNumber] - The [PhoneNumber] object to format (required)
  ///
  /// ## Returns
  /// A [Future<String>] containing the formatted phone number without dial code.
  ///
  /// ## Throws
  /// * [Exception] if the ISO code is null or invalid
  ///
  /// ## Example
  /// ```dart
  /// PhoneNumber number = PhoneNumber(
  ///   phoneNumber: '+1234567890',
  ///   dialCode: '+1',
  ///   isoCode: 'US',
  /// );
  ///
  /// String formatted = await PhoneNumber.getParsableNumber(number);
  /// print(formatted); // Output: "234 567 890" (without +1)
  /// ```
  static Future<String> getParsableNumber(PhoneNumber phoneNumber) async {
    if (phoneNumber.isoCode == null) {
      throw Exception('ISO Code is "${phoneNumber.isoCode}"');
    }
    return phoneNumber.formattedNationalNumber;
  }

  /// Returns the phone number string without the country dial code.
  ///
  /// This instance method provides a convenient way to get the national
  /// phone number without the international dial code prefix.
  ///
  /// ## Returns
  /// A [String] containing the phone number with the dial code removed.
  ///
  /// ## Example
  /// ```dart
  /// PhoneNumber number = PhoneNumber(
  ///   phoneNumber: '+1234567890',
  ///   dialCode: '+1',
  ///   isoCode: 'US',
  /// );
  ///
  /// String national = number.parseNumber();
  /// print(national); // Output: "234567890"
  /// ```
  String parseNumber() => nationalNumber;

  /// The subscriber digits for this number: the country calling code and any
  /// national trunk prefix removed, no separators.
  ///
  /// `+233241234567` (GH) -> `241234567`
  /// `+12125551111`  (US) -> `2125551111`  (every `1` preserved)
  String get nationalNumber {
    final String raw = phoneNumber ?? '';
    if (raw.isEmpty) return '';

    // Metadata-driven extraction. This is the only approach that is correct in
    // general — a textual strip of the dial code corrupts any number whose own
    // digits repeat the dial code.
    try {
      final parsed = PhoneNumberUtil.phoneUtil
          .parse(raw, (isoCode ?? '').toUpperCase());
      final nsn = PhoneNumberUtil.phoneUtil.getNationalSignificantNumber(parsed);
      if (nsn.isNotEmpty) return nsn;
    } catch (_) {
      // Unparseable (e.g. still being typed) — fall through.
    }

    // Fallback: strip the dial code, anchored to the start and escaped, so a
    // partially typed number still yields something sensible.
    final String dcDigits = (dialCode ?? '').replaceAll(RegExp(r'\D'), '');
    if (dcDigits.isEmpty) return raw.replaceAll(RegExp(r'\D'), '');
    return raw
        .replaceFirst(RegExp('^\\+?${RegExp.escape(dcDigits)}'), '')
        .replaceAll(RegExp(r'\D'), '');
  }

  /// Whether this is a valid number for its region, per libphonenumber.
  ///
  /// Synchronous, so it can be used directly inside a form validator without
  /// the one-frame lag of the `onInputValidated` callback.
  bool get isValid {
    final String raw = phoneNumber ?? '';
    if (raw.isEmpty) return false;
    try {
      final parsed = PhoneNumberUtil.phoneUtil
          .parse(raw, (isoCode ?? '').toUpperCase());
      return PhoneNumberUtil.phoneUtil.isValidNumber(parsed);
    } catch (_) {
      return false;
    }
  }

  /// The national number formatted for display, without the dial code —
  /// what belongs in the text field while the selector shows the country.
  ///
  /// `+233241234567` (GH) -> `24 123 4567`
  ///
  /// Note this deliberately differs from libphonenumber's NATIONAL format,
  /// which re-adds the trunk prefix (`024 123 4567`).
  String get formattedNationalNumber {
    final String raw = phoneNumber ?? '';
    if (raw.isEmpty) return '';
    try {
      final parsed = PhoneNumberUtil.phoneUtil
          .parse(raw, (isoCode ?? '').toUpperCase());
      final String international = PhoneNumberUtil.phoneUtil
          .format(parsed, p.PhoneNumberFormat.international);
      final String cc = '+${parsed.countryCode}';
      return international.startsWith(cc)
          ? international.substring(cc.length).trim()
          : international;
    } catch (_) {
      return nationalNumber;
    }
  }

  /// Builds a fully populated [PhoneNumber] from whatever a backend returns.
  ///
  /// Handles every shape seen in practice, resolving the country from the
  /// value itself rather than assuming one:
  ///
  /// | Raw input          | isoCode | dialCode | phoneNumber      |
  /// |--------------------|---------|----------|------------------|
  /// | `+233241234567`    | GH      | +233     | `+233241234567`  |
  /// | `233241234567`     | GH      | +233     | `+233241234567`  |
  /// | `0241234567`       | GH      | +233     | `+233241234567`  |
  /// | `024 123 4567`     | GH      | +233     | `+233241234567`  |
  /// | `+233 24 123 4567` | GH      | +233     | `+233241234567`  |
  ///
  /// [defaultIsoCode] is the region assumed for values that carry no country
  /// code. Returns `null` only for null/blank input; otherwise always returns
  /// a best-effort result so callers can display something the user can fix.
  static PhoneNumber? fromRaw(String? raw, {String? defaultIsoCode}) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final String iso = (defaultIsoCode ?? '').toUpperCase();
    final String digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // An explicit '+' is authoritative — the region hint is ignored for it.
    if (trimmed.startsWith('+')) {
      final PhoneNumber? resolved = _tryParse(trimmed, iso);
      if (resolved != null) return resolved;
    } else {
      // Try as a national number first: libphonenumber removes the trunk
      // prefix itself, so `0241234567` and `241234567` both land correctly.
      final PhoneNumber? national = _tryParse(digits, iso);
      if (national != null) return national;

      // Then as an international number that lost its '+' in transit,
      // e.g. `233241234567`.
      final PhoneNumber? international = _tryParse('+$digits', '');
      if (international != null) return international;
    }

    // Nothing validated. Return a best-effort value rather than dropping the
    // user's data on the floor.
    final String? fallbackIso =
        iso.isNotEmpty ? iso : _isoFromLeadingDialCode(digits);
    return PhoneNumber(
      phoneNumber: trimmed.startsWith('+') ? trimmed : digits,
      isoCode: fallbackIso,
      dialCode: _dialCodeForIso(fallbackIso),
    );
  }

  /// Parses [value] and returns a [PhoneNumber] only if the result is a valid
  /// number, so callers can try several interpretations in order.
  static PhoneNumber? _tryParse(String value, String isoCode) {
    try {
      final parsed = PhoneNumberUtil.phoneUtil.parse(value, isoCode);
      if (!PhoneNumberUtil.phoneUtil.isValidNumber(parsed)) return null;
      return PhoneNumber(
        phoneNumber: PhoneNumberUtil.phoneUtil
            .format(parsed, p.PhoneNumberFormat.e164),
        dialCode: '+${parsed.countryCode}',
        isoCode: PhoneNumberUtil.phoneUtil.getRegionCodeForNumber(parsed),
      );
    } catch (_) {
      return null;
    }
  }

  /// Best-effort country lookup for a digits-only value that failed to
  /// validate. Tries the longest calling code first so `+1268` (Antigua) wins
  /// over `+1`, and `+233` over any shorter partial match.
  static String? _isoFromLeadingDialCode(String digits) {
    for (int length = 4; length >= 1; length--) {
      if (digits.length <= length) continue;
      final String? iso = getISO2CodeByPrefix(digits.substring(0, length));
      if (iso != null) return iso;
    }
    return null;
  }

  static String? _dialCodeForIso(String? isoCode) {
    if (isoCode == null || isoCode.isEmpty) return null;
    final country = Countries.countryList.firstWhereOrNull(
        (country) => country['alpha_2_code'] == isoCode.toUpperCase());
    return country?['dial_code'] as String?;
  }

  /// For predefined phone number returns Country's [isoCode] from the dial code,
  /// Returns null if not found.
  static String? getISO2CodeByPrefix(String prefix) {
    if (prefix.isNotEmpty) {
      prefix = prefix.startsWith('+') ? prefix : '+$prefix';
      var country = Countries.countryList
          .firstWhereOrNull((country) => country['dial_code'] == prefix);
      if (country != null && country['alpha_2_code'] != null) {
        return country['alpha_2_code'];
      }
    }
    return null;
  }

  /// Returns [PhoneNumberType] which is the type of phone number
  /// Accepts [phoneNumber] and [isoCode] and r
  static Future<PhoneNumberType> getPhoneNumberType(
      String phoneNumber, String isoCode) async {
    PhoneNumberType type = await PhoneNumberUtil.getNumberType(
        phoneNumber: phoneNumber, isoCode: isoCode);

    return type;
  }
}
