import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
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

  Future<void> remove(String id, {bool deleteFile = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await loadPending();
    final item = pending.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (deleteFile && item.isNotEmpty && !kIsWeb) {
      final filePath = item['file_path'] as String?;
      if (filePath != null) {
        try {
          final file = io.File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    final updated = pending.where((item) => item['id'] != id).toList();
    await prefs.setString(_storageKey, jsonEncode(updated));
  }

  Future<void> clear({bool deleteFiles = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (deleteFiles && !kIsWeb) {
      final pending = await loadPending();
      for (final item in pending) {
        final filePath = item['file_path'] as String?;
        if (filePath != null) {
          try {
            final file = io.File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
      }
    }
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
    if (kIsWeb) {
      return 'web_temp:$filename';
    }
    io.Directory tempDir;
    try {
      tempDir = await io.Directory.systemTemp.createTemp('waste_sort_offline_');
    } catch (_) {
      final fallbackDir =
          io.Directory('${io.Directory.current.path}/waste_sort_offline_');
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      tempDir = fallbackDir;
    }

    final file = io.File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
