import 'dart:convert';

import 'package:frontend/models/pod_offline_model.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class PendingPodUploader {
  bool _isUploadingPendingPods = false;

  Future<void> uploadPendingPods() async {
    if (_isUploadingPendingPods) return;
    _isUploadingPendingPods = true;
    try{
      final box = await Hive.openBox<PodModel>('pendingPods');
      if (box.isEmpty) return;

      final pods = box.values.toList();

      // print("🔄 Attempting to upload ${pods.length} pending POD(s)...");

      for (var pod in pods) {
        if (pod.isUploading) continue; // skip PODs already in progress

        pod.isUploading = true;
        await pod.save();
        try {
          final response = await http.post(
            Uri.parse(pod.uri),
            headers: pod.headers,
            body: jsonEncode(pod.body),
          );

          if (response.statusCode == 200) {
            // print("✅ Uploaded pending POD: ${pod.key}");
            await box.delete(pod.key);
          } else {
            // print("⚠ Failed to upload pending POD: ${response.statusCode}");
            pod.isUploading = false;
            await pod.save();
          }
        } catch (e) {
          // print("❌ Error uploading pending POD: $e");
          pod.isUploading = false;
            await pod.save();
        }
      }
    } finally {
      _isUploadingPendingPods = false;
    }
  }
}