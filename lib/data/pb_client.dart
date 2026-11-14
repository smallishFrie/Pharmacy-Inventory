import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'lasa_engine.dart';
import 'models.dart';

// // Shared

final http.Client _client = http.Client();
const Map<String, String> _headers = {'Content-Type': 'application/json'};

// // Public API

class PbClient {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('PB_URL');
    if (envUrl.isNotEmpty) return envUrl;
    final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
    return 'http://$host:8090';
  }

  static Future<List<CabinetRecord>> getCabinets() async {
    final out = <CabinetRecord>[];
    var page = 1;
    var totalPages = 1;

    while (page <= totalPages) {
      final res = await _client.get(
        Uri.parse('$baseUrl/api/collections/cabinets/records?page=$page&perPage=500'),
        headers: _headers,
      );
      if (res.statusCode != 200) throw Exception('PB_CAB_${res.statusCode}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

      final items = (data['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        out.add(CabinetRecord.fromJson(item as Map<String, dynamic>));
      }
      page++;
    }
    return out;
  }

  static Future<CabinetRecord> createCabinet({
    required String name,
    required int rows,
    required int cols,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/collections/cabinets/records'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim().toUpperCase(),
        'rows': math.max(1, rows),
        'cols': math.max(1, cols),
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('PB_CAB_CREATE_${res.statusCode}');
    }
    return CabinetRecord.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<List<MedicineRecord>> getMedicines() async {
    final out = <MedicineRecord>[];
    var page = 1;
    var totalPages = 1;

    while (page <= totalPages) {
      final res = await _client.get(
        Uri.parse('$baseUrl/api/collections/medicines/records?page=$page&perPage=500'),
        headers: _headers,
      );
      if (res.statusCode != 200) throw Exception('PB_HTTP_${res.statusCode}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;

      final items = (data['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        out.add(MedicineRecord.fromJson(item as Map<String, dynamic>));
      }
      page++;
    }

    out.sort((a, b) {
      final c = a.cabinet.compareTo(b.cabinet);
      return c != 0 ? c : a.slot.compareTo(b.slot);
    });
    return LasaEngine.enrich(out);
  }

  static Future<MedicineRecord> createMedicine(Map<String, dynamic> data) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/collections/medicines/records'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('PB_CREATE_${res.statusCode}');
    }
    return MedicineRecord.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<MedicineRecord> updateStock(String id, int stock) async {
    return updateMedicine(id, {'stock': stock < 0 ? 0 : stock});
  }

  static Future<MedicineRecord> updateMedicine(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.patch(
      Uri.parse('$baseUrl/api/collections/medicines/records/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('PB_PATCH_${res.statusCode}');
    return MedicineRecord.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> deleteMedicine(String id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/collections/medicines/records/$id'),
      headers: _headers,
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('PB_DEL_${res.statusCode}');
    }
  }

  static Future<void> deleteCabinet(String id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/collections/cabinets/records/$id'),
      headers: _headers,
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('PB_CAB_DEL_${res.statusCode}');
    }
  }
}
