// ignore_for_file: unused_import, avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/milestone_history_model.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
import 'package:frontend/provider/base_url_provider.dart';
import 'package:frontend/provider/theme_provider.dart';
import 'package:frontend/provider/transaction_list_notifier.dart';
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/screen/navigation_menu.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/schedule.dart';
import 'package:frontend/util/transaction_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:device_info_plus/device_info_plus.dart';


class HistoryDetailScreen extends ConsumerStatefulWidget {
  final String uid;
  final Transaction? transaction;

  const HistoryDetailScreen({super.key, required this.uid, required this.transaction});

  @override
  ConsumerState<HistoryDetailScreen> createState() => _HistoryDetailState();
}

class _HistoryDetailState extends ConsumerState<HistoryDetailScreen> {
 
  Transaction? transaction;
  Transaction? leg;

  int? _expandedTabIndex;



  List<String> get tabTitles {
    final type = widget.transaction?.dispatchType;
    final title = type == 'dt' ? 'Consignee Info' : 'Shipper Info';
   
      return [title, 'Proof of Delivery'];

      
  }

  @override
  void initState() {
    super.initState();
    _expandedTabIndex = 0; // Default to the first tab
    _fetchHistoryDetails();
  }

  bool isLoading = true;

Future<void> _fetchHistoryDetails() async {
  final uid = ref.read(authNotifierProvider).uid ?? '';

  print("Fetching details for transaction ID: ${widget.transaction?.id}");
  print("Request Number: ${widget.transaction?.requestNumber}");
  print('➡️ TransactionDetails params: id=${widget.transaction?.id}, uid=$uid');

  try {
    final baseUrl = ref.read(baseUrlProvider);
    final response = await http.get(
      Uri.parse('$baseUrl/api/odoo/booking/history_details/${widget.transaction?.id}?uid=$uid'),
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


  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback;
  }




  String formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A"; // Handle null values
    
    try {
      DateTime dateTime = DateTime.parse(dateString); // Convert string to DateTime
      DateTime adjustedTime = dateTime.add(const Duration(hours:8));
      return DateFormat('dd MMM, yyyy  - h:mm a').format(adjustedTime); // Format date-time
    } catch (e) {
      return "Invalid Date"; // Handle errors gracefully
    }
  } 


  
  @override
  Widget build(BuildContext context) {
     if (isLoading) {
    // Show a loading spinner while fetching data
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  

  // Once loaded, show the normal content
  final transaction = this.transaction ?? widget.transaction;
    
    // 1️⃣ Backloaded message
    final backloadedName = (widget.transaction?.backloadConsolidation?.name.trim().isNotEmpty ?? false)
        ? widget.transaction?.backloadConsolidation?.name
        : 'N/A';
    final backloadedMessage = 'This booking has been backloaded: $backloadedName';
    

   final String driverId = ref.watch(authNotifierProvider).partnerId ?? '';

  final Map<String, dynamic> scheduleMap = TransactionUtils.getScheduleForTransaction(transaction!, driverId, widget.transaction?.requestNumber);
  final expandedList = TransactionUtils.expandTransaction(transaction, driverId);
  final openedRequestNumber = widget.transaction?.requestNumber;

 

  // For OT
  if (transaction.dispatchType == "ot") {
    leg = expandedList.firstWhere(
      (tx) => (tx.plTruckDriverName == driverId || tx.deTruckDriverName == driverId) &&
              tx.requestNumber == openedRequestNumber,
      orElse: () => expandedList.first,
    );
  } else if (transaction.dispatchType == "dt") {
    leg = expandedList.firstWhere(
      (tx) => (tx.dlTruckDriverName == driverId || tx.peTruckDriverName == driverId) &&
              tx.requestNumber == openedRequestNumber,
      orElse: () => expandedList.first,
    );
  }

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: mainColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 35, width: 20), // Space for icon or alignment
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.transaction?.originAddress ?? '—',
                          style: AppTextStyles.body.copyWith(
                            color: mainColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold
                          ),
                          softWrap: true,
                          maxLines: 2, // Optional: limit to 2 lines
                          overflow: TextOverflow.ellipsis, // Optional: fade or clip if it overflows
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              

              Container(
                padding: const EdgeInsets.all(14.0), // Add padding inside the container
                
                decoration: BoxDecoration(
                  color: (widget.transaction?.requestStatus == 'Completed') ? const Color.fromARGB(255, 45, 144,111) : (widget.transaction?.stageId == 'Cancelled') ?  Colors.red[500] : Colors.grey, // Background color based on status
                  borderRadius: BorderRadius.circular(20.0), // Rounded edges
                ),
                
                child: Column( // Use a Column to arrange the widgets vertically
                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                  children: [
                    
                    Row(
                      children: [
                        const SizedBox(height: 50, width: 20,), // Space between icon and text
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Space between label and value
                            Text(
                             widget.transaction?.bookingRefNo ?? '—',
                              style: AppTextStyles.subtitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                             Text(
                              "Dispatch Reference Number",
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const SizedBox(width: 20), // Space between icon and text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                                widget.transaction?.requestNumber ?? '',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Request Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
      // 🕒 Display correct date depending on status
      Text(
        (() {
         print("isReassigned: ${widget.transaction?.isReassigned}");

          if (widget.transaction?.isReassigned == true &&
              (widget.transaction?.reassigned?.isNotEmpty ?? false)) {
            return formatDateTime(widget.transaction!.reassigned!.first.createDate);
          } 
          // ✅ Completed or stage completed
          else if (widget.transaction?.requestStatus == 'Completed' ) {
            final completedDate = widget.transaction?.completedTime;
            final deliveryActual = scheduleMap['delivery']?.actualDatetime;

            if (completedDate != null && completedDate.isNotEmpty) {
              return formatDateTime(completedDate);
            } else if (deliveryActual != null && deliveryActual.isNotEmpty) {
              // fallback to delivery actual datetime
              return formatDateTime(deliveryActual);
            } else {
              return '—';
            }
          } 
          // Cancelled
          else if (widget.transaction?.stageId == 'Cancelled') {
            return formatDateTime(widget.transaction?.writeDate);
          } 
          // Backload
          else if (widget.transaction?.requestStatus == 'Backload') {
            return formatDateTime(widget.transaction?.backloadConsolidation?.consolidatedDatetime);
          } 
          // Default
          else {
            return '—';
          }
        })(),
        style: AppTextStyles.subtitle.copyWith(color: Colors.white),
      ),
      // 🏷 Label
      Text(
        (() {
          if (widget.transaction?.isReassigned == true &&
              (widget.transaction?.reassigned?.isNotEmpty ?? false)) {
            return 'Reassigned Date';
          } else if (widget.transaction?.requestStatus == 'Completed' ) {
            return 'Completed Date';
          } else if (widget.transaction?.stageId == 'Cancelled') {
            return 'Cancelled Date';
          } else if (widget.transaction?.requestStatus == 'Backload') {
            return 'Consolidated Date';
          } else {
            return '—';
          }
        })(),
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),  
              (widget.transaction?.requestStatus == "Reassigned") ?
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'This booking was reassigned to another driver.',
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  )
                )
                : 
              (widget.transaction?.stageId == "Cancelled") ?
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'This booking was cancelled.',
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  )
                )
                : (widget.transaction?.requestStatus == "Backload") ?
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                    child: Text(
                      backloadedMessage,
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),

                  )
                ) : Column(
                  children: [
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
            
                if (_expandedTabIndex == 0) _buildFreightTab(),
                if (_expandedTabIndex == 1) _buildShipConsTab(),

                const SizedBox(height: 20),
              ],
            )
          ]
                  
   
      
              
          ),
          
        ),
        
      ),
      
      // bottomNavigationBar: const NavigationMenu(),
    );
  } 

  Widget _buildShipConsTab (){

    final transaction = this.transaction ?? widget.transaction;
    if (transaction == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDT = widget.transaction?.dispatchType == 'dt';
     final String driverId = ref.watch(authNotifierProvider).partnerId ?? '';

  final Map<String, dynamic> scheduleMap = TransactionUtils.getScheduleForTransaction(transaction, driverId, widget.transaction?.requestNumber);
  final expandedList = TransactionUtils.expandTransaction(transaction, driverId);
  final openedRequestNumber = widget.transaction?.requestNumber;

  // For OT
  if (transaction.dispatchType == "ot") {
    leg = expandedList.firstWhere(
      (tx) => (tx.plTruckDriverName == driverId || tx.deTruckDriverName == driverId) &&
              tx.requestNumber == openedRequestNumber,
      orElse: () => expandedList.first,
    );
  } else if (transaction.dispatchType == "dt") {
    leg = expandedList.firstWhere(
      (tx) => (tx.dlTruckDriverName == driverId || tx.peTruckDriverName == driverId) &&
              tx.requestNumber == openedRequestNumber,
      orElse: () => expandedList.first,
    );
  }
 


  final pickup = scheduleMap['pickup'];
  final delivery = scheduleMap['delivery'];
    final isDiverted = transaction.backloadConsolidation?.isDiverted == "true";
    final divertedBookingNo = isDiverted 
    ? 'Diverted Booking No: ${transaction.backloadConsolidation?.name ?? '—'}'
    : null;
    final consolStatus = transaction.backloadConsolidation?.status;


    print('pickup actual datetime: ${pickup?.actualDatetime}');
    print('Dispatch Typr: ${transaction.dispatchType}');
    print("request Number: ${widget.transaction?.requestNumber}");
    print("Seal Number: ${transaction.sealNumber}");
    print("Is Diverted: $isDiverted");
    print("'Diverted Booking No: ${transaction.backloadConsolidation?.name ?? '—'}'");
    print("Consol Status $consolStatus");

    
   

    Uint8List? decodeBase64(String? data) {
      if(data == null || data.isEmpty)  return null;
      try{
      
        return base64Decode(data.trim());
      } catch (e) {
        debugPrint('Base64 error: $e');
        return null;
      }
    }

    List<Map<String, dynamic>> yardFiles = [];
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

    String? yardSignBase64;
    String? signBase64;
    String? name;
    String? yardName;
    String? yardactualdate;
    String? actualdate;
    String? yardtitle;
    String? title;


    if (isDT) {
      // === DT LOGIC (existing) ===
      if (widget.transaction?.requestNumber == transaction.dlRequestNumber) {
        String tempYardSign =transaction.plSign ?? '';
        String tempSign =transaction.dlSign ?? '';
        String tempYardName =transaction.peReleasedBy ?? '';
        String tempName =transaction.deReleasedBy ?? '';
        String tempYardActualDate = formatDateTime(pickup?.actualDatetime);
        String tempActualDate = formatDateTime(delivery?.actualDatetime);
        String tempYardTitle = "Yard/Port";
        String tempTitle = "Consignee";
        

          yardSignBase64 = tempYardSign;
          signBase64 = tempSign;
          yardName = tempYardName;
          name = tempName;
          yardactualdate = tempYardActualDate;
          actualdate = tempActualDate;
          yardtitle = tempYardTitle;
          title = tempTitle;
        
      } else if (widget.transaction?.requestNumber == transaction.peRequestNumber) {
        String tempYardSign =transaction.deSign ?? '';
        String tempSign =transaction.peSign ?? '';
        String tempYardName =transaction.plReceivedBy ?? '';
        String tempName =transaction.dlReceivedBy ?? '';
        String tempYardActualDate = formatDateTime(pickup?.actualDatetime);
        String tempActualDate = formatDateTime(delivery?.actualDatetime);
        String tempYardTitle = "Consignee";
        String tempTitle = "Yard/Port";

        if (isDiverted && consolStatus == 'draft') {
          yardSignBase64 = tempSign;
          signBase64 = tempYardSign;
          yardName = tempName;
          name = tempYardName;
          yardactualdate = tempYardActualDate;
          actualdate = tempActualDate;
          yardtitle = tempYardTitle;
          title = tempTitle;
        } else {
          yardSignBase64 = tempSign;
          signBase64 = tempYardSign;
          yardName = tempName;
          name = tempYardName;
          yardactualdate = tempYardActualDate;
          actualdate = tempActualDate;
          yardtitle = tempYardTitle;
          title = tempTitle;
        }
      } else {
        if (widget.transaction?.requestNumber == transaction.dlRequestNumber) {
          yardSignBase64 =transaction.peSign;
          signBase64 =transaction.deSign;
          yardName =transaction.peReleasedBy;
          name =transaction.deReleasedBy;
          yardactualdate = formatDateTime(pickup?.actualDatetime);
          actualdate = formatDateTime(delivery?.actualDatetime);
          yardtitle = "Yard/Port";
          title = "Shipper";

        } else if (widget.transaction?.requestNumber == transaction.plRequestNumber) {
          yardSignBase64 = transaction.dlSign;
          signBase64 = transaction.plSign;
          yardName = transaction.plReceivedBy;
          name = transaction.dlReceivedBy;
          yardactualdate = formatDateTime(pickup?.actualDatetime);
          actualdate = formatDateTime(delivery?.actualDatetime);
          yardtitle = "Shipper";
          title = "Yard/Port";
        }
      }

    } else {
      // === OT / NON-DT LOGIC (mirrored) ===
      if (widget.transaction?.requestNumber == transaction.deRequestNumber) {
        String tempYardSign = transaction.peSign ?? '';
        String tempSign = transaction.deSign ?? '';
        String tempYardName = transaction.peReleasedBy ?? '';
        String tempName = transaction.deReleasedBy ?? '';
        String tempYardActualDate = formatDateTime(pickup?.actualDatetime);
        String tempActualDate = formatDateTime(delivery?.actualDatetime);
        String tempYardTitle = "Yard/Port";
        String tempTitle = "Shipper";

        if (isDiverted && consolStatus == 'draft') {
          yardSignBase64 = tempSign;
          signBase64 = tempYardSign;
          yardName = tempName;
          name = tempYardName;
          yardactualdate = tempActualDate;
          actualdate = tempYardActualDate;
          yardtitle = tempTitle;
          title = tempYardTitle;
        } else {
          yardSignBase64 = tempYardSign;
          signBase64 = tempSign;
          yardName = tempYardName;
          name = tempName;
          yardactualdate = tempYardActualDate;
          actualdate = tempActualDate;
          yardtitle = tempYardTitle;
          title = tempTitle;
        }
      } else if (widget.transaction?.requestNumber == transaction.plRequestNumber) {
        String tempYardSign = transaction.dlSign ?? '';
        String tempSign = transaction.plSign ?? '';
        String tempYardName = transaction.plReceivedBy ?? '';
        String tempName = transaction.dlReceivedBy ?? '';
        String tempYardActualDate = formatDateTime(pickup?.actualDatetime);
        String tempActualDate = formatDateTime(delivery?.actualDatetime);
        String tempYardTitle = "Shipper";
        String tempTitle = "Yard/Port";

       
          yardSignBase64 = tempSign;
          signBase64 = tempYardSign;
          yardName = tempName;
          name = tempYardName;
          yardactualdate = tempYardActualDate;
          actualdate = tempActualDate;
          yardtitle = tempYardTitle;
          title = tempTitle;
        
      } else {
        // fallback — if no specific requestNumber matches
        yardSignBase64 = transaction.plSign;
        signBase64 = transaction.dlSign;
        yardName = transaction.plReceivedBy;
        name = transaction.dlReceivedBy;
        yardactualdate = formatDateTime(pickup?.actualDatetime);
        actualdate = formatDateTime(delivery?.actualDatetime);
        yardtitle = "Shipper";
        title = "Consignee";
      }
    }
    final yardSignBytes = decodeBase64(yardSignBase64);
    // final yardProofBytes = decodeBase64(yardProofBase64);

    final signBytes = decodeBase64(signBase64);
    // final proofBytes = decodeBase64(proofBase64);

    final reqNo = widget.transaction?.requestNumber;

  if (isDT && reqNo == transaction.dlRequestNumber) {
    // DT + dlRequestNumber:
    // Yard: only plProof
    addFile(yardFiles, transaction.plProof,transaction.plProofFilename ?? "POD");

    // Consignee (full pack): plProof + shared( hwbSigned, dlProof, deliveryReceipt, packingList, deliveryNote, stockDelivery, salesInvoice )
    addFile(shipperConsigneeFiles,transaction.dlProof,transaction.dlProofFilename);
    addFile(shipperConsigneeFiles,transaction.hwbSigned,transaction.hwbSignedFilename);
    addFile(shipperConsigneeFiles,transaction.deliveryReceipt,transaction.deliveryReceiptFilename);
    addFile(shipperConsigneeFiles,transaction.packingList,transaction.packingListFilename);
    addFile(shipperConsigneeFiles,transaction.deliveryNote,transaction.deliveryNoteFilename);
    addFile(shipperConsigneeFiles,transaction.stockDelivery,transaction.stockDeliveryFilename);
    addFile(shipperConsigneeFiles,transaction.salesInvoice,transaction.salesInvoiceFilename);
  }else  if (isDT && reqNo == transaction.peRequestNumber) {
    // DT + dlRequestNumber:
    // Yard: only plProof
    addFile(yardFiles, transaction.peProof, transaction.peProofFilename ?? "POD");
    addFile(shipperConsigneeFiles, transaction.deProof, transaction.deProofFilename ?? "POD");
  } 
  else if (!isDT && reqNo == transaction.plRequestNumber) {
    // OT + plRequestNumber:
    addFile(shipperConsigneeFiles, transaction.dlProof, transaction.dlProofFilename); // yard has dlProof
    addFile(yardFiles, transaction.plProof, transaction.plProofFilename); // shipper has plProof
    addFile(yardFiles, transaction.proofStock, transaction.proofStockFilename); // shipper has stock transfer
  } else if (!isDT && reqNo == transaction.deRequestNumber) {
    // Fallback: if nothing matches, attempt to add any non-null generic files so user can still download what's available
   
    addFile(yardFiles, transaction.peProof, transaction.peProofFilename);
    addFile(shipperConsigneeFiles, transaction.deProof, transaction.deProofFilename);

  }

    

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
        yardtitle!,
          style: AppTextStyles.body.copyWith(
            color: mainColor,
            fontWeight: FontWeight.bold, 
          )
        ),
        const SizedBox(height: 20),
        if(isDiverted && transaction.deRequestNumber == reqNo  && consolStatus != 'draft') ... [
          Text(
            "Remarks: Diverted",
            style: AppTextStyles.body.copyWith(
              color: mainColor,
              fontWeight: FontWeight.bold, 
            )
          ),
          const SizedBox(height: 20),
          Text(
            divertedBookingNo!,
            style: AppTextStyles.body.copyWith(
              color: mainColor,
            )
          ),
        ] else ... [
          Text(
        'Proof of Delivery',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),
        const SizedBox(height: 20),
        if (yardFiles.isNotEmpty)
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 8, // horizontal gap
          runSpacing: 8, // vertical gap
          children: yardFiles.map((file) {
            return _buildDownloadButton(
              file["filename"] as String,
              file["bytes"] as Uint8List,
            );
          }).toList(),
        ),
        Text(
          'Released by:  ${yardName ?? '—'}',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),
        const SizedBox(height: 20),
        Text(
        'Signature',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),
        const SizedBox(height: 20),

        if(yardSignBytes != null)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImage(imageBytes: yardSignBytes),
                ),
              );
            },
            child: Image.memory(yardSignBytes, height: 100),
          ),
          const SizedBox(height: 20),
         Text(
          'Actual Date and Time:  ${yardactualdate ?? '—'}',
            style: AppTextStyles.body.copyWith(
              color: mainColor,
            )
          ),
        ],
        
        const SizedBox(height: 20),
        const Divider(
          color: Colors.grey,
          thickness: 1,
        ),
        Text(
            //  isDT ? 'Consignee' : 'Shipper',
            title!,
            style: AppTextStyles.body.copyWith(
              color: mainColor,
              fontWeight: FontWeight.bold, 
            )
          ),
          const SizedBox(height: 20),

        // SHIPPER CONSIGNEE
        if(isDiverted && transaction.peRequestNumber == reqNo   && consolStatus != 'draft') ... [
          Text(
            "Remarks: Diverted",
            style: AppTextStyles.body.copyWith(
              color: mainColor,
              fontWeight: FontWeight.bold, 
            )
          ),
          const SizedBox(height: 20),
          Text(
            divertedBookingNo!,
            style: AppTextStyles.body.copyWith(
              color: mainColor,
            )
          ),
        ] else ...[
          
          Text(
          'Proof of Delivery',
            style: AppTextStyles.body.copyWith(
              color: mainColor,
            )
          ),
        const SizedBox(height: 20),
        if (shipperConsigneeFiles.isNotEmpty)
          Wrap(
          alignment: WrapAlignment.start,
          spacing: 8, // horizontal gap
          runSpacing: 8, // vertical gap
            children: shipperConsigneeFiles.map((file) {
              return _buildDownloadButton(file["filename"] as String, file["bytes"] as Uint8List);
            }).toList(),
          ),

        Text(
          'Released by:  ${name ?? '—'}',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),

        const SizedBox(height: 20),
        Text(
        'Signature',
          style: AppTextStyles.body.copyWith(
            color: mainColor,
          )
        ),
        const SizedBox(height: 20),

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
          const SizedBox(height: 20),
         Text(
          'Actual Date and Time: ${actualdate ?? '—'}',
            style: AppTextStyles.body.copyWith(
              color: mainColor,
            )
          ),
       
        ],

        ]
          
        
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
                  if(!mounted) return;
                  
                  // if(context.mounted){
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




  Widget  _buildFreightTab(){
    final isDiverted = widget.transaction?.backloadConsolidation?.isDiverted == "true";
    final isBackload = widget.transaction?.backloadConsolidation?.isBackload == "true";
    final consolStatus = widget.transaction?.backloadConsolidation?.status;

    final isDivertOrBackload = isDiverted || isBackload;
    final isConsolidated = consolStatus == "consolidated";

    final isDT = widget.transaction?.dispatchType == 'dt' &&
                widget.transaction?.requestNumber == widget.transaction?.peRequestNumber;

    final isOT = widget.transaction?.dispatchType == 'ot' &&
                widget.transaction?.requestNumber == widget.transaction?.deRequestNumber;


  

    final divertedPortName = (widget.transaction?.dispatchType == 'dt')
    ? (widget.transaction?.backloadConsolidation?.originName ?? '—')
    : (widget.transaction?.backloadConsolidation?.destinationName ?? '—');

  
    return  Column( // Use a Column to arrange the widgets vertically
      crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
      children: [
        if ((isDT || isOT) && isDivertOrBackload && isConsolidated)... [
      
        Row(
          children: [
            const SizedBox(width: 30), // Space between icon and text
            Expanded
            (
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Diverted Request",
                    style: AppTextStyles.subtitle.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Text(
                  divertedPortName,
                    // Use the originPort variable here
                    style: AppTextStyles.body.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  
                ],
              ),

            )
            
          ],
        
        ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const SizedBox(width: 30), // Space between icon and text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Port of Origin",
                  style: AppTextStyles.subtitle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  (widget.transaction != null)
                  ? ((widget.transaction!.dispatchType == 'ot'
                          ? widget.transaction!.rawOrigin
                          : widget.transaction!.rawDestination) ??
                      '—')
                  : '—',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black,
                  ),
                ),
                
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        Row(
          children: [
            const SizedBox(width: 30), // Space between icon and text
            Expanded
            (
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Service Provider",
                    style: AppTextStyles.subtitle.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Text(
                  (transaction?.freightForwarderName?.isNotEmpty ?? false)
                  ? transaction!.freightForwarderName! : '—',
                    // Use the originPort variable here
                    style: AppTextStyles.body.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  
                ],
              ),

            )
            
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const SizedBox(width: 30), // Space between icon and text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bill of Lading Number",
                  style: AppTextStyles.subtitle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  (transaction?.freightBlNumber?.isNotEmpty ?? false)
                  ? transaction!.freightBlNumber! : '—',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black,
                  ),
                ),
                
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        Row(
          children: [
            const SizedBox(width: 30), // Space between icon and text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Container Number",
                  style: AppTextStyles.subtitle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  
                (transaction?.containerNumber?.isNotEmpty ?? false)
                  ? transaction!.containerNumber!
                  : '—',
                  // Use the originPort variable here
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black,
                  ),
                ),
                
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),
        Row(
          children: [
            const SizedBox(width: 30), // Space between icon and text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Seal Number",
                  style: AppTextStyles.subtitle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                (transaction?.sealNumber?.isNotEmpty ?? false)
                  ? transaction!.sealNumber!
                  : '—',
                  // Use the originPort variable here
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black,
                  ),
                ),
                
              ],
            ),
          ],
        ),
      ],
    );
  }
}

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
