import 'package:frontend/models/consolidation_model.dart';
import 'package:intl/intl.dart';


Map< String, String> separateDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) {
      return {"date": "N/A", "time": "N/A"}; // Return default values if null or empty
    }

    try {
      DateTime datetime = DateTime.parse("${dateTime}Z").toLocal();

      return {
        "date": DateFormat('dd MMM , yyyy').format(datetime),
        "time": DateFormat('hh:mm a').format(datetime),
      };
    } catch (e) {
      // print("Error parsing date: $e");
      return {"date": "N/A", "time": "N/A"}; // Return default values on error
    }
  }

extension ConsolidationModelView on ConsolidationModel {
  String get formattedConsolidatedDate {
    if (consolidatedDatetime.trim().isNotEmpty) {
      final parsed = separateDateTime(consolidatedDatetime);
      return parsed['date'] ?? '—';
    }
    return '—';
  }
}
