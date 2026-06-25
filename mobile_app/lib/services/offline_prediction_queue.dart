import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class OfflinePredictionQueue {
  static const _storageKey = 'pending_prediction_queue';

  Future<List<Map<String, dynamic>>> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_storageKey);
    if (payload == null || payload.isEmpty) {
      return [];
    }

    final jsonList = jsonDecode(payload) as List<dynamic>;
    return jsonList
        .cast<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> enqueue({
    required String filePath,
    required String filename,
    required bool disableOcr,
    required int topK,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await loadPending();
    final item = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'file_path': filePath,
      'filename': filename,
      'disable_ocr': disableOcr,
      'top_k': topK,
      'queued_at': DateTime.now().toIso8601String(),
    };
    pending.add(item);
    await prefs.setString(_storageKey, jsonEncode(pending));
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await loadPending();
    final updated = pending.where((item) => item['id'] != id).toList();
    await prefs.setString(_storageKey, jsonEncode(updated));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<int> pendingCount() async {
    return (await loadPending()).length;
  }

  Future<bool> exists(String id) async {
    final pending = await loadPending();
    return pending.any((item) => item['id'] == id);
  }

  static Future<String> saveBytesToTempFile(
    List<int> bytes,
    String filename,
  ) async {
    Directory tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('waste_sort_offline_');
    } catch (_) {
      final fallbackDir =
          Directory('${Directory.current.path}/waste_sort_offline_');
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      tempDir = fallbackDir;
    }

    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
