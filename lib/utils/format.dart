/// Every peso amount the app puts on screen goes through here.
///
/// Screens used to call `.toStringAsFixed(0)` or `.toStringAsFixed(2)` on their
/// own, which is why the savings balance showed cents while almost everything
/// else didn't. [formatPeso] always groups thousands and always carries the ₱
/// symbol; pass `decimals` to keep the precision a screen has always shown, so
/// cent-accurate places stay cent-accurate.
///
/// Deliberately not `NumberFormat.currency`: that pulls in locale data
/// initialization for what is a fixed prefix plus digit grouping, and the
/// app only ever shows one currency in one style.
library;

const String _peso = '₱';

/// A peso amount with thousands separators: `formatPeso(6000)` -> `₱6,000`,
/// `formatPeso(85.5, decimals: 2)` -> `₱85.50`, `formatPeso(-150)` -> `-₱150`.
///
/// The minus goes before the symbol so an overspend reads as a negative number
/// rather than a peso amount with a stray dash.
String formatPeso(double value, {int decimals = 0}) {
  final places = decimals < 0 ? 0 : decimals;
  final negative = value < 0;

  // toStringAsFixed handles the rounding; we only add the grouping.
  final fixed = value.abs().toStringAsFixed(places);
  final dot = fixed.indexOf('.');
  final whole = dot == -1 ? fixed : fixed.substring(0, dot);
  final rest = dot == -1 ? '' : fixed.substring(dot);

  final out = '${_group(whole)}$rest';
  return negative ? '-$_peso$out' : '$_peso$out';
}

/// Inserts a comma every three digits from the right: `1234567` -> `1,234,567`.
String _group(String digits) {
  if (digits.length <= 3) return digits;

  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    // A comma belongs wherever an even number of groups of three is still to
    // come, e.g. the 1 and 4 of `1234567`, but never at the very front.
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// The same rounding as [formatPeso] but without the symbol or the separators,
/// for seeding a text field — an editable amount shouldn't come pre-filled with
/// a `₱` the user would then have to delete. Pass `decimals: 0` for fields that
/// only take whole pesos (budgets, category limits).
String formatAmountInput(double value, {int decimals = 2}) {
  return value.toStringAsFixed(decimals < 0 ? 0 : decimals);
}
