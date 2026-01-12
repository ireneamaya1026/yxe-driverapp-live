// ignore_for_file: avoid_print, unused_import

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/milestone_history_model.dart';
import 'package:frontend/models/reject_reason_model.dart' show RejectionReason;
import 'package:frontend/models/transaction_model.dart'; // Import your model file
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/notifiers/navigation_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
import 'package:frontend/provider/accepted_transaction.dart' as transaction_list;
import 'package:frontend/provider/base_url_provider.dart';
import 'package:frontend/provider/reject_provider.dart';
import 'package:frontend/provider/transaction_list_notifier.dart';
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/screen/homepage_screen.dart';
import 'package:frontend/screen/navigation_menu.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/confirmation.dart';
import 'package:frontend/user/detailed_details.dart';
import 'package:frontend/user/history_screen.dart';
import 'package:frontend/user/homepage_screen.dart';
import 'package:frontend/user/proof_of_delivery_screen.dart';
import 'package:frontend/util/transaction_utils.dart';
import 'package:frontend/util/transction_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // For getApplicationDocumentsDirectory / getExternalStorageDirectory
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:permission_handler/permission_handler.dart' as locperm;
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:device_info_plus/device_info_plus.dart';





class TransactionDetails extends ConsumerStatefulWidget {
  final Transaction? transaction; // Keep it nullable
  final String uid; // Add a field for uid

  // Constructor to accept the nullable Transaction object
  const TransactionDetails({
    super.key,
    required this.transaction,
    required this.uid, required int id,
  });

  // Helper function to handle null values and provide fallback
  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback; // If value is null, return fallback
  }
  



  @override
  ConsumerState<TransactionDetails> createState() => _TransactionDetailsState();
}

  
class _TransactionDetailsState extends ConsumerState<TransactionDetails> {
  
  // final Map<String, bool> _loadingStates = {};
  

  gmaps.GoogleMapController? _googleMapController;
   Transaction? transaction;

 
  Location location = Location();
  // bool _isMapReady = false;
  locperm.PermissionStatus? _permissionGranted;
  bool _serviceEnabled = false;
  // LocationData? _locationData;
  static const gmaps.LatLng _pointA = gmaps.LatLng(10.300233284867856, 123.91189477293283);
  static const gmaps.LatLng _pointB = gmaps.LatLng(10.298462163232422, 123.8950565989957);
  static const gmaps.LatLng _pointC = gmaps.LatLng(10.308225643109328, 123.90735316709156);

  int? _expandedTabIndex;

 
  bool get isFreightFirst {
    // Replace with actual logic or remove if not needed
   
    // Example if you want to compare:
    return widget.transaction?.requestNumber == widget.transaction?.deRequestNumber || widget.transaction?.requestNumber ==widget.transaction?. dlRequestNumber;
  }

  List<String> get tabTitles {
    final type = widget.transaction?.dispatchType;
    final title = type == 'dt' ? 'Consignee' : 'Shipper';
    if(isFreightFirst){
      return ['Yard/Port', title];
    } else {
      return [title, 'Yard/Port'];
    }
      
  }
   Transaction? leg;

   
  
  @override
  void initState() {
    super.initState();
    initLocation();
    _expandedTabIndex = 1;
     _fetchTransactionDetails();
  }

