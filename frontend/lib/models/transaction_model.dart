import 'package:frontend/models/consolidation_model.dart';
import 'package:frontend/models/driver_reassignment_model.dart';
import 'package:frontend/models/milestone_history_model.dart';

class Transaction {
  final int id;
  final String? name;
  final String? origin;
  final String? destination;
  final String? originAddress;
  final String? destinationAddress;
  final String? arrivalDate;
  final String? deliveryDate;
  final String? pickupDate;
  final String? departureDate;
  final String? status;
  final bool? isAccepted;
  final String? dispatchType;
  final String? containerNumber;
  final String? freightBlNumber;
  final String? sealNumber;
  final String? bookingRefNo;
  final String? transportForwarderName;
  final String? freightBookingNumber;
  final String? originContainerYard;
  final String? requestNumber;
  final String? deRequestNumber;
  final String? plRequestNumber;
  final String? dlRequestNumber;
  final String? peRequestNumber;

  final String? requestStatus;
  final String? deRequestStatus;
  final String? plRequestStatus;
  final String? dlRequestStatus;
  final String? peRequestStatus;
  final String? deTruckDriverName;
  final String? dlTruckDriverName;
  final String? peTruckDriverName;
  final String? plTruckDriverName;
  final String? freightForwarderName;
  final String? truckPlateNumber;
  final String? deTruckPlateNumber;
  final String? plTruckPlateNumber;
  final String? dlTruckPlateNumber;
  final String? peTruckPlateNumber;
  final String? truckType;
  final String? deTruckType;
  final String? plTruckType;
  final String? dlTruckType;
  final String? peTruckType;
  final String? contactPerson;
  final String? vehicleName;
  final bool? isReassigned;


  final String? contactNumber;

  final String? deProof;
  final String? plProof;
  final String? dlProof;
  final String? peProof;

  final String? deProofFilename;
  final String? plProofFilename;
  final String? dlProofFilename;
  final String? peProofFilename;

  final String? deSign;
  final String? plSign;
  final String? dlSign;
  final String? peSign;
  final String? login;
  final String? serviceType;
  final String? stageId;
  final String? completedTime;
  final String? deCompletedTime;
  final String? plCompletedTime;
  final String? dlCompletedTime;
  final String? peCompletedTime;
  final String? rejectedTime;
  final String? deRejectedTime;
  final String? plRejectedTime;
  final String? dlRejectedTime;
  final String? peRejectedTime;

  final String? shipperProvince;
  final String? shipperCity;  
  final String? shipperBarangay;
  final String? shipperStreet;
  final String? consigneeProvince;
  final String? consigneeCity;  
  final String? consigneeBarangay;
  final String? consigneeStreet;

  final String? assignedDate;
  final String? deAssignedDate;
  final String? plAssignedDate;
  final String? dlAssignedDate;
  final String? peAssignedDate;

  final String? peReleasedBy;
  final String? deReleasedBy;
  final String? dlReceivedBy;
  final String? plReceivedBy;

  final String? landTransport;

 final String? writeDate;

 final String? bookingRefNumber;

  final List<MilestoneHistoryModel>? history;
  final ConsolidationModel? backloadConsolidation;
  final List<DriverReassignment>? reassigned;

  final String? proofStock;
  final String? proofStockFilename;
  final String? hwbSigned;
  final String? hwbSignedFilename;
  final String? deliveryReceipt;
  final String? deliveryReceiptFilename;
  final String? packingList;
  final String? packingListFilename;
  final String? deliveryNote;
  final String? deliveryNoteFilename;
  final String? stockDelivery;
  final String? stockDeliveryFilename;
  final String? salesInvoice;
  final String? salesInvoiceFilename;

  // final String? completeAddress ;


