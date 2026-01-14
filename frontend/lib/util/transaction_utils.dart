import 'package:frontend/models/driver_reassignment_model.dart';
import 'package:frontend/models/milestone_history_model.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:collection/collection.dart';



class TransactionUtils {
  static String removeBrackets(String input) {
    return input
        .replaceAll(RegExp(r'\s*\[.*?\]'), '')
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .trim();
  }

  static String cleanAddress(List<String?> parts) {
  return parts
      .where((e) => e != null && e.trim().isNotEmpty)
      .map((e) => removeBrackets(e!)
          .replaceAll(RegExp(r'(^,)|(,$)'), '') // remove leading/trailing commas
          .trim())
      .where((e) => e.isNotEmpty && e.toLowerCase() != 'ph')
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
        : 'Pickup Laden';
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
            name: "Deliver Empty",
            origin: shipperDestination,
            destination: shipperOrigin,
            requestNumber: item.deRequestNumber,
            requestStatus: item.deRequestStatus,
            assignedDate: item.deAssignedDate,
            originAddress: "Deliver Empty Container to Shipper",
            freightBookingNumber: item.freightBookingNumber,
            completedTime: item.deCompletedTime,
            truckPlateNumber: item.deTruckPlateNumber,
            reassigned: item.reassigned,
            rawOrigin: item.rawOrigin,
  rawDestination: item.rawDestination,
  stageId: item.stageId,
  writeDate: item.writeDate
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
            reassigned: item.reassigned,
            rawOrigin: item.rawOrigin,
  rawDestination: item.rawDestination,
   stageId: item.stageId,
  writeDate: item.writeDate
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
            reassigned: item.reassigned,
           rawOrigin: item.rawOrigin,
  rawDestination: item.rawDestination,
   stageId: item.stageId,
  writeDate: item.writeDate
          ),
        if (item.peTruckDriverName == driverId)
          item.copyWith(
            name: "Pickup Empty",
            origin: consigneeOrigin,
            destination: consigneeDestination,
            requestNumber: item.peRequestNumber,
            requestStatus: item.peRequestStatus,
            assignedDate: item.peAssignedDate,
            originAddress: "Pickup Empty Container from Consignee",
            freightBookingNumber: item.freightBookingNumber,
            completedTime: item.peCompletedTime,
            truckPlateNumber: item.peTruckPlateNumber,
            reassigned: item.reassigned,
            rawOrigin: item.rawOrigin,
  rawDestination: item.rawDestination,
   stageId: item.stageId,
  writeDate: item.writeDate
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
    final driverId = e.driverId.isNotEmpty ? e.driverId[0]?.toString() : null;
    if (driverId != currentDriverId) continue;

    final dispatchId = e.dispatchId.isNotEmpty
        ? int.tryParse(e.dispatchId[0].toString())
        : null;

    final Transaction? parent =
  allTransactions.firstWhereOrNull((t) => t.id == dispatchId);

    final tx = parent != null
      ? parent.copyWith(
          requestNumber: e.requestNumber,
          requestStatus: 'Reassigned',
          // ❌ clear lifecycle fields
          stageId: null,
          completedTime: e.createDate,
          writeDate: null,

          // ✅ reassignment timestamp
          assignedDate: e.createDate,
          isReassigned: true,
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

      // ✅ DO NOT expand reassigned transactions
      result.add(tx);
    }

    return result;
  }


static Map<String, MilestoneHistoryModel?> getScheduleForTransaction(
  Transaction transaction,
  String driverId,
  String? requestNumber
) {
  final dispatchType = transaction.dispatchType;
  final history = transaction.history ?? [];
  final serviceType = transaction.serviceType;
  final dispatchId = transaction.id;
  final transportMode = transaction.landTransport;

  // Determine which leg the driver actually belongs to
  String? matchingLeg;

// Match using both driverId and requestNumber
if (transaction.deTruckDriverName?.trim() == driverId.trim() &&
    transaction.deRequestNumber == requestNumber) {
  matchingLeg = 'de';
} else if (transaction.plTruckDriverName?.trim() == driverId.trim() &&
    transaction.plRequestNumber == requestNumber) {
  matchingLeg = 'pl';
} else if (transaction.dlTruckDriverName?.trim() == driverId.trim() &&
    transaction.dlRequestNumber == requestNumber) {
  matchingLeg = 'dl';
} else if (transaction.peTruckDriverName?.trim() == driverId.trim() &&
    transaction.peRequestNumber == requestNumber) {
  matchingLeg = 'pe';
}
// print("Matching Leg: $matchingLeg request Number: $requestNumber");

  if (matchingLeg == null) {
    return {'pickup': null, 'delivery': null};
  }

  // Reference code map
  final fclPrefixes = {
    'ot': {
      'freight':{
        'Full Container Load': {
          'de': {'delivery': 'TEOT', 'pickup': 'TYOT'},
          'pl': {'delivery': 'CLOT', 'pickup': 'TLOT', 'email': 'ELOT'},
        },
        'Less-Than-Container Load': {
          'pl': {'pickup': 'LTEOT'},
        },
      },
      'transport':{
         'Full Container Load': {
          'pl': {'delivery': 'TCLOT', 'pickup': 'TTEOT'},
        },
        'Less-Than-Container Load': {
          'pl': {'delivery': 'TCLOT', 'pickup': 'TTEOT'},
        },
      }

      
    },
    'dt': {
      'freight':{
        'Full Container Load': {
          'dl': {'delivery': 'CLDT', 'pickup': 'GYDT'},
          'pe': {'delivery': 'CYDT', 'pickup': 'GLDT', 'email': 'EEDT'},
        },
        'Less-Than-Container Load': {
          'dl': {'delivery': 'LCLDT'},
        },
      }
      
    }
  };

  final fclMap = fclPrefixes[dispatchType]?[transportMode]?[serviceType]?[matchingLeg];

  // print("FCL Map: $fclMap");
  if (fclMap == null) {
    return {'pickup': null, 'delivery': null};
  }

  final pickupFcl = fclMap['pickup'];
  final deliveryFcl = fclMap['delivery'];
  final emailFcl = fclMap['email'];

  MilestoneHistoryModel? pickupSchedule;
  MilestoneHistoryModel? deliverySchedule;
  MilestoneHistoryModel? emailSchedule;

  bool matchFcl(MilestoneHistoryModel h, String fclCode) {
  final matches = h.fclCode.trim().toUpperCase() == fclCode.toUpperCase() &&
                  h.dispatchId.toString() == dispatchId.toString() &&
                  h.serviceType == serviceType;
  // if (matches) {
  //   print('Matched FCL: ${h.fclCode}, dispatchId: ${h.dispatchId}, serviceType: ${h.serviceType}');
  // } else {
  //   print('No match: FCL(${h.fclCode}), dispatchId(${h.dispatchId}), serviceType(${h.serviceType})');
  // }
  return matches;
}

  if (pickupFcl != null) {
    pickupSchedule = history.firstWhere(
      (h) => matchFcl(h, pickupFcl),
      orElse: () => const MilestoneHistoryModel(
        id: -1,
        dispatchId: '',
        dispatchType: '',
        fclCode: '',
        scheduledDatetime: '',
        actualDatetime: '',
        serviceType: '',
        isBackload: '',
      ),
    );
    if (pickupSchedule.id == -1) pickupSchedule = null;
  }

  if (deliveryFcl != null) {
    deliverySchedule = history.firstWhere(
      (h) => matchFcl(h, deliveryFcl),
      orElse: () => const MilestoneHistoryModel(
        id: -1,
        dispatchId: '',
        dispatchType: '',
        fclCode: '',
        scheduledDatetime: '',
        actualDatetime: '',
        serviceType: '',
        isBackload: '',
      ),
    );
    if (deliverySchedule.id == -1) deliverySchedule = null;
  }
  if(emailFcl != null) {
        emailSchedule = history.firstWhere(
          (h) => 
            h.fclCode.trim().toUpperCase() == emailFcl.toUpperCase() &&
            h.dispatchId == dispatchId.toString() &&
            h.serviceType == serviceType,
          orElse: () => const MilestoneHistoryModel(
            id: -1,
            dispatchId: '',
            dispatchType: '',
            fclCode: '',
            scheduledDatetime: '',
            actualDatetime: '',
            serviceType: '', isBackload: '',
           
          ),
        );
        if(emailSchedule.id == -1) emailSchedule  = null;
      }

  return {'pickup': pickupSchedule, 'delivery': deliverySchedule};
}

}

