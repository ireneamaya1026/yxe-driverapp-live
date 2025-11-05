// ignore_for_file: unused_import, avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:frontend/user/confirmation.dart';
import 'package:frontend/user/detailed_details.dart';
import 'package:frontend/widgets/progress_row.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  final String uid;
  final Transaction? transaction;

  const ScheduleScreen({super.key, required this.uid, required this.transaction, required relatedFF});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleState();
}

class _ScheduleState extends ConsumerState<ScheduleScreen> {
  late String uid;
  MilestoneHistoryModel? schedule;

  @override
  void initState() {
    super.initState();
    uid = widget.uid; // Initialize uid
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
            'pickup': 'TLOT',
            'email': 'ELOT'
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
            'pickup': 'GLDT',
            'email': 'EEDT'
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
      final emailFcl = fclMap?['email'];

      MilestoneHistoryModel? pickupSchedule;
      MilestoneHistoryModel? deliverySchedule;
      MilestoneHistoryModel? emailSchedule;

      if(pickupFcl != null) {
        pickupSchedule = history!.firstWhere(
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
            actualDatetime: '',
            serviceType: '', isBackload: '',
           
          ),
        );
        if(pickupSchedule.id == -1) pickupSchedule  = null;
      }

      if(deliveryFcl != null) {
        deliverySchedule = history!.firstWhere(
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
            actualDatetime: '',
            serviceType: '', isBackload: '',
            
          ),
        );
        if(deliverySchedule.id == -1) deliverySchedule  = null;
      }

      if(emailFcl != null) {
        emailSchedule = history!.firstWhere(
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
      return {
        'pickup': pickupSchedule,
        'delivery': deliverySchedule,
        'email' : emailSchedule
      };
    }
    return {
      'pickup': null,
      'delivery': null,
      'email': null
    };
  }

  bool _isLoading = false;


  Future<void> _sendEmail() async {

     setState(() => _isLoading = true);
    final now = DateTime.now();
    final adjustedTime = now.subtract(const Duration(hours: 8));
    final timestamp = DateFormat("yyyy-MM-dd HH:mm:ss").format(adjustedTime);

    final baseUrl = ref.watch(baseUrlProvider);
    var uid = ref.read(authNotifierProvider).uid; // 👈 Grab UID from login response
  
    Uri url;
 
    url = Uri.parse('$baseUrl/api/odoo/notify?uid=$uid');

    var response = await http.post(url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'password': ref.read(authNotifierProvider).password ?? '',
        'login':ref.watch(authNotifierProvider).login ?? ''
      },
      body: jsonEncode({
        'id': widget.transaction?.id,
        'uid': uid,
        'dispatch_type': widget.transaction?.dispatchType,
        'request_number': widget.transaction?.requestNumber,
        'timestamp': timestamp,
      }),
    );
    print("Response status code: ${response.statusCode}");
    
  
    if (!mounted) return;
    if (response.statusCode == 200) {
    final scheduleMap = getPickupAndDeliverySchedule(widget.transaction!);
    final emailModel = scheduleMap['email'];

    if (emailModel != null && widget.transaction?.history != null) {
      final history = widget.transaction!.history!;
      final index = history.indexWhere((h) => h.id == emailModel.id);

      if (index != -1) {
        // ✅ Replace the milestone with a new one that includes actualDatetime
        final old = history[index];
        final updated = MilestoneHistoryModel(
          id: old.id,
          dispatchId: old.dispatchId,
          dispatchType: old.dispatchType,
          fclCode: old.fclCode,
          scheduledDatetime: old.scheduledDatetime,
          actualDatetime: timestamp, // ✅ new value here
          serviceType: old.serviceType,
          isBackload: old.isBackload,
        );

        setState(() {
          history[index] = updated; // ✅ replace old model
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }

    showSuccessDialog(context, "Email Sent!");
  } else {
    setState(() => _isLoading = false);
    showSuccessDialog(context, "Failed to send email!");
    print("❌ Failed to send email: ${response.statusCode}");
  }
    
  }

  

  Map< String, String> separateDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) {
      return {"date": "N/A", "time": "N/A"}; // Return default values if null or empty
    }

    try {
      DateTime datetime = DateTime.parse("${dateTime}Z").toLocal();

      return {
        "date": DateFormat(' MMMM dd, yyyy').format(datetime),
        "time": DateFormat('hh:mm a').format(datetime),
      };
    } catch (e) {
      print("Error parsing date: $e");
      return {"date": "N/A", "time": "N/A"}; // Return default values on error
    }
  }
    
  
  @override
  Widget build(BuildContext context) {
   final scheduleMap = getPickupAndDeliverySchedule(widget.transaction!);
  final pickup = scheduleMap['pickup'];
  final delivery = scheduleMap['delivery'];
  final email = scheduleMap['email'];

  
  bool isAlreadyNotified = email?.actualDatetime != null ;
  final hasActualDatetime = email?.actualDatetime != null &&
    email!.actualDatetime!.trim().isNotEmpty;

  int currentStep = 2; // Assuming Schedule is step 2 (0-based index)
  final bookingNumber = widget.transaction?.bookingRefNumber;

    final allTransactions = ref.watch(transactionListProvider);
    print("Schedule All Transaction: $allTransactions");

    // for (var tx in allTransactions) {
    //   print("🔍 TX → bookingRefNumber: '${tx.bookingRefNumber}', dispatchType: '${tx.dispatchType}'");
    // }

    final relatedFF = allTransactions.cast<Transaction?>().firstWhere(
        (tx) {
          final refNum = tx?.bookingRefNumber?.trim();
          final currentRef = bookingNumber?.trim();
          final dispatch = tx?.dispatchType!.toLowerCase().trim();

          return refNum != null &&
                refNum == currentRef &&
                dispatch == 'ff'; // ✅ specifically look for FF
        },
        orElse: () => null,
      );
   

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: mainColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  getNullableValue(widget.transaction?.name).toUpperCase(),
                  style:AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ProgressRow(currentStep: currentStep, uid: uid, transaction: widget.transaction,relatedFF: relatedFF,), // Pass an integer value for currentStep
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8.0), // Add padding inside the container
                
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.asset(
                    'assets/Freight Forwarding.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Pickup and Delivery Schedule", // Section Title
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(255, 128, 137, 145),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0), // Add padding inside the container
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20.0), // Rounded edges
                ),
                child: Column(
                  children:[
                   
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: mainColor,
                            size: 20,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children:[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                    "Pick Up Schedule: ",
                                      // Use the originPort variable here
                                      style: AppTextStyles.caption.copyWith(
                                        color: mainColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5), // Space between label and value
                                    Text(
                                      "Pick up Time: ",
                                      style: AppTextStyles.caption.copyWith(
                                        color: mainColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      separateDateTime(pickup?.scheduledDatetime)["date"] ?? "N/A",
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: mainColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5), // Space between label and value
                                      Text(
                                        separateDateTime(pickup?.scheduledDatetime)["time"] ?? "N/A",
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: mainColor,
                                        ),
                                      )
                                  ],
                                )
                              ]
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: mainColor,
                            size: 20,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children:[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                    "Delivery Schedule: ",
                                      // Use the originPort variable here
                                      style: AppTextStyles.caption.copyWith(
                                        color: mainColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5), // Space between label and value
                                    Text(
                                      "Delivery Time: ",
                                      style: AppTextStyles.caption.copyWith(
                                        color: mainColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      separateDateTime(delivery?.scheduledDatetime)["date"] ?? "N/A",
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: mainColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5), // Space between label and value
                                    Text(
                                      separateDateTime(delivery?.scheduledDatetime)["time"] ?? "N/A",
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: mainColor,
                                      ),
                                    )
                                  ],
                                )
                              ]
                            ),
                          )
                        ],
                      ),
                  ]
                ),
                
              ),
              const SizedBox(height: 20),
              if(widget.transaction?.plRequestNumber == widget.transaction?.requestNumber || widget.transaction?.peRequestStatus == widget.transaction?.requestNumber)

              Text (
                "Optional",
                style: AppTextStyles.caption.copyWith(
                  fontStyle: FontStyle.italic,
                  color: darkerBgColor,
                ),
              ),
              
              if(widget.transaction?.plRequestNumber == widget.transaction?.requestNumber|| widget.transaction?.peRequestNumber == widget.transaction?.requestNumber)...[
              Column (
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: (hasActualDatetime || _isLoading) ? null : _sendEmail,
  style: ElevatedButton.styleFrom(
    backgroundColor: (hasActualDatetime || _isLoading)
        ? Colors.grey
        : mainColor,
  ),
                      child:  _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                      : Row (
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8), // Space between icon and text
                          Text(
                            widget.transaction?.dispatchType == 'ot' ? "Notify Shipper" : "Notify Consignee",
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ]
                      )
                      
                    ),
                  )
                ],
              ), 
              ],
              const SizedBox(height: 10),

              // Text (
              //   "Note: Schedule is subject to change based on unforeseen circumstances. Please stay updated through your notifications.",
              //   style: AppTextStyles.caption.copyWith(
              //     fontStyle: FontStyle.italic,
              //     color: const Color.fromARGB(255, 128, 137, 145),
              //   ),
              // )
            ],
          ),
          
        ),
        
      ),
      bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column (
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        
                        print("uid: ${widget.uid}");
                    
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConfirmationScreen(uid: widget.uid, transaction: widget.transaction, relatedFF: relatedFF,),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        "Next",
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                ],
              )
              
            ),
            const NavigationMenu(),
          ],
          
        )
      // bottomNavigationBar: const NavigationMenu(),
    );
  }

  void showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: mainColor,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                              color: Colors.black87
                            ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("OK", style: AppTextStyles.body.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                );
              }
            )
          );
     
  }
}
