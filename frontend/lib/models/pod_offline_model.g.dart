// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pod_offline_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PodModelAdapter extends TypeAdapter<PodModel> {
  @override
  final int typeId = 0;

  @override
  PodModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PodModel(
      uri: fields[0] as String,
      headers: (fields[1] as Map).cast<String, String>(),
      body: (fields[2] as Map).cast<String, dynamic>(),
      isUploading: fields[3] as bool? ?? false,
uuid: fields[4] as String? ?? const Uuid().v4(),
    );
  }

  @override
  void write(BinaryWriter writer, PodModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.uri)
      ..writeByte(1)
      ..write(obj.headers)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.isUploading)
      ..writeByte(4)
      ..write(obj.uuid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
