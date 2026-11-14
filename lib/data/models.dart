import 'dart:math' as math;

// // Types

class CabinetRecord {
  final String id;
  final String name;
  final int rows;
  final int cols;

  const CabinetRecord({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
  });

  int get totalSlots => rows * cols;

  factory CabinetRecord.fromJson(Map<String, dynamic> json) {
    return CabinetRecord(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'A').toString().toUpperCase(),
      rows: math.max(1, (json['rows'] as num?)?.toInt() ?? 3),
      cols: math.max(1, (json['cols'] as num?)?.toInt() ?? 4),
    );
  }
}

class MedicineRecord {
  final String id;
  final String name;
  final String displayName;
  final String brand;
  final String category;
  final String dosage;
  final String cabinet;
  final int slot;
  final int stock;
  final String batch;
  final DateTime expiry;
  final bool isLasa;
  final String lasaGroup;

  const MedicineRecord({
    required this.id,
    required this.name,
    String? displayName,
    this.brand = '',
    this.category = '',
    required this.dosage,
    required this.cabinet,
    required this.slot,
    required this.stock,
    required this.batch,
    required this.expiry,
    required this.isLasa,
    required this.lasaGroup,
  }) : displayName = displayName ?? name;

  String brandLabel({required bool tl}) {
    if (brand.trim().isNotEmpty) return brand.trim();
    return tl ? 'Generiko' : 'Generic';
  }

  String categoryLabel({required bool tl}) {
    if (category.trim().isNotEmpty) return category.trim();
    return tl ? 'Pangkalahatan' : 'General';
  }

  //`cols` is the bin count per shelf row.
  String coord(int cols) {
    final r = (slot ~/ cols) + 1;
    final b = (slot % cols) + 1;
    return '$cabinet · R$r-B$b';
  }

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiry.year, expiry.month, expiry.day);
    return exp.difference(today).inDays;
  }

  int get batchNum {
    final match = RegExp(r'(\d+)$').firstMatch(batch);
    if (match == null) return 1;
    return int.tryParse(match.group(1)!) ?? 1;
  }

  MedicineRecord withLasa({
    required String displayName,
    required bool isLasa,
    required String lasaGroup,
  }) {
    return MedicineRecord(
      id: id,
      name: name,
      displayName: displayName,
      brand: brand,
      category: category,
      dosage: dosage,
      cabinet: cabinet,
      slot: slot,
      stock: stock,
      batch: batch,
      expiry: expiry,
      isLasa: isLasa,
      lasaGroup: lasaGroup,
    );
  }

  factory MedicineRecord.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? '').toString();
    return MedicineRecord(
      id: (json['id'] ?? '').toString(),
      name: rawName,
      displayName: rawName,
      brand: (json['brand'] ?? '').toString().trim(),
      category: (json['category'] ?? '').toString().trim(),
      dosage: (json['dosage'] ?? '').toString(),
      cabinet: (json['cabinet'] ?? 'A').toString().toUpperCase(),
      slot: (json['slot'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      batch: (json['batch'] ?? '').toString(),
      expiry: DateTime.tryParse((json['expiry'] ?? '').toString()) ?? DateTime.now(),
      isLasa: json['is_lasa'] == true,
      lasaGroup: (json['lasa_group'] ?? '').toString(),
    );
  }
}
