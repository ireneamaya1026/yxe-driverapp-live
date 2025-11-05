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
import 'package:frontend/provider/theme_provider.dart';
import 'package:frontend/provider/transaction_list_notifier.dart';
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/screen/navigation_menu.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/schedule.dart';
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
  late String uid;

  int? _expandedTabIndex;



  List<String> get tabTitles {
    final type = widget.transaction?.dispatchType;
    final title = type == 'dt' ? 'Consignee Info' : 'Shipper Info';
   
      return [title, 'Proof of Delivery'];

      
  }

  @override
  void initState() {
    super.initState();
    uid = widget.uid; // Initialize uid
    _expandedTabIndex = 0; // Default to the first tab
  }

  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback;
  }
  Map<String, MilestoneHistoryModel?> getPickupAndDeliverySchedule(Transaction? transaction) {
    final dispatchType = transaction!.dispatchType;
    final history = transaction.history;
    final serviceType = transaction.serviceType;
    final dispatchId = transaction.id;
    final requestNumber = transaction.requestNumber;

    final fclPrefixes = {
      'ot': {
        'Full Container Load': {
          'de': {
            'delivery': 'TEOT',
            'pickup': 'TYOT'
          },
          'pl': {
            'delivery': 'CLOT',
            'pickup': 'TLOT'
          },
        },
        'Less-Than-Container Load': {
          'pl': {
            'delivery': 'LCLOT',
            'pickup': 'LTEOT'
          },
        },
      },
      'dt': {
        'Full Container Load': {
          'dl': {
            'delivery': 'CLDT',
            'pickup': 'GYDT'
          },
          'pe': {
            'delivery': 'CYDT',
            'pickup': 'GLDT'
          },
        },
        'Less-Than-Container Load': {
          'pl': {
            'delivery': 'LCLOT',
            'pickup': 'LTEOT'
          },
        }
      }
    };

    final fclCodeMap = {
      'de': transaction.deRequestNumber,
      'pl': transaction.plRequestNumber,
      'dl': transaction.dlRequestNumber,
      'pe': transaction.peRequestNumber,
    };

    String? matchingLegs;
    for (final entry in fclCodeMap.entries) {
      if (entry.value !=null && entry.value == requestNumber) {
        matchingLegs = entry.key;
        break;
      }
    }

    print("Matching Leg for $requestNumber: $matchingLegs");

    if(matchingLegs != null) {
      final fclMap = fclPrefixes[dispatchType]?[serviceType]?[matchingLegs];
      final pickupFcl = fclMap?['pickup'];
      final deliveryFcl = fclMap?['delivery'];

      MilestoneHistoryModel? pickupSchedule;
      MilestoneHistoryModel? deliverySchedule;

      if(pickupFcl != null) {
        pickupSchedule = history?.firstWhere(
          (h) => 
            h.fclCode.trim().toUpperCase() == pickupFcl.toUpperCase() &&
            h.dispatchId == dispatchId.toString() &&
            h.serviceType == serviceType,
          orElse: () => const MilestoneHistoryModel(
            id: -1,
            dispatchId: '',
            dispatchType: '',
            fclCode: '',
            scheduledDatetime: '',
            serviceType: '',
            actualDatetime: '', isBackload: ''
          ),
        );
        if(pickupSchedule?.id == -1) pickupSchedule  = null;
      }

      if(deliveryFcl != null) {
        deliverySchedule = history?.firstWhere(
          (h) => 
            h.fclCode.trim().toUpperCase() == deliveryFcl.toUpperCase() &&
            h.dispatchId == dispatchId.toString() &&
            h.serviceType == serviceType,
          orElse: () => const MilestoneHistoryModel(
            id: -1,
            dispatchId: '',
            dispatchType: '',
            fclCode: '',
            scheduledDatetime: '',
            serviceType: '',
            actualDatetime: '', isBackload: ''
          ),
        );
        if(deliverySchedule?.id == -1) deliverySchedule  = null;
      }
      return {
        'pickup': pickupSchedule,
        'delivery': deliverySchedule,
      };
    }
    return {
      'pickup': null,
      'delivery': null,
    };


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
    // 1️⃣ Backloaded message
    final backloadedName = (widget.transaction?.backloadConsolidation?.name.trim().isNotEmpty ?? false)
        ? widget.transaction?.backloadConsolidation?.name
        : 'N/A';
    final backloadedMessage = 'This booking has been backloaded: $backloadedName';
    final transaction = widget.transaction;

    final scheduleMap = getPickupAndDeliverySchedule(transaction);

     final delivery = scheduleMap['delivery'];




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
          if (widget.transaction?.isReassigned == true &&
              (widget.transaction?.reassigned?.isNotEmpty ?? false)) {
            return formatDateTime(widget.transaction!.reassigned!.first.createDate);
          } 
          // ✅ Completed or stage completed
          else if (widget.transaction?.requestStatus == 'Completed' ||
              widget.transaction?.stageId == 'Completed') {
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
          } else if (widget.transaction?.requestStatus == 'Completed' ||
              widget.transaction?.stageId == 'Completed') {
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

    final transaction = widget.transaction;

    // 🔒 Add this guard — it prevents null crashes during screen transition
    if (transaction == null) {
      return const Scaffold(
        body: Center(child: Text('No transaction data available')),
      );
    }

    final isDT = widget.transaction?.dispatchType == 'dt';
    final scheduleMap = getPickupAndDeliverySchedule(transaction);
    final pickup = scheduleMap['pickup'];
    final delivery = scheduleMap['delivery'];
    final isDiverted = widget.transaction?.backloadConsolidation?.isDiverted == "true";
    final divertedBookingNo = isDiverted 
    ? 'Diverted Booking No: ${widget.transaction?.backloadConsolidation?.name ?? '—'}'
    : null;
    final consolStatus = widget.transaction?.backloadConsolidation?.status;


    print('pickup actual datetime: ${pickup?.actualDatetime}');
    print('Dispatch Typr: ${widget.transaction?.dispatchType}');
    print("request Number: ${widget.transaction?.requestNumber}");
    print("Seal Number: ${widget.transaction?.sealNumber}");
    print("Is Diverted: $isDiverted");
    print("'Diverted Booking No: ${widget.transaction?.backloadConsolidation?.name ?? '—'}'");
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
      if (widget.transaction?.requestNumber == widget.transaction?.dlRequestNumber) {
        String tempYardSign = widget.transaction?.plSign ?? '';
        String tempSign = widget.transaction?.dlSign ?? '';
        String tempYardName = widget.transaction?.peReleasedBy ?? '';
        String tempName = widget.transaction?.deReleasedBy ?? '';
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
        
      } else if (widget.transaction?.requestNumber == widget.transaction?.peRequestNumber) {
        String tempYardSign = widget.transaction?.deSign ?? '';
        String tempSign = widget.transaction?.peSign ?? '';
        String tempYardName = widget.transaction?.plReceivedBy ?? '';
        String tempName = widget.transaction?.dlReceivedBy ?? '';
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
        if (widget.transaction?.requestNumber == widget.transaction?.dlRequestNumber) {
          yardSignBase64 = widget.transaction?.peSign;
          signBase64 = widget.transaction?.deSign;
          yardName = widget.transaction?.peReleasedBy;
          name = widget.transaction?.deReleasedBy;
          yardactualdate = formatDateTime(pickup?.actualDatetime);
          actualdate = formatDateTime(delivery?.actualDatetime);
          yardtitle = "Yard/Port";
          title = "Shipper";

        } else if (widget.transaction?.requestNumber == widget.transaction?.plRequestNumber) {
          yardSignBase64 = widget.transaction?.dlSign;
          signBase64 = widget.transaction?.plSign;
          yardName = widget.transaction?.plReceivedBy;
          name = widget.transaction?.dlReceivedBy;
          yardactualdate = formatDateTime(pickup?.actualDatetime);
          actualdate = formatDateTime(delivery?.actualDatetime);
          yardtitle = "Shipper";
          title = "Yard/Port";
        }
      }

    } else {
      // === OT / NON-DT LOGIC (mirrored) ===
      if (widget.transaction?.requestNumber == widget.transaction?.deRequestNumber) {
        String tempYardSign = widget.transaction?.peSign ?? '';
        String tempSign = widget.transaction?.deSign ?? '';
        String tempYardName = widget.transaction?.peReleasedBy ?? '';
        String tempName = widget.transaction?.deReleasedBy ?? '';
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
      } else if (widget.transaction?.requestNumber == widget.transaction?.plRequestNumber) {
        String tempYardSign = widget.transaction?.dlSign ?? '';
        String tempSign = widget.transaction?.plSign ?? '';
        String tempYardName = widget.transaction?.plReceivedBy ?? '';
        String tempName = widget.transaction?.dlReceivedBy ?? '';
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
        yardSignBase64 = widget.transaction?.plSign;
        signBase64 = widget.transaction?.dlSign;
        yardName = widget.transaction?.plReceivedBy;
        name = widget.transaction?.dlReceivedBy;
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

  if (isDT && reqNo == widget.transaction?.dlRequestNumber) {
    // DT + dlRequestNumber:
    // Yard: only plProof
    addFile(yardFiles, widget.transaction?.plProof, widget.transaction?.plProofFilename ?? "POD");

    // Consignee (full pack): plProof + shared( hwbSigned, dlProof, deliveryReceipt, packingList, deliveryNote, stockDelivery, salesInvoice )
    addFile(shipperConsigneeFiles, widget.transaction?.dlProof, widget.transaction?.dlProofFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.hwbSigned, widget.transaction?.hwbSignedFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.deliveryReceipt, widget.transaction?.deliveryReceiptFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.packingList, widget.transaction?.packingListFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.deliveryNote, widget.transaction?.deliveryNoteFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.stockDelivery, widget.transaction?.stockDeliveryFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.salesInvoice, widget.transaction?.salesInvoiceFilename);
  }else  if (isDT && reqNo == widget.transaction?.peRequestNumber) {
    // DT + dlRequestNumber:
    // Yard: only plProof
    addFile(yardFiles, widget.transaction?.peProof, widget.transaction?.peProofFilename ?? "POD");
    addFile(shipperConsigneeFiles, widget.transaction?.deProof, widget.transaction?.deProofFilename ?? "POD");
  } 
  else if (!isDT && reqNo == widget.transaction?.plRequestNumber) {
    // OT + plRequestNumber:
    addFile(shipperConsigneeFiles, widget.transaction?.dlProof, widget.transaction?.dlProofFilename); // yard has dlProof
    addFile(yardFiles, widget.transaction?.plProof, widget.transaction?.plProofFilename); // shipper has plProof
    addFile(yardFiles, widget.transaction?.proofStock, widget.transaction?.proofStockFilename); // shipper has stock transfer
  } else if (!isDT && reqNo == widget.transaction?.deRequestNumber) {
    // Fallback: if nothing matches, attempt to add any non-null generic files so user can still download what's available
   
    addFile(yardFiles, widget.transaction?.peProof, widget.transaction?.peProofFilename);
    addFile(shipperConsigneeFiles, widget.transaction?.deProof, widget.transaction?.deProofFilename);

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
        if(isDiverted && widget.transaction?.deRequestNumber == reqNo  && consolStatus != 'draft') ... [
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

        // SHIPPER CONSIGNEE
        if(isDiverted && widget.transaction?.peRequestNumber == reqNo   && consolStatus != 'draft') ... [
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
            //  isDT ? 'Consignee' : 'Shipper',
            title!,
            style: AppTextStyles.body.copyWith(
              color: mainColor,
              fontWeight: FontWeight.bold, 
            )
          ),
          const SizedBox(height: 20),
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




  Widget  _buildFreightTab(){
    final isDiverted = widget.transaction?.backloadConsolidation?.isDiverted == "true";
    final consolStatus = widget.transaction?.backloadConsolidation?.status;


  

    final divertedPortName = (widget.transaction?.dispatchType == 'dt')
    ? (widget.transaction?.backloadConsolidation?.originName ?? '—')
    : (widget.transaction?.backloadConsolidation?.destinationName ?? '—');

    return  Column( // Use a Column to arrange the widgets vertically
      crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
      children: [
        if(isDiverted && consolStatus == 'consolidated') ... [
      
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
                  (widget.transaction?.origin?.isNotEmpty ?? false)
                  ? widget.transaction!.origin! : '—',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.black,
                  ),
                ),
                
              ],
            ),
          ],
        ),
         ],
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
                  (widget.transaction?.freightForwarderName?.isNotEmpty ?? false)
                  ? widget.transaction!.freightForwarderName! : '—',
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
                  (widget.transaction?.freightBlNumber?.isNotEmpty ?? false)
                  ? widget.transaction!.freightBlNumber! : '—',
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
                  
                (widget.transaction?.containerNumber?.isNotEmpty ?? false)
                  ? widget.transaction!.containerNumber!
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
                (widget.transaction?.sealNumber?.isNotEmpty ?? false)
                  ? widget.transaction!.sealNumber!
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
