// ignore_for_file: unused_import, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
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

  const DetailedDetailScreen({super.key, required this.uid, required this.transaction, required relatedFF});

  @override
  ConsumerState<DetailedDetailScreen> createState() => _DetailedDetailState();
}

class _DetailedDetailState extends ConsumerState<DetailedDetailScreen> {
  late String uid;

  @override
  void initState() {
    super.initState();
    uid = widget.uid; // Initialize uid

    Future.microtask(() async {
      await ref.refresh(combinedTransactionProvider.future);
    });

  }

  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback;
  }

  
  @override
  Widget build(BuildContext context) {
  
    final transaction = widget.transaction;
    final bookingNumber = transaction?.bookingRefNumber;
    int currentStep = 1; // Assuming Detailed Details is step 1 (0-based index)

    final allTransactions = ref.watch(transactionListProvider);
    print("All Transaction: $allTransactions");

    // for (var tx in allTransactions) {
    //   print("🔍 TX → bookingRefNumber: '${tx.bookingRefNumber}', dispatchType: '${tx.dispatchType}'");
    // }

    final relatedFF = ref.watch(relatedFFProvider(bookingNumber ?? ''));
   

    String? checkPrerequisites(Transaction transaction, String requestNumber) {
      print("Related FF: ${relatedFF?.stageId}");
      


      if (requestNumber == transaction.plRequestNumber &&
          transaction.deRequestStatus != "Completed" &&  transaction.deRequestStatus != "Backload") {
        return "Delivery Empty should be completed first.";
      }

      // if (requestNumber == transaction.dlRequestNumber) {
      //   if (relatedFF == null || relatedFF.stageId != "Completed") {
      //     return "Associated Freight Forwarding should be completed first.";
      //   }
      // }

      if(transaction.freightForwarderName!.isEmpty) {
        return "Associated Freight Forwarding Vendor has not yet been assigned.";
      }

      // if (requestNumber == transaction.deRequestNumber) {
      //   if (relatedFF == null || relatedFF.stageId?.trim() != "Vendor Accepted") {
      //     return "Associated Freight Forwarding Vendor has not yet been assigned.";
      //   }
      // }
    
      if (requestNumber == transaction.peRequestNumber &&
          transaction.dlRequestStatus != "Completed") {
        return "Delivery Laden should be completed first.";
      }

      return null; // ✅ All good
    }


        
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if(didPop) {
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
                    getNullableValue(widget.transaction?.name).toUpperCase(),
                    style:AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ProgressRow(currentStep: currentStep, uid: uid, transaction: transaction, relatedFF: relatedFF,),
                const SizedBox(height: 20),
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
                                // (widget.transaction?.originAddress.isNotEmpty ?? false)
                                // ? widget.transaction!.originAddress.toUpperCase() : '—',
                                (widget.transaction?.origin!.isNotEmpty ?? false)
                                ? widget.transaction!.origin!.toUpperCase() : '—',
                                  // Use the originPort variable here
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
                      onPressed: () {
                        // Example: Replace this with your real prerequisite check
                        String? errorMessage;
                        if (widget.transaction != null) {
                          errorMessage = checkPrerequisites(
                            widget.transaction!,
                            widget.transaction!.requestNumber ?? '', // <- pass whichever request they’re on, fallback to empty string if null
                          );
                        } else {
                          errorMessage = "Transaction data is missing.";
                        }


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
