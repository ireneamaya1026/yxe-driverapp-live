import 'package:frontend/models/consolidation_extension.dart';

class ConsolidationModel {
  final int id;
  final String name;
  final String status;
  final String consolidatedDatetime;
  final String? isBackload;
  final String? isDiverted;
  final List<dynamic>? consolOrigin;
  final List<dynamic>? consolDestination;

  const ConsolidationModel({
    required this.id,
    required this.name,
    required this.status,
    required this.consolidatedDatetime,
    required this.isBackload,
    required this.isDiverted,
    this.consolDestination,
    this.consolOrigin
  });

  factory ConsolidationModel.fromJson(Map<String, dynamic> json) {
     
    return ConsolidationModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Name',
      status: json['status'] ?? 'Unknown Status',
      consolidatedDatetime:  json['consolidated_date'] ?? 'Unknown Date',

      consolOrigin: json['consol_origin'],
      consolDestination: json['consol_destination'],
      
      isBackload: json['is_backload']?.toString(),
      isDiverted: json['is_diverted']?.toString()

    );
  }
  


  ConsolidationModel copyWith({String? name}) {
    return ConsolidationModel(
      id: id,
      name: name ?? this.name,
      status: status,
      consolidatedDatetime: consolidatedDatetime,
      
      isBackload: isBackload,
      isDiverted: isDiverted,

      consolOrigin: consolOrigin ?? consolOrigin,
      consolDestination: consolDestination ?? consolDestination,

    );
  }
  String get formattedConsolidatedDate {
    if (consolidatedDatetime.trim().isNotEmpty) {
      final parsed = separateDateTime(consolidatedDatetime);
      return parsed['date'] ?? '—';
    }
    return '—';
  }
   String get originName => consolOrigin != null && consolOrigin!.length > 1 ? consolOrigin![1] : '—';
  String get destinationName => consolDestination != null && consolDestination!.length > 1 ? consolDestination![1] : '—';

}