  const Transaction({
    required this.id,
     this.name,
     this.origin,
     this.destination,
     this.originAddress,
     this.destinationAddress,
     this.arrivalDate,
     this.deliveryDate,
     this.status,
     this.dispatchType,
     this.containerNumber,
     this.freightBlNumber,
     this.sealNumber,
     this.transportForwarderName,
     this.bookingRefNo,
     this.freightBookingNumber,
     this.originContainerYard,
     this.requestNumber,
     this.deRequestNumber,
     this.plRequestNumber,
     this.dlRequestNumber,
     this.peRequestNumber,
     this.requestStatus,
     this.deRequestStatus,
     this.plRequestStatus,
     this.dlRequestStatus,
     this.peRequestStatus,
     this.deTruckDriverName,
     this.dlTruckDriverName,
     this.peTruckDriverName,
     this.plTruckDriverName,
     this.freightForwarderName,
     this.contactNumber,
     this.truckPlateNumber,
     this.deTruckPlateNumber,
     this.plTruckPlateNumber,
     this.dlTruckPlateNumber,
     this.peTruckPlateNumber,
     this.deTruckType,
     this.plTruckType,
     this.dlTruckType,
     this.peTruckType,
     this.truckType,
     this.contactPerson,
     this.vehicleName,
     this.deProof,
     this.plProof,
     this.dlProof,
     this.peProof,
      this.deProofFilename,
     this.plProofFilename,
     this.dlProofFilename,
     this.peProofFilename,
     this.deSign,  
     this.plSign,   
     this.dlSign,   
     this.peSign,  
     this.pickupDate,   
     this.departureDate,   
     this.serviceType, 
     this.stageId,
     this.completedTime,
     this.deCompletedTime,
     this.plCompletedTime,
     this.dlCompletedTime,
     this.peCompletedTime,
     this.rejectedTime,
     this.deRejectedTime,
     this.plRejectedTime,
     this.dlRejectedTime,
     this.peRejectedTime,
     this.shipperProvince,
     this.shipperCity,
     this.shipperBarangay,
     this.shipperStreet,
     this.consigneeProvince,
     this.consigneeCity,
     this.consigneeBarangay,
     this.consigneeStreet,
     this.isAccepted,
     this.assignedDate,
     this.deAssignedDate,
     this.plAssignedDate,
     this.dlAssignedDate,
     this.peAssignedDate,
     this.login,
     this.history,
     this.landTransport,
     this.writeDate,
     this.deReleasedBy,
     this.peReleasedBy,
     this.dlReceivedBy,
     this.plReceivedBy,
     this.backloadConsolidation,
     this.bookingRefNumber,
     this.reassigned,
    //  this.completeAddress,
     this.proofStock,
     this.proofStockFilename,
     this.hwbSigned,
     this.hwbSignedFilename,
     this.deliveryReceipt,
     this.deliveryReceiptFilename,
     this.packingList,
     this.packingListFilename,
     this.deliveryNote,
     this.deliveryNoteFilename,
     this.stockDelivery,
     this.stockDeliveryFilename,
     this.salesInvoice,
     this.salesInvoiceFilename,
    this.isReassigned = false,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // print('knii Raw transaction JSON: $json');
    final rawConsolidation = json['backload_consolidation'];


    return Transaction(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'No Name Provided',  // Provide a default value
      origin: json['origin'] ?? 'Unknown Origin',  // Provide a default value
      destination: json['destination'] ?? 'Unknown Destination',  // Provide a default value
      arrivalDate: json['arrival_date'] ?? 'Unknown Arrival Date',  // Provide a default value
      deliveryDate: json['delivery_date'] ?? 'Unknown Delivery Date',  // Provide a default value
      status: json['status'] ?? 'Unknown Status',  // Provide a default value
      dispatchType: json['dispatch_type'] ?? 'Unknown Dispatch Type',
      containerNumber: json['container_number'].toString(),
      freightBlNumber: json['freight_bl_number'].toString(),
      sealNumber: json['seal_number'].toString(),
      bookingRefNo: json ['name'] ?? 'N/A',
      transportForwarderName: json['origin_forwarder_name'] != null && json['origin_forwarder_name'].isNotEmpty
                            ? _extractName(json ['origin_forwarder_name']) : _extractName(json ['destination_forwarder_name']),
      freightBookingNumber: json ['freight_booking_number'],
      freightForwarderName: json['freight_forwarder_name'] != null && json['freight_forwarder_name'].isNotEmpty
                            ? _extractName(json['freight_forwarder_name'])
                            : '',
      contactNumber: json['dispatch_type'] == 'ot'
                    ? (json['shipper_phone'] != null && json['shipper_phone'].toString().isNotEmpty
                        ? json['shipper_phone']
                        : '')
                    : (json['consignee_phone'] != null && json['consignee_phone'].toString().isNotEmpty
                        ? json['consignee_phone']
                        : ''),

      contactPerson: json['dispatch_type'] == 'ot'
                    ? (json['shipper_contact_id'] != null && json['shipper_contact_id'].toString().isNotEmpty
                        ? _extractName(json['shipper_contact_id'])
                        : _extractName(json['shipper_id']))
                    : (json['consignee_contact_id'] != null && json['consignee_contact_id'].toString().isNotEmpty
                        ? _extractName(json['consignee_contact_id'])
                        : _extractName(json['consignee_id'])),

      originAddress: json['origin_port_terminal_address'] ?? 'Unknown Origin Address',  // Provide a default value
      destinationAddress: json['destination_port_terminal_address'] ?? 'Unknown Destination Address',  // Provide a

                 
      originContainerYard: json['origin_container_location'].toString(),
      requestNumber: json['de_request_no'].toString(),
      deRequestNumber: json['de_request_no'].toString(),
      plRequestNumber: json['pl_request_no'].toString(),
      dlRequestNumber: json['dl_request_no'].toString(),
      peRequestNumber: json['pe_request_no'].toString(),

      requestStatus: json['de_request_status'].toString(),
      deRequestStatus: json['de_request_status'].toString(),
      plRequestStatus: json['pl_request_status'].toString(),
      dlRequestStatus: json['dl_request_status'].toString(),
      peRequestStatus: json['pe_request_status'].toString(),
      deTruckDriverName: _extractDriverId(json['de_truck_driver_name'])?.toString(),
      dlTruckDriverName: _extractDriverId(json['dl_truck_driver_name'])?.toString(),
      peTruckDriverName: _extractDriverId(json['pe_truck_driver_name'])?.toString(),
      plTruckDriverName: _extractDriverId(json['pl_truck_driver_name'])?.toString(),
      truckPlateNumber: _extractName(json['de_truck_plate_no'])?.toString(),
      deTruckPlateNumber: _extractName(json['de_truck_plate_no'])?.toString(),
      plTruckPlateNumber: _extractName(json['pl_truck_plate_no'])?.toString(),
      dlTruckPlateNumber: _extractName(json['dl_truck_plate_no'])?.toString(),
      peTruckPlateNumber: _extractName(json['pe_truck_plate_no'])?.toString(),
      truckType: _extractName(json['de_truck_type'])?.toString(),
      deTruckType: _extractName(json['de_truck_type'])?.toString(),
      plTruckType: _extractName(json['pl_truck_type'])?.toString(),
      dlTruckType: _extractName(json['dl_truck_type'])?.toString(),
      peTruckType: _extractName(json['pe_truck_type'])?.toString(),
      vehicleName: _extractName(json['vehicle_name'])?.toString(), // Provide a default value
      deProof: json['de_proof'].toString(),
      plProof: json['pl_proof'].toString(),
      dlProof: json['dl_proof'].toString(),
      peProof: json['pe_proof'].toString(),

      deProofFilename: json['de_proof_filename'].toString(),
      plProofFilename: json['pl_proof_filename'].toString(),
      dlProofFilename: json['dl_proof_filename'].toString(),
      peProofFilename: json['pe_proof_filename'].toString(),

      deSign: json['de_signature'].toString(),
      plSign: json['pl_signature'].toString(),
      dlSign: json['dl_signature'].toString(),
      peSign: json['pe_signature'].toString(),

      pickupDate: json['pickup_date'] ?? 'Unknown Pick Up Date',  // Provide a default value
      departureDate: json['departure_date'] ?? 'Unknown DEparture Date',  // Provide a default value

      serviceType:json['service_type']?.toString(),

      login: json['login'].toString(),
      stageId: json['stage_id']?.toString() ?? '0',  // Provide a default value

      completedTime: json['de_completion_time'] ?? 'Unknown Completed Time',
      deCompletedTime: json['de_completion_time'] ?? 'Unknown DE',
      plCompletedTime: json['pl_completion_time'] ?? 'Unknown PL',
      dlCompletedTime: json['dl_completion_time'] ?? 'Unknown DL',
      peCompletedTime: json['pe_completion_time'] ?? 'Unknown PE',

      rejectedTime: json['de_rejection_time'] ?? 'Unknown Rejected Time', // Provide a default value
      deRejectedTime: json['de_rejection_time'] ?? 'Unknown DE',
      plRejectedTime: json['pl_rejection_time'] ?? 'Unknown PL',
      dlRejectedTime: json['dl_rejection_time'] ?? 'Unknown DL',
      peRejectedTime: json['pe_rejection_time'] ?? 'Unknown PE',
      shipperProvince: json['shipper_province']?.toString() ?? 'Unknown Shipper Province',
      shipperCity: json['shipper_city']?.toString() ?? 'Unknown Shipper City',
      shipperBarangay: json['shipper_barangay']?.toString() ?? 'Unknown Shipper Barangay',
      shipperStreet: json['shipper_street']?.toString() ?? 'Unknown Shipper Street',
      consigneeProvince: json['consignee_province']?.toString() ?? 'Unknown Consignee Province',
      consigneeCity: json['consignee_city']?.toString() ?? 'Unknown Consignee City',
      consigneeBarangay: json['consignee_barangay']?.toString() ?? 'Unknown Consignee Barangay',
      consigneeStreet: json['consignee_street']?.toString() ?? 'Unknown Consignee Street',

      assignedDate: json['de_assignation_time'] ?? 'Unknown Assignation Time', // Provide a default value
      deAssignedDate: json['de_assignation_time'] ?? 'Unknown DE',
      plAssignedDate: json['pl_assignation_time'] ?? 'Unknown PL',
      dlAssignedDate: json['dl_assignation_time'] ?? 'Unknown DL',
      peAssignedDate: json['pe_assignation_time'] ?? 'Unknown PE',
      landTransport: json['booking_service'] ?? 'Unknown Transport', 

      plReceivedBy: json['pl_receive_by'].toString(),
      peReleasedBy: json['pe_release_by'].toString(),
      deReleasedBy: json['de_release_by'].toString(),
      dlReceivedBy: json['dl_receive_by'].toString(),

      bookingRefNumber: json['booking_reference_no']?.toString() ?? 'N/A',

      history: (json['history'] is List) 
        ? (json['history'] as List).map((e) => MilestoneHistoryModel.fromJson(e)).toList() : [],

      writeDate: json['write_date']?.toString() ?? 'Unknown Date', // Provide a default value

      isAccepted: false,  // set default or map from API

      isReassigned: false,

      backloadConsolidation: rawConsolidation != null && rawConsolidation is Map
          ? ConsolidationModel.fromJson(Map<String, dynamic>.from(rawConsolidation))
          : null,

       reassigned: (json['reassigned'] is List)
    ? (json['reassigned'] as List)
        .map((e) => DriverReassignment.fromJson(e))
        .toList()
    : (json['reassigned'] is Map)
        ? [DriverReassignment.fromJson(json['reassigned'] as Map<String, dynamic>)]
        : [],

        



      // completeAddress: json['origin']?.toString() ?? 'N/A',

      proofStock: json['pl_proof_stock'].toString(),
      proofStockFilename: json['pl_proof_filename_stock'].toString(),
      hwbSigned: json['dl_hwb_signed'].toString(),
      hwbSignedFilename: json['dl_hwb_signed_filename'].toString(),
      deliveryReceipt: json['dl_delivery_receipt'].toString(),
      deliveryReceiptFilename: json['dl_delivery_receipt_filename'].toString(),
      packingList: json['dl_packing_list'].toString(),
      packingListFilename: json['dl_packing_list_filename'].toString(),
      deliveryNote: json['dl_delivery_note'].toString(),
      deliveryNoteFilename: json['dl_delivery_note_filename'].toString(),
      stockDelivery: json['dl_stock_delivery_receipt'].toString(),
      stockDeliveryFilename: json['dl_stock_delivery_receipt_filename'].toString(),
      salesInvoice: json['dl_sales_invoice'].toString(),
      salesInvoiceFilename: json['dl_sales_invoice_filename'].toString(),


      
    );
  }

  static String? _extractName(dynamic field) {
    if (field is List && field.isNotEmpty) {
      return field[1]?.toString(); // Extract name (second item in list)
    } else if (field is String) {
      return field;
    }
    return null; // Return null if not available
  }

  static int? _extractDriverId(dynamic field) {
    if (field is List && field.isNotEmpty) {
      return field[0]; // ID is usually the first element
    }
    return null;
  }

 





  Transaction copyWith({String? name, String? destination,String? requestNumber,String? origin,String? requestStatus,status, bool? isAccepted, String? truckPlateNumber, String? destinationAddress, String? originAddress, String? rejectedTime, String? completedTime, String? assignedDate, String? freightBookingNumber,
   List<DriverReassignment>? reassigned,  bool? isReassigned}) {
    return Transaction(
      id: id,
      name: name ?? this.name,
      origin:origin ?? this.origin,
      destination:destination ?? this.destination,
      arrivalDate: arrivalDate,
      deliveryDate: deliveryDate,
      status: status ?? this.status,
      dispatchType: dispatchType,
     containerNumber: containerNumber,
      isAccepted: isAccepted ?? this.isAccepted,
  
      freightBlNumber: freightBlNumber,
      sealNumber: sealNumber,
      bookingRefNo: bookingRefNo,
      transportForwarderName: transportForwarderName,
      freightBookingNumber:freightBookingNumber,
      originContainerYard:originContainerYard,
      requestNumber:requestNumber ?? this.requestNumber,
      deRequestNumber:deRequestNumber,
      plRequestNumber:plRequestNumber,
      dlRequestNumber:dlRequestNumber,
      peRequestNumber:peRequestNumber,
      requestStatus:requestStatus ?? this.requestStatus,
      deRequestStatus:deRequestStatus,
      plRequestStatus:plRequestStatus,
      dlRequestStatus:dlRequestStatus,
      peRequestStatus:peRequestStatus,
      deTruckDriverName: deTruckDriverName,
      dlTruckDriverName: dlTruckDriverName,
      peTruckDriverName: peTruckDriverName,
      plTruckDriverName: plTruckDriverName,
      freightForwarderName: freightForwarderName,
      truckPlateNumber: truckPlateNumber ?? truckPlateNumber,
      deTruckPlateNumber: deTruckPlateNumber,
      plTruckPlateNumber: plTruckPlateNumber,
      dlTruckPlateNumber: dlTruckPlateNumber,
      peTruckPlateNumber: peTruckPlateNumber,
      truckType: truckType ?? truckType,
      deTruckType: deTruckType,
      plTruckType: plTruckType,
      dlTruckType: dlTruckType,
      peTruckType: peTruckType,
      contactNumber: contactNumber,
      contactPerson: contactPerson,
      vehicleName: vehicleName,
      deProof: deProof,
      plProof: plProof,
      dlProof: dlProof,
      peProof: peProof,

      deProofFilename: deProofFilename,
      plProofFilename: plProofFilename,
      dlProofFilename: dlProofFilename,
      peProofFilename: peProofFilename,

      deSign: deSign,
      plSign: plSign,
      dlSign: dlSign, 
      peSign: peSign,

      pickupDate: pickupDate,
      departureDate: departureDate,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      serviceType: serviceType,
      stageId: stageId,
      completedTime: completedTime ?? completedTime,
      deCompletedTime: deCompletedTime,
      plCompletedTime: plCompletedTime,
      dlCompletedTime: dlCompletedTime,
      peCompletedTime: peCompletedTime,

      rejectedTime: rejectedTime ?? rejectedTime,
      deRejectedTime: deRejectedTime,
      plRejectedTime: plRejectedTime,
      dlRejectedTime: dlRejectedTime,
      peRejectedTime: peRejectedTime,
      shipperProvince: shipperProvince,
      shipperCity: shipperCity,
      shipperBarangay: shipperBarangay,
      shipperStreet: shipperStreet,
      consigneeProvince: consigneeProvince,
      consigneeCity: consigneeCity,
      consigneeBarangay: consigneeBarangay,
      consigneeStreet: consigneeStreet,
      assignedDate: assignedDate ?? assignedDate,
      deAssignedDate: deAssignedDate,
      plAssignedDate: plAssignedDate,
      dlAssignedDate: dlAssignedDate,
      peAssignedDate: peAssignedDate,
      landTransport: landTransport,
      writeDate: writeDate,

      peReleasedBy: peReleasedBy,
      deReleasedBy: deReleasedBy,
      dlReceivedBy: dlReceivedBy,
      plReceivedBy: plReceivedBy,

      bookingRefNumber:bookingRefNumber,
      

      login: login,
       history: history,
       backloadConsolidation: backloadConsolidation,
       reassigned: reassigned ?? this.reassigned,

        // completeAddress: completeAddress, 

      proofStock: proofStock,
      proofStockFilename: proofStockFilename,
      hwbSigned: hwbSigned,
      hwbSignedFilename: hwbSignedFilename,
      deliveryReceipt: deliveryReceipt,
      deliveryReceiptFilename: deliveryReceiptFilename,
      packingList: packingList,
      packingListFilename: packingListFilename,
      deliveryNote: deliveryNote,
      deliveryNoteFilename: deliveryNoteFilename,
      stockDelivery: stockDelivery,
      stockDeliveryFilename: stockDeliveryFilename,
      salesInvoice: salesInvoice,
      salesInvoiceFilename: salesInvoiceFilename,

      isReassigned: isReassigned
      
    );
  }
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.requestNumber == requestNumber;
  }

  @override
  int get hashCode => Object.hash(id, requestNumber);
}