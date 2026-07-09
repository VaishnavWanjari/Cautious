import 'package:intl/intl.dart';

/// Formatting helpers shared across the app.
class Fmt {
  static final _date = DateFormat('d MMM yyyy');
  static final _shortDate = DateFormat('d MMM');

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// Indian-format currency: ₹1,25,000 with lakh/crore compaction for headlines.
  static String inr(num value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(value);
  }

  static String inrExact(num value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(value);

  static String daysWord(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'in 1 day';
    if (days > 0) return 'in $days days';
    return '${-days} days ago';
  }
}
