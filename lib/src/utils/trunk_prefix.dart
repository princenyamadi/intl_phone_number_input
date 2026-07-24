import 'package:dlibphonenumber/dlibphonenumber.dart' as p;

/// Corrects phone numbers typed or pasted with a national trunk prefix.
///
/// Many countries publish numbers in a "national" form that carries a leading
/// trunk (national direct dialling) prefix which must be dropped when the
/// number is dialled internationally. Ghana is the common case for this app:
/// a subscriber writes their number as `024 123 4567` (10 digits) but the
/// international form is `+233 24 123 4567` — 9 subscriber digits, no `0`.
///
/// The set of affected countries and their prefixes is **not hardcoded here**.
/// It is read from libphonenumber's own metadata via
/// [p.PhoneNumberUtil.getNddPrefixForRegion], so it stays correct for every
/// region without a list to maintain. See `docs/national-trunk-prefixes.md`
/// for the generated reference table.
class TrunkPrefix {
  TrunkPrefix._();

  static final p.PhoneNumberUtil _util = p.PhoneNumberUtil.instance;

  /// Memoised `iso -> trunk prefix` lookups. Metadata reads are cheap but this
  /// runs on every keystroke, so the cache is worth keeping.
  static final Map<String, String?> _prefixCache = <String, String?>{};

  /// The national direct dialling prefix for [isoCode], or `null` when the
  /// region has none (Spain, Portugal, Norway, Denmark, Singapore, Hong Kong,
  /// Italy, …).
  ///
  /// Examples: `GH`, `NG`, `GB`, `ZA`, `KE`, `DE`, `FR` → `0`;
  /// `US`, `CA` → `1`; `RU`, `KZ` → `8`.
  static String? forIso(String? isoCode) {
    if (isoCode == null || isoCode.isEmpty) return null;
    final String iso = isoCode.toUpperCase();
    return _prefixCache.putIfAbsent(iso, () {
      try {
        final String? ndd = _util.getNddPrefixForRegion(iso, true);
        return (ndd == null || ndd.isEmpty) ? null : ndd;
      } catch (_) {
        return null;
      }
    });
  }

  /// Whether [isoCode] uses a national trunk prefix at all.
  static bool appliesTo(String? isoCode) => forIso(isoCode) != null;

  /// Removes the national trunk prefix from [input] when — and only when —
  /// doing so is unambiguously correct for [isoCode].
  ///
  /// Returns the digits of the corrected national number, or [input] unchanged
  /// if no correction applies. Non-digit characters in [input] are ignored.
  ///
  /// The decision is delegated to libphonenumber's `parse`, which strips the
  /// trunk prefix only if what remains is a possible length for the region.
  /// That guard is what makes this safe to run on every keystroke:
  ///
  /// * Partial input keeps its prefix — `0`, `02`, `024` are left alone
  ///   because the remainder is still too short to be a real number.
  /// * Regions where a leading `0` is significant are untouched, because
  ///   their metadata declares no trunk prefix.
  /// * A number already in subscriber form is untouched, because it does not
  ///   start with the prefix.
  static String strip(String input, String? isoCode) {
    final String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || isoCode == null || isoCode.isEmpty) return input;

    final String? ndd = forIso(isoCode);
    if (ndd == null ||
        !digits.startsWith(ndd) ||
        digits.length <= ndd.length) {
      return input;
    }

    try {
      final p.PhoneNumber parsed = _util.parse(digits, isoCode.toUpperCase());
      final String nsn = _util.getNationalSignificantNumber(parsed);
      // `parse` declined to strip if it handed back everything we gave it.
      // Require `digits` to end with `nsn` so we only ever remove a prefix.
      if (nsn.isNotEmpty && nsn.length < digits.length && digits.endsWith(nsn)) {
        return nsn;
      }
    } catch (_) {
      // Too short, unparseable, or unknown region — leave the input alone.
    }
    return input;
  }
}
