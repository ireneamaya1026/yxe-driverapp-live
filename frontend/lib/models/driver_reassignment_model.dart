class DriverReassignment {
  final String id;
  final List<dynamic> driverId; // always a list [id, name]
  final List<dynamic> dispatchId; // always a list [id, ref]
  final String driverName;
  final String requestNumber;
  final String dispatchName;
  final String createDate;
  final String requestType;

  DriverReassignment({
    required this.id,
    required this.dispatchId,
    required this.dispatchName,
    required this.driverId,
    required this.driverName,
    required this.requestNumber,
    required this.createDate,
    required this.requestType,
  });

  factory DriverReassignment.fromJson(Map<String, dynamic> json) {
    List<dynamic> driverList = [];
    final driverRaw = json['driver_id'];
    if (driverRaw is List) {
      driverList = driverRaw;
    } else if (driverRaw != null) {
      driverList = [driverRaw];
    }

    List<dynamic> dispatchList = [];
    final dispatchRaw = json['dispatch_id'];
    if (dispatchRaw is List) {
      dispatchList = dispatchRaw;
    } else if (dispatchRaw != null) {
      dispatchList = [dispatchRaw];
    }

    return DriverReassignment(
      id: json['id'].toString(),
      dispatchId: dispatchList,
      dispatchName: dispatchList.length > 1 ? dispatchList[1].toString() : '',
      driverId: driverList,
      driverName: driverList.length > 1 ? driverList[1].toString() : '',
      requestNumber: json['request_no']?.toString() ?? '',
      createDate: json['create_date']?.toString() ?? '',
      requestType: json['request_type']?.toString() ?? '',
    );
}


}
