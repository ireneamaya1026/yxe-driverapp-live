import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'pod_offline_model.g.dart';

@HiveType(typeId: 0)
class PodModel extends HiveObject {
  @HiveField(0)
  String uri;

  @HiveField(1)
  Map<String, String> headers;

  @HiveField(2)
  Map<String, dynamic> body;

  @HiveField(3)
  bool isUploading; // prevent duplicates during uploads

  @HiveField(4)
  String uuid; // unique id per POD for backend idempotency

  PodModel({
    required this.uri,
    required this.headers,
    required this.body,
    this.isUploading = false,
    required this.uuid,
  });
}
