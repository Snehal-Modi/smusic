import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin JSON-friendly wrapper over SharedPreferences.
class Store {
  final SharedPreferences _p;
  Store._(this._p);

  static Future<Store> open() async => Store._(await SharedPreferences.getInstance());

  String? getString(String k) => _p.getString(k);
  Future<void> setString(String k, String v) => _p.setString(k, v);

  int? getInt(String k) => _p.getInt(k);
  Future<void> setInt(String k, int v) => _p.setInt(k, v);

  bool? getBool(String k) => _p.getBool(k);
  Future<void> setBool(String k, bool v) => _p.setBool(k, v);

  double? getDouble(String k) => _p.getDouble(k);
  Future<void> setDouble(String k, double v) => _p.setDouble(k, v);

  List<dynamic> getJsonList(String k) {
    final s = _p.getString(k);
    if (s == null || s.isEmpty) return [];
    try {
      final v = jsonDecode(s);
      return v is List ? v : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> setJsonList(String k, List<dynamic> v) => _p.setString(k, jsonEncode(v));

  Map<String, dynamic>? getJsonMap(String k) {
    final s = _p.getString(k);
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJsonMap(String k, Map<String, dynamic> v) => _p.setString(k, jsonEncode(v));

  Future<void> remove(String k) => _p.remove(k);
}
