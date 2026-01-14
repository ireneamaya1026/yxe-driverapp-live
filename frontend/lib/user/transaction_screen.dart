// ignore_for_file: avoid_print, use_build_context_synchronously, unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:frontend/models/pod_offline_model.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/notifiers/transaction_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/confirmation.dart';
import 'package:frontend/user/transaction_details.dart';
import 'package:frontend/util/transaction_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/provider/accepted_transaction.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart'; // Import signature package
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';


class TransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  // final TransactionDetails transaction;
  const TransactionScreen({super.key, required this.user});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  String? uid;
  // Future<List<Transaction>>? _futureTransactions;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  List<Transaction>? lastFetchedTransactions;

  

  Future<List<Transaction>> _fetchLoadedTransactions() async {
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      if (lastFetchedTransactions != null &&
          lastFetchedTransactions!.isNotEmpty) {
        return lastFetchedTransactions!;
      }
      
    }

    final transactions =
        await ref.read(filteredItemsProviderForTransactionScreen.future);

    lastFetchedTransactions = transactions;
    return transactions;
  }


  @override
  void initState() {
    super.initState();
   
    Future.microtask(() {
      final authUid = ref.read(authNotifierProvider).uid;
      setState(() {
        uid = authUid; // ✅ store the authenticated UID here
      });

      // ref.invalidate(filteredItemsProviderForTransactionScreen);
      // _futureTransactions = ref.read(filteredItemsProviderForTransactionScreen.future);
    });
    _connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> result) async {
      final connected = !result.contains(ConnectivityResult.none);
      if (!mounted) return;

      setState(() => _hasInternet = connected);

      if (connected) {
        await ref.read(pendingPodUploaderProvider).uploadPendingPods();
        ref.invalidate(filteredItemsProviderForTransactionScreen); // refresh when back online
      }
    });

      // Try upload once on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1)); // small delay so network settles
      if (await hasInternetConnection()) {
        await ref.read(pendingPodUploaderProvider).uploadPendingPods();
        // ref.invalidate(filteredItemsProviderForTransactionScreen); // refresh when back online
      }
    });
  }

  Future<bool> hasInternetConnection() async {
    try {
      final response = await http.get(Uri.parse("https://www.google.com"));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  

  Future<void> _refreshTransaction() async {
    if (await hasInternetConnection()) {
      ref.invalidate(filteredItemsProviderForTransactionScreen);
    }
  }

  String formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A"; // Handle null values
    
    try {
      DateTime dateTime = DateTime.parse(dateString); // Convert string to DateTime
       return DateFormat('MMMM d, yyyy - h:mm a').format(dateTime); // Format date-time
    } catch (e) {
      return "Invalid Date"; // Handle errors gracefully
    }
  } 

  Color getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.orange;
      case 'Ongoing':
        return const Color.fromARGB(255, 253, 246, 20);
      case 'Completed':
      return Colors.green;
      default:
      return Colors.grey;
    }
  }

  double getStatusProgress(String status){
    switch (status) {
      case 'Accepted':
        return 0.33;
      case 'Ongoing':
        return 0.66;
      case 'Completed':
      return 1.0;
      default:
      return 0.0;
    }
  }


  
  
  @override
  Widget build(BuildContext context) {
     
    // final transactionold = ref.watch(filteredItemsProviderForTransactionScreen);
    
    final acceptedTransaction = ref.watch(accepted_transaction.acceptedTransactionProvider);
    

    final asyncTx = _hasInternet
        ? ref.watch(filteredItemsProviderForTransactionScreen.future)
        : null;

     return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header card covering full top area
            SizedBox(
              height: 200, // You can adjust height as needed
              width: double.infinity,
              child: Card(
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/New YXE Drive.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    Positioned(
                      left: 24,
                      top: 26,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery\nTransactions',
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text (
                            'Records of scheduled \ndeliveries',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                            
                            )
                          )
                        ],
                      )
                    ),
                    
                  ],
                ),
              ),
            ),
           
            Expanded (
              child: RefreshIndicator(
                onRefresh: _refreshTransaction,
                child: FutureBuilder<List<Transaction>>(
                  future: _fetchLoadedTransactions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final message = snapshot.error.toString().replaceFirst('Exception: ', '');
                      return RefreshIndicator (
                        onRefresh: _refreshTransaction,
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.all(16),
                              child: Text(
                                message,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.bold
                                ),
                                textAlign: TextAlign.center,
                              )
                            )
                          )
                        )
                      );
                    }
                    final transactionList = snapshot.data ?? [];


                    // If acceptedTransaction is a list, convert it to a Set of IDs for faster lookup
                    final acceptedTransactionIds = acceptedTransaction;

                    // Filtered list excluding transactions with IDs in acceptedTransaction
                    final transaction = transactionList.where((t) {
                      final key = "${t.id}-${t.requestNumber}";
                        return !acceptedTransactionIds.contains(key);
                    }).toList();

                   
                    final authPartnerId = ref.watch(authNotifierProvider).partnerId;
                    final driverId = authPartnerId?.toString();

                   
                    final expandedTransactions = TransactionUtils.expandTransactions(
                      transaction,
                      driverId ?? '',
                    );


                    expandedTransactions.sort((a,b){
                      DateTime dateA = DateTime.tryParse(a.deliveryDate!) ?? DateTime(0);
                      DateTime dateB = DateTime.tryParse(b.deliveryDate!) ?? DateTime(0);
                      return dateB.compareTo(dateA);
                    });
                    

                    final ongoingTransactions = expandedTransactions
                      .where((tx) => tx.requestStatus == "Ongoing")
                      .toList();

                  
                    if (ongoingTransactions.isEmpty) {
                      return LayoutBuilder(
                        builder: (context,constraints){
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(), // Allow scrolling even if the list is empty
                            children: [
                              SizedBox(
                                height: constraints.maxHeight, // Adjust height as needed
                                child: Center(
                                  child: Text(
                                    'No transactions yet.',
                                    style: AppTextStyles.subtitle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      );
                      
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ongoingTransactions.length,
                      itemBuilder: (context, index) {
                        final item = ongoingTransactions[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: darkerBgColor,
                                blurRadius: 6,
                                offset: Offset(0, 3)
                              )
                            ]
                          ),
                            
                          child: InkWell(
                            onTap:  () async {
                              final hasInternet = await hasInternetConnection();
                              if (hasInternet) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TransactionDetails(
                                      transaction: item,
                                      id: item.id,
                                      uid: uid ?? '',
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ConfirmationScreen(
                                      transaction: item,
                                      id: item.id,
                                      uid: uid ?? '', relatedFF: null, requestNumber: null,
                                    ),
                                  ),
                                );
                              }

                              
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Space between label and value
                                          Text(
                                            '${item.origin} - ${item.destination}',
                                            style: AppTextStyles.body.copyWith(
                                              color: mainColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          // Text(
                                          //   formatDateTime(item.arrivalDate),
                                          //   style: AppTextStyles.caption.copyWith(
                                          //     color: darkerBgColor,
                                          //   ),
                                          // ),
                                        ],
                                      ),
                                      ) // Space between icon and text
                                      
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      const SizedBox(width: 20), // Space between icon and text
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Space between label and value
                                          Text(
                                            "Request Number",
                                            style: AppTextStyles.caption.copyWith(
                                              color: darkerBgColor,
                                            ),
                                          ),
                                          Text(
                                            (item.requestNumber?.toString() ?? 'No Request Number Available'),
                                            style: AppTextStyles.body.copyWith(
                                              color: mainColor,
                                              fontWeight: FontWeight.bold,
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
                                              "Truck Number",
                                              style: AppTextStyles.caption.copyWith(
                                                color: darkerBgColor,
                                              ),
                                            ),
                                            Text(
                                              (item.truckPlateNumber?.isNotEmpty ?? false)
                                                ? item.truckPlateNumber! : '—',
                                              style: AppTextStyles.body.copyWith(
                                                color: mainColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 150,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: LinearGradient(
                                            colors: [
                                              getStatusColor(item.requestStatus ?? ''),
                                              Colors.grey,
                                            ],
                                            stops: [
                                              getStatusProgress(item.requestStatus ?? ''),
                                              getStatusProgress(item.requestNumber ?? '')
                                            ],
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Text(
                                          item.requestStatus ?? '',
                                          style: AppTextStyles.caption.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }, 
                  // Remove loading and error named parameters, handle in builder
                ),  
              )
            )
              
          ],
        )
      ) 
    );
    
  }

}
