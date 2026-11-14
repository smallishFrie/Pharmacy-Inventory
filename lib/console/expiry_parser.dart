import '../data/models.dart';

class ExpiryParser {
  ExpiryParser._();

  static DateTime? parse(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}').hasMatch(s)) {
      final iso = DateTime.tryParse(s);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    }

    final parts = s.split(RegExp(r'[/\-\.\s]+'));
    if (parts.length == 2) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      if (p0 == null || p1 == null) return null;

      if (p0 > 1900 && p1 >= 1 && p1 <= 12) return DateTime(p0, p1 + 1, 0);
      if (p0 >= 1 && p0 <= 12) {
        final year = p1 < 100 ? 2000 + p1 : p1;
        if (year >= 2000 && year <= 2100) return DateTime(year, p0 + 1, 0);
      }
    } else if (parts.length == 3) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      final p2 = int.tryParse(parts[2]);
      if (p0 == null || p1 == null || p2 == null) return null;

      if (p0 > 1900) {
        return DateTime(p0, p1.clamp(1, 12).toInt(), p2.clamp(1, 31).toInt());
      }

      final year = p2 < 100 ? 2000 + p2 : p2;
      if (p0 <= 12) {
        return DateTime(year, p0.clamp(1, 12).toInt(), p1.clamp(1, 31).toInt());
      } else {
        return DateTime(year, p1.clamp(1, 12).toInt(), p0.clamp(1, 31).toInt());
      }
    }
    return null;
  }

  static String shortDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final y = (dt.year % 100).toString().padLeft(2, '0');
    return '$m/$y';
  }

  static String monthYear(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    return '$m/${dt.year}';
  }

  static String badge(MedicineRecord rec, {required bool tl}) {
    final d = rec.daysLeft;
    if (d < 0) return tl ? 'PASADO' : 'EXPIRED';
    if (d <= 30) return '${d}D';
    return shortDate(rec.expiry);
  }
}