  bool isLoading = true;

Future<void> _fetchTransactionDetails() async {
  print("Fetching details for transaction ID: ${widget.transaction?.id}");
  print("Request Number: ${widget.transaction?.requestNumber}");
  print('➡️ TransactionDetails params: id=${widget.transaction?.id}, uid=${widget.uid}');

  try {
    final baseUrl = ref.read(baseUrlProvider);
    final response = await http.get(
      Uri.parse('$baseUrl/api/odoo/booking/transaction_details/${widget.transaction?.id}?uid=${widget.uid}'),
      headers: {
        'Content-Type': 'application/json',
          'Accept': 'application/json',
          'password': ref.read(authNotifierProvider).password ?? '',
          'login':ref.read(authNotifierProvider).login ?? ''
      },
    );

  if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      // check if structure is what you expect
      final data = jsonData['data'];
      final transactions = data?['transactions'];

      if (transactions != null && transactions is List && transactions.isNotEmpty) {
        final selected = transactions.firstWhere(
          (tx) => tx['id'] == widget.transaction?.id,
          orElse: () => transactions.first,
        );

        debugPrint('✅ Found transaction: ${selected['id']}');

        setState(() {
          transaction = Transaction.fromJson(selected);
          isLoading = false;
        });
      } else {
        debugPrint('⚠️ No transactions found in response.');
        setState(() => isLoading = false);
      }
    } else {
      debugPrint('❌ Failed request. Code: ${response.statusCode}');
      setState(() => isLoading = false);
    }
  } catch (e) {
    setState(() => isLoading = false);
    debugPrint('Error fetching transaction: $e');
  }
  
}

  Future<void> initLocation() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    _permissionGranted = (await location.hasPermission()) as perm.PermissionStatus?;
    if (_permissionGranted == locperm.PermissionStatus.denied) {
      _permissionGranted = (await location.requestPermission()) as perm.PermissionStatus?;
      if (_permissionGranted != locperm.PermissionStatus.granted) return;
    }

    // _locationData = await location.getLocation();

    
  }



  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback;
  }

  String formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "—"; // Handle null values
    
    try {
      DateTime dateTime = DateTime.parse("${dateString}Z").toLocal();
       // Convert string to DateTime
       return DateFormat('MMMM d, yyyy - h:mm a').format(dateTime); // Format date-time
    } catch (e) {
      return "Invalid Date"; // Handle errors gracefully
    }
  } 

 
 
  


  @override
  Widget build(BuildContext context) {
    // Early return if transaction is null
    if (transaction == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

  // At this point, transaction is guaranteed non-null
  final bookingNumber = transaction?.bookingRefNumber?.trim();
  final String driverId = ref.watch(authNotifierProvider).partnerId ?? '';

  final Map<String, dynamic> scheduleMap = TransactionUtils.getScheduleForTransaction(transaction!, driverId, widget.transaction?.requestNumber);
  final expandedList = TransactionUtils.expandTransaction(transaction!, driverId);
  final openedRequestNumber = widget.transaction?.requestNumber;

  // For OT
  if (transaction!.dispatchType == "ot") {
    leg = expandedList.firstWhere(
      (tx) => (tx.plTruckDriverName == driverId || tx.deTruckDriverName == driverId) &&
              tx.requestNumber == openedRequestNumber,
      orElse: () => expandedList.first,
    );
  } else if (transaction!.dispatchType == "dt") {
    leg = expandedList.firstWhere(
      (tx) => (tx.dlTruckDriverName == driverId || tx.peTruckDriverName == driverId) &&
              tx.requestNumber == openedRequestNumber,
      orElse: () => expandedList.first,
    );
  }
 


  final pickup = scheduleMap['pickup'];
  final delivery = scheduleMap['delivery'];
  final showTabs = widget.transaction?.requestStatus == "Ongoing";
    return Consumer(
      builder: (context, ref, child) {
        final allTransactions = ref.watch(transactionListProvider);

        final relatedFF = allTransactions.cast<Transaction?>().firstWhere(
          (tx) =>
            tx?.bookingRefNumber?.trim() == bookingNumber &&
            tx?.dispatchType?.toLowerCase().trim() == 'ff',
          orElse: () => null,
        );

        if (isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (transaction == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Booking Details")),
            body: const Center(child: Text("No transaction details available.")),
          );
        }
      
       // If transaction is not null, display its details
        return Scaffold(
          appBar: AppBar(
            iconTheme: const IconThemeData(color: mainColor),
          ),
          
          body: Padding(
            padding: const EdgeInsets.all(14.0),
            child: ListView( // Use ListView to allow scrolling
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      // color: Colors.green[500], // Set background color for this section
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        getNullableValue(widget.transaction?.name).toUpperCase(), // Section Title
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ),
             
                    Padding(
                 
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(widget.transaction?.originAddress?.toUpperCase() ?? '',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),  
                      ),
                    ),

                  ],
                ),
                
                if (showTabs) ...[
                  Row(
                    children: List.generate(tabTitles.length, (index) {
                      final bool isSelected = _expandedTabIndex == index;
                      

                      final Color tabColor = isSelected ? mainColor : bgColor;


                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                if(_expandedTabIndex == index) {
                                  _expandedTabIndex = null;
                                } else {
                                  _expandedTabIndex = index;
                                }
                              });
                            // });
                            
                          },
                          child: Container (
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border (
                                bottom: BorderSide(
                                  color: tabColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tabTitles[index],
                              style: AppTextStyles.body.copyWith(
                                color:  tabColor,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (isFreightFirst) ...[
                    if (_expandedTabIndex == 0) _buildFreightTab(),
                    if (_expandedTabIndex == 1) _buildShipConsTab(),
                  ] else ...[
                    if (_expandedTabIndex == 0) _buildShipConsTab(),
                    if (_expandedTabIndex == 1) _buildFreightTab(),
                  ]

                ],
                const SizedBox(height: 12), 
                Container(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: mainColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // Space between icon and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Space between label and value
                          
                          Text(
                            "Request Number",
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: mainColor,
                            ),
                          ),
                          Text(
                            widget.transaction?.requestNumber ?? '',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),// Add some space between sections
                Container(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: mainColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // Space between icon and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Space between label and value
                          
                          Text(
                            
                            "Dispatch Booking  Number",
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: mainColor,
                            ),
                          ),
                          Text(
                            transaction?.bookingRefNo ?? '',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: mainColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // Space between icon and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Space between label and value
                          
                          Text(
                            "Freight Booking Number",
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: mainColor,
                            ),
                          ),
                          Text(
                            (transaction?.freightBookingNumber?.isNotEmpty ?? false)
                              ? transaction!.freightBookingNumber! : '—',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: mainColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // Space between icon and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Space between label and value
                          
                          Text(
                            "Freight BL Number",
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: mainColor,
                            ),
                          ),
                          Text(
                            (transaction?.freightBlNumber?.isNotEmpty ?? false)
                              ?transaction!.freightBlNumber! : '—',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: mainColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // Space between icon and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Space between label and value
                          
                          Text(
                            "Container Number",
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: mainColor,
                            ),
                          ),
                          Text(
                            (transaction?.containerNumber?.isNotEmpty ?? false)
                              ? transaction!.containerNumber! : '—',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Column( // Use a Column to arrange the widgets vertically
                  crossAxisAlignment: CrossAxisAlignment.center, // Align text to the left
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: mainColor,
                            size: 30,
                          ),
                          const SizedBox(width: 8), // Space between icon and text
                          Expanded (
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Space between label and value
                                Text(
                                  leg?.origin ?? '',
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: mainColor,
                                  ),
                                ),
                              Text(
                                  "Pick-up Address",
                                  style: AppTextStyles.caption.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 18), // Match left padding with location icon
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center, // Center dots with the location pin tip
                          children: List.generate(3, (_) => const Padding(
                            padding: EdgeInsets.symmetric(vertical: .0), // Adjust spacing
                            child: Icon(
                              Icons.circle_rounded,
                              color: mainColor,
                              size: 8,
                            ),
                          )),
                        ),
                      ],
                    ),
                    
                    // const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(7.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                        children: [
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8), // Space between icon and text
                          Expanded (
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Space between label and value
                                Text(
                                 leg?.destination ?? '',
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: mainColor,
                                  )
                                ),
                                Text(
                                  "Delivery Address",
                                  style: AppTextStyles.caption.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    Column(
  children: [
    if (!(transaction?.serviceType == "Less-Than-Container Load" && transaction?.dispatchType == 'DT')) // Show pickup unless serviceType=2 and dispatchType=DT
      Container(
        padding: const EdgeInsets.all(7.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 5),
            const Icon(
              Icons.calendar_today_outlined,
              color: mainColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(pickup?.scheduledDatetime),
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
                Text(
                  "Pick-up Date",
                  style: AppTextStyles.caption.copyWith(
                    color: mainColor,
                  ),
                ),
              ],
            ),
            )
            
          ],
        ),
      ),

    if (!(transaction?.serviceType == "Less-Than-Container Load" && transaction?.dispatchType == 'OT')) // Show delivery unless serviceType=2 and dispatchType=OT
      Container(
        padding: const EdgeInsets.all(7.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 5),
            const Icon(
              Icons.calendar_today_outlined,
              color: mainColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(delivery?.scheduledDatetime),
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
                Text(
                  "Delivery Date",
                  style: AppTextStyles.caption.copyWith(
                    color: mainColor,
                  ),
                ),
              ],
            ),
            )
            
          ],
        ),
      ),
  ],
),

                    if(transaction?.landTransport != "transport")
                    Container(
                      padding: const EdgeInsets.all(7.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // Align top of icon and text
                        children: [
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.directions_boat_filled_outlined,
                            color: mainColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8), // Space between icon and text
                          
                          Expanded(
                            child:Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text( 
                                transaction?.dispatchType == 'ot' ? formatDateTime(transaction?.departureDate)
                                : formatDateTime(transaction?.arrivalDate),
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: mainColor,
                                )
                              ),
                              Text(
                               transaction?.dispatchType == 'ot' ? " Vessel Departure Date" 
                                :  "Vessel Arrival Date",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                          )
                          
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                
                  ],
                ),
                SizedBox(
                        height: 300,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: _pointA,
                              zoom: 13,
                            ),
                            markers: {
                              gmaps.Marker(
                                markerId: const MarkerId("current_location"),
                                position: _pointA,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                              ),
                              gmaps.Marker(
                                markerId: const MarkerId("source_location"),
                                position: _pointB,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                              ),
                              gmaps.Marker(
                                markerId: const MarkerId("first_location"),
                                position: _pointC,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                              ),
                            },
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            zoomControlsEnabled: true,
                            onMapCreated: (controller) {
                              controller = _googleMapController!;
                            },
                          ),
                        ),
                      ),
              ],
            ),
            
          ),
          bottomNavigationBar: Column (
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column (
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity, // Make the button full width
                      child: ElevatedButton(
                      onPressed: () async {
                        // if (widget.transaction?.requestStatus != 'Pending') {
                        if (leg?.requestStatus == 'Ongoing') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConfirmationScreen(uid: widget.uid, transaction:leg, relatedFF:relatedFF, requestNumber: leg!.requestNumber, id: widget.transaction?.id ?? 0,),
                            ),
                          );
                        }else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailedDetailScreen(uid: widget.uid, transaction: leg, relatedFF: relatedFF),
                            ),
                          );
                        }
                        
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 80,
                          vertical: 20,
                        ),
                        disabledForegroundColor: mainColor,
                        disabledBackgroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        
                        'View Booking',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center, // Ensure the text is centered
                        overflow: TextOverflow.ellipsis, // Handle overflow if needed
                        maxLines: 1,
                      ),
                    ),
                  ),
                   
                    
                    
                  ],
                  
                ),
            
              ),
              const NavigationMenu(),
            ],
          )
          
        

        );
      },
    );
  }

  Widget _buildFreightTab (){

    final isDT = widget.transaction?.dispatchType == 'dt';

      
   

    Uint8List? decodeBase64(String? data) {
      if(data == null || data.isEmpty)  return null;
      try{
      
        return base64Decode(data.trim());
      } catch (e) {
        debugPrint('Base64 error: $e');
        return null;
      }
    }

    String? signBase64;
    String? proofBase64;
    String? filename;

    // print('Request Number:${transaction?.requestNumber}' );
    

    if (isDT) {
      if (widget.transaction?.requestNumber == transaction?.dlRequestNumber) {
        signBase64 = transaction?.plSign;
        proofBase64 = transaction?.plProof;
        filename = transaction?.plProofFilename;
      } else if (widget.transaction?.requestNumber == transaction?.peRequestNumber) {
        signBase64 = transaction?.deSign;
        proofBase64 = transaction?.deProof;
        filename = transaction?.deProofFilename;
      }
    } else {
      if (widget.transaction?.requestNumber == transaction?.deRequestNumber) {
        signBase64 = transaction?.peSign;
        proofBase64 = transaction?.peProof;
        filename = transaction?.peProofFilename;
      } else if (widget.transaction?.requestNumber == transaction?.plRequestNumber) {
        signBase64 = transaction?.dlSign;
        proofBase64 = transaction?.dlProof;
        filename = transaction?.dlProofFilename;
       
      }
    }

    final signBytes = decodeBase64(signBase64);
    final proofBytes = decodeBase64(proofBase64);


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
        'Yard/Port Documents',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),
        const SizedBox(height: 10),
        if (proofBytes != null)
        _buildDownloadButton("POD", proofBytes),

        const SizedBox(height: 10),

        if(signBytes != null)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImage(imageBytes: signBytes),
                ),
              );
            },
            child: Image.memory(signBytes, height: 100),
          ),

          
       
      ],
    );
  }

  Widget _buildShipConsTab (){
    final isDT = transaction?.dispatchType == 'dt';

    Uint8List? decodeBase64(String? data) {
      if(data == null || data.isEmpty)  return null;
      try{
      
        return base64Decode(data.trim());
      } catch (e) {
        debugPrint('Base64 error: $e');
        return null;
      }
    }

     List<Map<String, dynamic>> shipperConsigneeFiles = [];
    
    void addFile(List<Map<String, dynamic>> targetList, String? base64, String? filename) {
      if (base64 != null && base64.trim().isNotEmpty) {
        final decoded = decodeBase64(base64);
        if (decoded != null) {
          final safeName = (filename == null || filename.trim().isEmpty)
              ? 'file_${targetList.length + 1}.png'
              : filename;
          targetList.add({
            "bytes": decoded,
            "filename": safeName,
          });
        }
      }
    }


    String? signBase64;
    String? proofBase64;
    String? filename;
    

    if (isDT) {
      if (widget.transaction?.requestNumber == transaction?.dlRequestNumber) {
        signBase64 = transaction?.dlSign;
        proofBase64 = transaction?.dlProof;
        filename = transaction?.dlProofFilename;
        addFile(shipperConsigneeFiles, transaction?.dlProof, transaction?.dlProofFilename);
      } else if (widget.transaction?.requestNumber == transaction?.peRequestNumber) {
        signBase64 = transaction?.peSign;
        proofBase64 = transaction?.peProof;
        filename = transaction?.peProofFilename;
        addFile(shipperConsigneeFiles, transaction?.peProof, transaction?.peProofFilename); 
      }
    } else {
      if (widget.transaction?.requestNumber == transaction?.deRequestNumber) {
        signBase64 = transaction?.deSign;
        proofBase64 = transaction?.deProof;
        filename = transaction?.deProofFilename;
        addFile(shipperConsigneeFiles, transaction?.deProof, transaction?.deProofFilename);
      } else if (widget.transaction?.requestNumber == transaction?.plRequestNumber) {
        signBase64 = transaction?.plSign;
        proofBase64 = transaction?.plProof;
        filename = transaction?.dlProofFilename;
        addFile(shipperConsigneeFiles, transaction?.plProof, transaction?.plProofFilename); // shipper has plProof
        addFile(shipperConsigneeFiles, transaction?.proofStock, transaction?.proofStockFilename); // shipper has stock transfer
      }
    }

    final signBytes = decodeBase64(signBase64);
    final proofBytes = decodeBase64(proofBase64);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDT ? 'Consignee Documents' : 'Shipper Documents',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),
         const SizedBox(height: 10),
         if (shipperConsigneeFiles.isNotEmpty)
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 8, // horizontal gap
          runSpacing: 8, // vertical gap
          children: shipperConsigneeFiles.map((file) {
            return _buildDownloadButton(
              file["filename"] as String,
              file["bytes"] as Uint8List,
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        if(signBytes != null)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImage(imageBytes: signBytes),
                ),
              );
            },
            child: Image.memory(signBytes, height: 100),
          ),

       
      ],
    );
  }

  Widget _buildDownloadButton(String fileName, Uint8List bytes) {
      return SizedBox(
        child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextButton.icon(
              onPressed: 
              () async {
                try {
                  if (Platform.isAndroid) {
                    int sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

                    if (sdk <= 29) {
                      // ✅ Android 9 & 10
                      await Permission.storage.request();
                    } else {
                      // ✅ Android 11+
                      if (await Permission.manageExternalStorage.isDenied) {
                        await Permission.manageExternalStorage.request();
                      }
                    }
                  }

                  Directory dir = Platform.isAndroid
                      ? Directory('/storage/emulated/0/Download')
                      : await getApplicationDocumentsDirectory();

                  if (!await dir.exists()) {
                    dir = await getExternalStorageDirectory() ?? dir;
                  }
                  
                  final ext = fileName.split('.').last;
                  final baseName = fileName.replaceAll('.$ext', '');
                  String uniqueFileName =  fileName;

                  int counter = 1;
                   while (File('${dir.path}/$uniqueFileName').existsSync()) {
                    uniqueFileName = '$baseName($counter).$ext';
                    counter++;
                  }
                  
                  final file = File('${dir.path}/$uniqueFileName');
                  await file.writeAsBytes(bytes);
                  
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Downloaded: $uniqueFileName',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating, // ✅ Makes it float with margin
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder( // ✅ Rounded corners
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: mainColor, // ✅ Soft black, not pure #000
                        elevation: 6, // ✅ Soft shadow for depth
                      ),
                    );
                  }

                  print('✅ File saved: ${file.path}');
                } catch (e) {
                  print('❌ Save failed: $e');
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '❌ Download failed: $fileName',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating, // ✅ Makes it float with margin
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder( // ✅ Rounded corners
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.red, // ✅ Soft black, not pure #000
                        elevation: 6, // ✅ Soft shadow for depth
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label:Text(
                'Download $fileName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false, // ✅ Force no wrapping!
                style: AppTextStyles.caption,
              )
            ),
          )
      
      );
    }


}

  



// Move FullScreenImage to the top-level (outside of any class)
class FullScreenImage extends StatelessWidget{
  final Uint8List imageBytes;

  const FullScreenImage({super.key, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: Center (
        child: InteractiveViewer(child: Image.memory(imageBytes)),
      )
    );
  }
}

