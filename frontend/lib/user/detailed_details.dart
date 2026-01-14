// ignore_for_file: unused_import, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:frontend/user/schedule.dart';
import 'package:frontend/widgets/progress_row.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

class DetailedDetailScreen extends ConsumerStatefulWidget {
  final String uid;
  final Transaction? transaction;
  final Transaction? relatedFF;

  const DetailedDetailScreen({
    super.key,
    required this.uid,
    required this.transaction,
    required this.relatedFF,
  });

  @override
  ConsumerState<DetailedDetailScreen> createState() =>
      _DetailedDetailState();
}

class _DetailedDetailState extends ConsumerState<DetailedDetailScreen> {
  late String uid;

  String? prerequisiteMsg;
  bool prerequisitesChecked = false;

  @override
  void initState() {
    super.initState();
    uid = widget.uid;

    Future.microtask(() async {
      await _fetchTransactionTransactions();
      _evaluatePrerequisites(); // 👈 compute once after load
    });
  }

  Future<void> _fetchTransactionTransactions() async {
    if (widget.transaction?.id == null) return;

    print("Fetching merged transactions for transaction ID: ${widget.transaction!.id}");

    try {
      final baseUrl = ref.read(baseUrlProvider);
      final url = Uri.parse(
          '$baseUrl/api/odoo/booking/transaction_details/${widget.transaction!.id}?uid=${widget.uid}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'password': ref.read(authNotifierProvider).password ?? '',
          'login': ref.read(authNotifierProvider).login ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data']['transactions'];
        final transactions = data
            .map<Transaction>((t) => Transaction.fromJson(t))
            .where((tx) =>
                tx.bookingRefNumber != null && tx.dispatchType != null)
            .toList();

        ref.read(transactionListProvider.notifier).loadTransactions(transactions);

        // update FFs
        for (var tx in transactions) {
          if (tx.dispatchType == 'ff') {
            ref.read(completedFFsProvider.notifier).updateFF(tx);
          }
        }

        print("Transactions loaded:");
        for (var tx in transactions) {
          print("${tx.dispatchType} | ${tx.bookingRefNumber} | ${tx.stageId}");
        }
      } else {
        print("Failed to fetch transactions: ${response.statusCode}");
      }
    } catch (e, st) {
      print("Error fetching transactions: $e\n$st");
    }
  }

  /// -------------------------------------------------
  /// 📌 Evaluate prerequisites ONCE (fixes disappearing)
  /// -------------------------------------------------
  void _evaluatePrerequisites() {
    final transaction = widget.transaction;
    if (transaction == null) return;

    final bookingNumber = transaction.bookingRefNumber;
    final requestNumber = transaction.requestNumber;

    final relatedFF =
        ref.read(relatedFFProvider(bookingNumber ?? ''));

    prerequisiteMsg = checkPrerequisites(
      transaction,
      requestNumber!,
      relatedFF,
    );

    setState(() {
      prerequisitesChecked = true;
    });
  }

  /// -------------------------------------------------
  /// 📌 Prerequisite check logic
  /// -------------------------------------------------
  String? checkPrerequisites(
      Transaction transaction, String requestNumber, Transaction? relatedFF) {
    print("Related FF inside prerequisites: ${relatedFF?.stageId}");
    print("Land Transport: ${transaction.landTransport}");

    if (transaction.landTransport != "transport" &&
        requestNumber == transaction.plRequestNumber &&
        transaction.deRequestStatus != "Completed" &&
        transaction.deRequestStatus != "Backload") {
      return "Delivery Empty should be completed first.";
    }

    if (requestNumber == transaction.dlRequestNumber) {
      if (relatedFF == null || relatedFF.stageId != "Completed") {
        return "Associated Freight Forwarding should be completed first.";
      }
    }

    if (transaction.landTransport != "transport" &&
        transaction.freightForwarderName!.isEmpty) {
      return "Associated Freight Forwarding Vendor has not yet been assigned.";
    }
    
    if (requestNumber == transaction.peRequestNumber &&
        transaction.dlRequestStatus != "Completed") {
      return "Delivery Laden should be completed first.";
    }

    

    return null;
  }

  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    if (transaction == null) return const SizedBox.shrink();

