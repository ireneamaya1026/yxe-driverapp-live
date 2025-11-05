import 'package:frontend/models/driver_reassignment_model.dart';
import 'package:frontend/models/transaction_model.dart';

class TransactionUtils {
  static String removeBrackets(String input) {
    return input
        .replaceAll(RegExp(r'\s*\[.*?\]'), '')
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .trim();
  }

  static String cleanAddress(List<String?> parts) {
    return parts
        .where((e) =>
            e != null &&
            e.trim().isNotEmpty &&
            e.trim().toLowerCase() != 'ph')
        .map((e) => removeBrackets(e!))
        .join(', ');
  }

  static String buildConsigneeAddress(Transaction item,
      {bool cityLevel = false}) {
    return cleanAddress(cityLevel
        ? [item.consigneeCity, item.consigneeProvince]
        : [
            item.consigneeStreet,
            item.consigneeBarangay,
            item.consigneeCity,
            item.consigneeProvince
          ]);
  }

  static String buildShipperAddress(Transaction item,
      {bool cityLevel = false}) {
    return cleanAddress(cityLevel
        ? [item.shipperCity, item.shipperProvince]
        : [
            item.shipperStreet,
            item.shipperBarangay,
            item.shipperCity,
            item.shipperProvince
          ]);
  }

  static String descriptionMsg(Transaction item) {
    return item.landTransport == 'transport'
        ? 'Deliver Laden Container to Consignee'
        : 'Pickup Laden Container from Shipper';
  }

  static String newName(Transaction item) {
    return item.landTransport == 'transport'
        ? 'Deliver to Consignee'
        : 'Pickup from Shipper';
  }

  /// Expands a transaction into multiple "legs" depending on dispatchType
  static List<Transaction> expandTransaction(
      Transaction item, String driverId) {
    if (item.dispatchType == "ot") {
      final shipperOrigin = buildShipperAddress(item);
      final shipperDestination = cleanAddress([item.destination]);

      return [
        if (item.deTruckDriverName == driverId)
          item.copyWith(
            name: "Deliver to Shipper",
            origin: shipperDestination,
            destination: shipperOrigin,
            requestNumber: item.deRequestNumber,
            requestStatus: item.deRequestStatus,
            assignedDate: item.deAssignedDate,
            originAddress: "Deliver Empty Container to Shipper",
            freightBookingNumber: item.freightBookingNumber,
            completedTime: item.deCompletedTime,
            truckPlateNumber: item.deTruckPlateNumber,
            reassigned: item.reassigned
          ),
        if (item.plTruckDriverName == driverId)
          item.copyWith(
            name: newName(item),
            origin: shipperOrigin,
            destination: shipperDestination,
            requestNumber: item.plRequestNumber,
            requestStatus: item.plRequestStatus,
            assignedDate: item.plAssignedDate,
            originAddress: descriptionMsg(item),
            freightBookingNumber: item.freightBookingNumber,
            completedTime: item.plCompletedTime,
            truckPlateNumber: item.plTruckPlateNumber,
            reassigned: item.reassigned
          ),
      ];
    } else if (item.dispatchType == "dt") {
      final consigneeOrigin = buildConsigneeAddress(item);
      final consigneeDestination = cleanAddress([item.origin]);

      return [
        if (item.dlTruckDriverName == driverId)
          item.copyWith(
            name: "Deliver to Consignee",
            origin: consigneeDestination,
            destination: consigneeOrigin,
            requestNumber: item.dlRequestNumber,
            requestStatus: item.dlRequestStatus,
            assignedDate: item.dlAssignedDate,
            originAddress: "Deliver Laden Container to Consignee",
            freightBookingNumber: item.freightBookingNumber,
            completedTime: item.dlCompletedTime,
            truckPlateNumber: item.dlTruckPlateNumber,
            reassigned: item.reassigned
          ),
        if (item.peTruckDriverName == driverId)
          item.copyWith(
            name: "Pickup from Consignee",
            origin: consigneeOrigin,
            destination: consigneeDestination,
            requestNumber: item.peRequestNumber,
            requestStatus: item.peRequestStatus,
            assignedDate: item.peAssignedDate,
            originAddress: "Pickup Empty Container from Consignee",
            freightBookingNumber: item.freightBookingNumber,
            completedTime: item.peCompletedTime,
            truckPlateNumber: item.peTruckPlateNumber,
            reassigned: item.reassigned
          ),
      ];
    }

    // default: return as-is
    return [item];
  }

