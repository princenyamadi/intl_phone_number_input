import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_number_input/src/utils/phone_number.dart';
import 'package:intl_phone_number_input/src/utils/trunk_prefix.dart';

void main() {
  group('TrunkPrefix.forIso', () {
    test('reads the prefix from libphonenumber metadata', () {
      expect(TrunkPrefix.forIso('GH'), '0');
      expect(TrunkPrefix.forIso('NG'), '0');
      expect(TrunkPrefix.forIso('GB'), '0');
      expect(TrunkPrefix.forIso('ZA'), '0');
      expect(TrunkPrefix.forIso('KE'), '0');
      expect(TrunkPrefix.forIso('DE'), '0');
      expect(TrunkPrefix.forIso('RU'), '8');
      expect(TrunkPrefix.forIso('US'), '1');
    });

    test('is null for regions that declare no trunk prefix', () {
      for (final iso in ['IT', 'ES', 'PT', 'NO', 'DK', 'SG', 'HK']) {
        expect(TrunkPrefix.forIso(iso), isNull, reason: '$iso has no NDD');
      }
    });

    test('is case insensitive and null-safe', () {
      expect(TrunkPrefix.forIso('gh'), '0');
      expect(TrunkPrefix.forIso(null), isNull);
      expect(TrunkPrefix.forIso(''), isNull);
      expect(TrunkPrefix.forIso('ZZ'), isNull);
    });
  });

  group('TrunkPrefix.strip corrects local-form numbers', () {
    const cases = <String, List<String>>{
      // iso: [input, expected]
      'GH': ['0241234567', '241234567'],
      'NG': ['08031234567', '8031234567'],
      'GB': ['07400123456', '7400123456'],
      'ZA': ['0711234567', '711234567'],
      'KE': ['0712123456', '712123456'],
      'DE': ['015123456789', '15123456789'],
      'RU': ['89123456789', '9123456789'],
      'US': ['12125551234', '2125551234'],
    };

    cases.forEach((iso, value) {
      test('$iso: ${value[0]} -> ${value[1]}', () {
        expect(TrunkPrefix.strip(value[0], iso), value[1]);
      });
    });

    test('ignores separators in the input', () {
      expect(TrunkPrefix.strip('024 123 4567', 'GH'), '241234567');
      expect(TrunkPrefix.strip('(024) 123-4567', 'GH'), '241234567');
    });
  });

  group('TrunkPrefix.strip leaves input alone when it must', () {
    test('number already in subscriber form', () {
      expect(TrunkPrefix.strip('241234567', 'GH'), '241234567');
      expect(TrunkPrefix.strip('8031234567', 'NG'), '8031234567');
    });

    test('partially typed input keeps its prefix', () {
      for (final partial in ['0', '02', '024', '0241', '02412']) {
        expect(TrunkPrefix.strip(partial, 'GH'), partial,
            reason: 'must not strip while $partial is still too short');
      }
    });

    test('regions where a leading zero is significant', () {
      // Italy abolished its trunk prefix; the 0 is part of the number.
      expect(TrunkPrefix.strip('0212345678', 'IT'), '0212345678');
      expect(TrunkPrefix.strip('0912345678', 'ES'), '0912345678');
    });

    test('empty, non-numeric, and unknown regions', () {
      expect(TrunkPrefix.strip('', 'GH'), '');
      expect(TrunkPrefix.strip('abc', 'GH'), 'abc');
      expect(TrunkPrefix.strip('0241234567', null), '0241234567');
      expect(TrunkPrefix.strip('0241234567', 'ZZ'), '0241234567');
    });

    test('input whose remainder would be too short keeps its prefix', () {
      // Stripping would leave 2 digits, far below any GH length, so the
      // metadata guard declines and the user's input is preserved.
      expect(TrunkPrefix.strip('024', 'GH'), '024');
      expect(TrunkPrefix.strip('08', 'NG'), '08');
    });
  });

  group('PhoneNumber.nationalNumber', () {
    test('extracts subscriber digits without corrupting the number', () {
      final gh = PhoneNumber(
          phoneNumber: '+233241234567', dialCode: '+233', isoCode: 'GH');
      expect(gh.nationalNumber, '241234567');
    });

    test('regression: every 1 survives in a NANP number', () {
      // The old implementation used replaceAll(dialCode), which deleted
      // every '1' in the number rather than just the country code.
      final us = PhoneNumber(
          phoneNumber: '+12125551111', dialCode: '+1', isoCode: 'US');
      expect(us.nationalNumber, '2125551111');
    });

    test('regression: a number repeating its own dial code is intact', () {
      final gh = PhoneNumber(
          phoneNumber: '+233233123456', dialCode: '+233', isoCode: 'GH');
      expect(gh.nationalNumber, '233123456');
    });

    test('parseNumber stays in step with nationalNumber', () {
      final gh = PhoneNumber(
          phoneNumber: '+233241234567', dialCode: '+233', isoCode: 'GH');
      expect(gh.parseNumber(), gh.nationalNumber);
    });

    test('handles null and empty', () {
      expect(PhoneNumber(isoCode: 'GH').nationalNumber, '');
      expect(PhoneNumber(phoneNumber: '', isoCode: 'GH').nationalNumber, '');
    });
  });

  group('PhoneNumber.formattedNationalNumber', () {
    test('formats without re-adding the trunk prefix', () {
      final gh = PhoneNumber(
          phoneNumber: '+233241234567', dialCode: '+233', isoCode: 'GH');
      // libphonenumber's NATIONAL format would give "024 123 4567".
      expect(gh.formattedNationalNumber, isNot(startsWith('0')));
      expect(gh.formattedNationalNumber.replaceAll(RegExp(r'\D'), ''),
          '241234567');
    });

    test('drops the dial code for a foreign number', () {
      final gb = PhoneNumber(
          phoneNumber: '+447400123456', dialCode: '+44', isoCode: 'GB');
      expect(gb.formattedNationalNumber, isNot(contains('+44')));
      expect(gb.formattedNationalNumber.replaceAll(RegExp(r'\D'), ''),
          '7400123456');
    });
  });

  group('PhoneNumber.fromRaw resolves every backend shape', () {
    const shapes = <String>[
      '+233241234567', // E.164, the documented case
      '233241234567', // digits only, '+' lost in transit
      '0241234567', // local form with trunk prefix
      '024 123 4567', // local form, formatted
      '+233 24 123 4567', // international, formatted
      '+233-24-123-4567', // international, dashed
    ];

    for (final raw in shapes) {
      test('"$raw" -> +233241234567 / GH / +233', () {
        final number = PhoneNumber.fromRaw(raw, defaultIsoCode: 'GH');
        expect(number, isNotNull);
        expect(number!.phoneNumber, '+233241234567');
        expect(number.isoCode, 'GH');
        expect(number.dialCode, '+233');
        expect(number.nationalNumber, '241234567');
      });
    }

    test('a foreign number wins over the default region', () {
      final number = PhoneNumber.fromRaw('+447400123456', defaultIsoCode: 'GH');
      expect(number!.isoCode, 'GB');
      expect(number.dialCode, '+44');
      expect(number.nationalNumber, '7400123456');
    });

    test('digits-only foreign number is detected', () {
      final number = PhoneNumber.fromRaw('2348031234567', defaultIsoCode: 'GH');
      expect(number!.isoCode, 'NG');
      expect(number.phoneNumber, '+2348031234567');
    });

    test('null and blank input yield null', () {
      expect(PhoneNumber.fromRaw(null), isNull);
      expect(PhoneNumber.fromRaw(''), isNull);
      expect(PhoneNumber.fromRaw('   '), isNull);
      expect(PhoneNumber.fromRaw('abc'), isNull);
    });

    test('unparseable input still returns something the user can fix', () {
      final number = PhoneNumber.fromRaw('12345', defaultIsoCode: 'GH');
      expect(number, isNotNull);
      expect(number!.isoCode, 'GH');
      expect(number.dialCode, '+233');
    });
  });

  group('RegionInfo dial code carries the plus', () {
    test('getRegionInfoFromPhoneNumber returns +233, not 233', () async {
      final number =
          await PhoneNumber.getRegionInfoFromPhoneNumber('+233241234567', 'GH');
      expect(number.dialCode, '+233');
      expect(number.isoCode, 'GH');
      expect(number.phoneNumber, '+233241234567');
    });
  });
}