    int currentStep = 1;
    final bookingNumber = transaction.bookingRefNumber;
    final allTransactions = ref.watch(transactionListProvider);
    final isLoaded =  allTransactions.any((tx) => tx.bookingRefNumber == bookingNumber);
    final relatedFF = ref.watch(relatedFFProvider(bookingNumber ?? ''));
     bool hideForOngoing =  (widget.transaction?.requestNumber == transaction.peRequestNumber &&
     (transaction.dlRequestStatus == "Ongoing" || relatedFF?.stageId == "Completed"));
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.invalidate(pendingTransactionProvider);
          ref.invalidate(acceptedTransactionProvider);
          ref.invalidate(bookingProvider);
          ref.invalidate(filteredItemsProvider);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: mainColor),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.invalidate(pendingTransactionProvider);
              ref.invalidate(acceptedTransactionProvider);
              ref.invalidate(bookingProvider);
              ref.invalidate(filteredItemsProvider);
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    getNullableValue(transaction.name).toUpperCase(),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ProgressRow(
                  currentStep: currentStep,
                  uid: uid,
                  transaction: transaction,
                  relatedFF: relatedFF,
                ),

                const SizedBox(height: 10),

                /// ---------------------------------------------------------
                /// 📌 SHOW MESSAGE ONLY AFTER FINAL EVALUATION (NO FLICKER)
                /// ---------------------------------------------------------
                /// 
                
                if (prerequisitesChecked && prerequisiteMsg != null && !hideForOngoing && transaction.dispatchType == "dt")
                  Container(
                     padding: const EdgeInsets.all(8.0),
                      color: Colors.yellow.shade100, // <-- background color here
                    child: Text(
                      "This action requires the container to arrive at the discharge port.",
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: const Color.fromARGB(255, 218, 161, 3),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16.0), // Add padding inside the container
                  
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20.0), // Rounded edges
                  ),
                  
                  child: Column( // Use a Column to arrange the widgets vertically
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                                widget.transaction?.requestNumber ?? 'N/A',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                "Request Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Expanded (
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Space between label and value
                               Text(
                  (widget.transaction != null) 
                  ? (() {
                    final isOT = widget.transaction!.dispatchType == "ot";
                    final rawValue = isOT ? widget.transaction!.rawOrigin : widget.transaction!.rawDestination;

                    if (rawValue == null || rawValue.isEmpty) return '—';
                    return rawValue.toUpperCase();
                  }) () : '—',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                                Text(
                                  "Port of Origin",
                                  style: AppTextStyles.caption.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                          
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Space between label and value
                                Text(
                                (widget.transaction?.freightForwarderName?.isNotEmpty ?? false)
                                ? widget.transaction!.freightForwarderName!.toUpperCase() : '—',
                                  // Use the originPort variable here
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                                Text(
                                  "Service Provider",
                                  style: AppTextStyles.caption.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                          
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Expanded(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                (widget.transaction?.contactPerson?.isNotEmpty ?? false)
                                ? widget.transaction!.contactPerson! : '—',
                                style: AppTextStyles.subtitle.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                                Text(
                                  "Contact Person",
                                  style: AppTextStyles.caption.copyWith(
                                    color: mainColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                              (widget.transaction?.contactNumber?.isNotEmpty ?? false)
                              ? widget.transaction!.contactNumber! : '—',
                                // Use the originPort variable here
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                "Contact Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ), // ⬅️ Added progress indicator above content
                Container(
                  // color: Colors.green[500], // Set background color for this section
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Freight and Container Info", // Section Title
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
              
                  child: Column( // Use a Column to arrange the widgets vertically
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                                (widget.transaction?.freightBookingNumber?.isNotEmpty ?? false)
                                ? widget.transaction!.freightBookingNumber! : '—',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                "Freight Booking Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                                (widget.transaction?.freightBlNumber?.isNotEmpty ?? false)
                                ? widget.transaction!.freightBlNumber! : '—',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                "Bill of Lading Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                              (widget.transaction?.containerNumber?.isNotEmpty ?? false)
                              ? widget.transaction!.containerNumber! : '—',
                                // Use the originPort variable here
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                "Container Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.circle_rounded,
                            color: mainColor,
                            size: 15,
                          ),
                          const SizedBox(width: 20), // Space between icon and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Space between label and value
                              Text(
                              (widget.transaction?.sealNumber?.isNotEmpty ?? false)
                                ? widget.transaction!.sealNumber!
                                : '—',
                                // Use the originPort variable here
                                style: AppTextStyles.subtitle.copyWith(
                                  color: mainColor,
                                ),
                              ),
                              Text(
                                "Container Seal Number",
                                style: AppTextStyles.caption.copyWith(
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
        ),
        
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // if(!showButton)
            
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column (
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoaded ? () {
                        // Example: Replace this with your real prerequisite check
                        String? errorMessage;
                        if (widget.transaction != null) {
                          errorMessage = checkPrerequisites(
                            widget.transaction!,
                            widget.transaction!.requestNumber ?? '', 
                            relatedFF// <- pass whichever request they’re on, fallback to empty string if null
                          );
                        };


                        if (errorMessage != null) {
                          // Show modal with message
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(
                                  "Invalid Action!",
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                content: Text(
                                  errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.black87
                                  ),
                                ),
                                actions: [
                                  Center(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: mainColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("OK", style: AppTextStyles.body.copyWith(color: Colors.white)),
                                    )
                                  )
                                  
                                ],
                              );
                            },
                          );
                        } else {
                          // If everything is okay -> go to ScheduleScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScheduleScreen(
                                uid: widget.uid,
                                transaction: widget.transaction, relatedFF: relatedFF,
                              ),
                            ),
                          );
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Next",
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(width: 8),
                          if(!isLoaded)...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ]
                        ],
                      )
                      
                    ),
                  ),
                ],
              )
              
            ),
            const NavigationMenu(),
          ],
          
        )
         
        // bottomNavigationBar: const NavigationMenu(),
      )
    );
   
  }
  

 
}