  /// Expand a full transaction list
  static List<Transaction> expandTransactions(
      List<Transaction> transactions, String driverId) {
    return transactions
        .expand((item) => expandTransaction(item, driverId))
        .toList();
  }

static List<Transaction> expandReassignments(
  List<DriverReassignment> reassignments,
  String currentDriverId,
  String currentDriverName,
  List<Transaction> allTransactions,
) {
  final result = <Transaction>[];

  String getOriginAddress(String? requestType) {
    switch (requestType) {
      case 'DE':
        return "Deliver Empty Container to Shipper";
      case 'PL':
        return "Pickup Laden Container from Shipper";
      case 'DL':
        return "Deliver Laden Container to Consignee";
      case 'PE':
        return "Pickup Empty Container from Consignee";
      default:
        return '';
    }
  }

  for (final e in reassignments) {
    final driverList = e.driverId;
    String? driverId = (driverList.isNotEmpty && driverList[0] != null)
        ? driverList[0].toString()
        : null;

//     final isCurrentDriver = driverId != null && driverId == currentDriverId;

//    // Find original transaction by dispatch_id
// // 🔹 STEP 1: Extract dispatch ID from reassignment
// final dispatchIdValue = e.dispatchId.isNotEmpty ? e.dispatchId[0].toString() : null;
// print('🔸 Checking reassignment id=${e.id}, request=${e.requestNumber}, dispatchId=$dispatchIdValue');

// 🔹 STEP 2: Search for a matching transaction


final isCurrentDriver = driverId != null && driverId == currentDriverId;
if (!isCurrentDriver) {
  print('⛔ Skipping reassignment ${e.requestNumber} — not current driver');
  continue;
}

final dispatchIdValue = e.dispatchId.isNotEmpty ? e.dispatchId[0].toString() : null;
final requestNumberValue = e.requestNumber;
print('🔸 Checking reassignment id=${e.id}, request=$requestNumberValue, dispatchId=$dispatchIdValue');

// find matching transaction by request number (and other leg fields)
final matchingList = allTransactions.where((tx) =>
    tx.requestNumber == e.requestNumber ||
    tx.deRequestNumber == e.requestNumber ||
    tx.plRequestNumber == e.requestNumber ||
    tx.dlRequestNumber == e.requestNumber ||
    tx.peRequestNumber == e.requestNumber
).toList();

final Transaction? matchingTx = matchingList.isNotEmpty ? matchingList.first : null;

// debug prints
if (matchingTx != null) {
  print('🟢 MATCHED Transaction by request — id=${matchingTx.id}, '
        'dispatchName=${matchingTx.name}, reqNo=${matchingTx.requestNumber}');
} else {
  print('🔴 NO MATCH FOUND for requestNo=${e.requestNumber}');
}

    // Build base transaction: either copy existing or create minimal new
    final baseTx = matchingTx != null
        ? matchingTx.copyWith(
            isReassigned: isCurrentDriver,
            originAddress: getOriginAddress(e.requestType),
            reassigned: [e],
          )
        : Transaction(
            id: int.tryParse(e.id) ?? 0,
            name: '',
            requestStatus: 'Reassigned',
            isReassigned: true,
            origin: '',
            destination: '',
           originAddress: getOriginAddress(e.requestType),
            destinationAddress: '',
           arrivalDate: '',
        deliveryDate: '',
        pickupDate: '',
        departureDate: '',
        status: '',
        isAccepted: false,
        dispatchType: '',
        containerNumber: null,
        freightBlNumber: null,
        sealNumber: null,
        bookingRefNo: e.dispatchName,
        transportForwarderName: null,
        freightBookingNumber: null,
        originContainerYard: null,
        requestNumber: e.requestNumber,
        deRequestNumber: null,
        plRequestNumber: null,
        dlRequestNumber: null,
        peRequestNumber: null,
        deRequestStatus: null,
        plRequestStatus: null,
        dlRequestStatus: null,
        peRequestStatus: null,
        deTruckDriverName: null,
        dlTruckDriverName: null,
        peTruckDriverName: null,
        plTruckDriverName: null,
        freightForwarderName: null,
        truckPlateNumber: null,
        deTruckPlateNumber: null,
        plTruckPlateNumber: null,
        dlTruckPlateNumber: null,
        peTruckPlateNumber: null,
        truckType: null,
        deTruckType: null,
        plTruckType: null,
        dlTruckType: null,
        peTruckType: null,
        contactPerson: null,
        vehicleName: null,
        contactNumber: null,
        deProof: null,
        plProof: null,
        dlProof: null,
        peProof: null,
        deProofFilename: null,
        plProofFilename: null,
        dlProofFilename: null,
        peProofFilename: null,
        deSign: null,
        plSign: null,
        dlSign: null,
        peSign: null,
        login: null,
        serviceType: null,
        stageId: null,
        completedTime: e.createDate,
        deCompletedTime: null,
        plCompletedTime: null,
        dlCompletedTime: null,
        peCompletedTime: null,
        rejectedTime: null,
        deRejectedTime: null,
        plRejectedTime: null,
        dlRejectedTime: null,
        peRejectedTime: null,
        shipperProvince: null,
        shipperCity: null,
        shipperBarangay: null,
        shipperStreet: null,
        consigneeProvince: null,
        consigneeCity: null,
        consigneeBarangay: null,
        consigneeStreet: null,
        assignedDate: null,
        deAssignedDate: null,
        plAssignedDate: null,
        dlAssignedDate: null,
        peAssignedDate: null,
        peReleasedBy: null,
        deReleasedBy: null,
        dlReceivedBy: null,
        plReceivedBy: null,
        landTransport: null,
        writeDate: null,
        bookingRefNumber: null,
        history: [],
        backloadConsolidation: null,
        reassigned: [e],
        proofStock: null,
        proofStockFilename: null,
        hwbSigned: null,
        hwbSignedFilename: null,
        deliveryReceipt: null,
        deliveryReceiptFilename: null,
        packingList: null,
        packingListFilename: null,
        deliveryNote: null,
        deliveryNoteFilename: null,
        stockDelivery: null,
        stockDeliveryFilename: null,
        salesInvoice: null,
        salesInvoiceFilename: null,
      );

      
      print('🧩 match result: isCurrentDriver=$isCurrentDriver, driverId=$driverId, currentDriverId=$currentDriverId');


    print(
      '🟢 MATCHED REASSIGNED — id=${baseTx.id}, reqNo=${baseTx.requestNumber}, isReassigned=${baseTx.isReassigned}'
    );

  
    // Expand like normal transaction (OT/DT legs)
    final expanded = TransactionUtils.expandTransaction(baseTx, currentDriverId);
    result.addAll(expanded);
  }

  return result;
}

}
