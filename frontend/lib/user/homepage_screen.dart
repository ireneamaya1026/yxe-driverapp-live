
// ignore_for_file: unused_import, deprecated_member_use, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/pod_offline_model.dart';
import 'package:frontend/models/reject_reason_model.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
import 'package:frontend/provider/transaction_list_notifier.dart' as transaction_list;
import 'package:frontend/provider/transaction_list_notifier.dart';
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/provider/reject_provider.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/confirmation.dart';
import 'package:frontend/user/show_all_booking.dart';
import 'package:frontend/util/transaction_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/user/transaction_details.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';


class HomepageScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final int initialIndex;

  const HomepageScreen({this.initialIndex = 0, super.key, required this.user});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends ConsumerState<HomepageScreen> {
  String? uid;


  //  final Map<String, bool> _loadingStates = {};
  Future<void> _refreshTransaction() async {
    print("Refreshing transactions");
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      print("No internet connection. Cannot refresh.");
      return;
    }
    try {
      final future = ref.refresh(filteredItemsProvider.future);
      await future; // Wait for the future to complete
      print("REFRESHED!");
    }catch (e){
      print('DID NOT REFRESHED!');
    }
   }

   late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

   Future<bool> hasInternetConnection() async {
    try {
      final response = await http.get(Uri.parse("https://www.google.com"));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  
  List<Transaction>? lastFetchedTransactions;

  Future<void> _fetchLoadedTransactions() async {
  final hasInternet = await hasInternetConnection();
  if (!hasInternet) return; // do nothing if offline

  try {
    final transactions = await ref.read(filteredItemsProvider.future);
    if (!mounted) return;
    setState(() {
      lastFetchedTransactions = transactions;
    });
  } catch (e) {
    print("Error fetching transactions: $e");
    // fallback to previous data
    setState(() {
      lastFetchedTransactions = lastFetchedTransactions ?? [];
    });
  }
}
  


  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      
      await _fetchLoadedTransactions(); // if async
    });
    _connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> result) async {
        if (!result.contains(ConnectivityResult.none)) {
          print("Internet is back! Uploading pending PODs...");
          await ref.read(pendingPodUploaderProvider).uploadPendingPods() ;
        }
      });

      // Try upload once on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1)); // small delay so network settles
      if (await hasInternetConnection()) {
        await ref.read(pendingPodUploaderProvider).uploadPendingPods() ;
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }


   final List<Map<String, String>> carouselItems = [
    {
      "title": "Start Driving Smarter Today.",
      "subtitle": "From Booking to Delivery — Seamless",
      "image": "assets/hand-drawn-transportation-truck-with-delivery-man.png",
      "color": "#FBC926"
    },
    {
      "title": "More Cargo. More Miles.More Pay.",
      "subtitle": "Book shipments. Accept jobs. Drive your way",
      "image": "assets/illustrated-transport-truck-delivery-side-view-front-view-red-color-delivery-truck.png",
      "color": "#2D906F"
    },
    {
      "title": "Loads at your fingertips.",
      "subtitle": "Browse, accept, and deliver — all in one app",
      "image": "assets/box-truck-with-delivery-man-standing-it-vector-illustration.png",
      "color": "#FBC926"
    },
    {
      "title": "All your Drivers need. In One App.",
      "subtitle": "Booking, tracking, payments, and support.",
      "image": "assets/delivery-truck-boxes-with-isometric-style.png",
      "color": "#2D906F"
    },
  ];

  String formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A"; // Handle null values
    
    try {
      DateTime dateTime = DateTime.parse("${dateString}Z").toLocal();// Convert string to DateTime
      return DateFormat('d MMMM, yyyy').format(dateTime); // Format date-time
    } catch (e) {
      return "Invalid Date"; // Handle errors gracefully
    }
  } 
  
  
  
  @override
  Widget build(BuildContext context) {
     
    final transactionold = ref.watch(filteredItemsProvider);
    
    final acceptedTransaction = ref.watch(accepted_transaction.acceptedTransactionProvider);
    final uid = ref.read(authNotifierProvider).uid;
    // print("Desc: ${item.originAddress}"); // 'item' is undefined here, so this line is removed
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CarouselSlider(
                items: carouselItems.map((item) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Color(int.parse(item['color']!.replaceFirst('#', '0xff'))),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          // 📝 Text column — don't constrain title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item['title']!,
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Flexible(
                                  child: Text(
                                    item['subtitle']!,
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 70,
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                              image: AssetImage(item['image']!),
                              fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                options: CarouselOptions(
                  height: 150,
                  enlargeCenterPage: true,
                  autoPlay: true,
                  viewportFraction: 0.95,
                  autoPlayInterval: const Duration(seconds: 4),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical:10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bookings',
                      style:AppTextStyles.title.copyWith(
                        color: mainColor,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllBookingScreen(uid: uid ?? '', transaction: null,),
                          ),
                        );
                      },
                      child: Text (
                        "Show All",
                        style:AppTextStyles.body.copyWith(
                          color: mainColor,
                          fontWeight: FontWeight.bold
                        ),
                      )
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: RefreshIndicator (
                  onRefresh: _refreshTransaction,
                  child: transactionold.when(
                    data: (transactionList) {
                      // If transactionList is null, we ensure it's an empty list to prevent errors
                      if (transactionList.isNotEmpty) {
                        for (var transaction in transactionList) {
                          print("Booking ID: ${transaction.id}");
                        }
                      } else {
                        print("No transactions found.");
                      }
                      final validTransactionList = transactionList;

                      // If there are no transactions, show a message
                      if (validTransactionList.isEmpty) {
                        return CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(), // Allow scrolling even if the list is empty
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  'No transactions for the next two days.',
                                  style: AppTextStyles.subtitle,
                                  textAlign: TextAlign.center,
                                ),
                                
                              ),
                            )
                          ]
                          
                        );
                      }

                      // If acceptedTransaction is a list, convert it to a Set of IDs for faster lookup
                      final acceptedTransactionIds = acceptedTransaction;

                      // Filtered list excluding transactions with IDs in acceptedTransaction
                      final transaction = validTransactionList.where((t) {
                        final key = "${t.id}-${t.requestNumber}";
                          return !acceptedTransactionIds.contains(key);
                      }).toList();

                        // If no filtered transactions, show a message
                      if (transaction.isEmpty) {
                        return const Center(child: Text('No transactions available that have not been accepted.'));
                      }
                      final authPartnerId = ref.watch(authNotifierProvider).partnerId;
                      final driverId = authPartnerId?.toString();
                      
                      final expandedTransactions = TransactionUtils.expandTransactions(
                        transaction,
                        driverId ?? '',
                      );

                      expandedTransactions.sort((a,b){
                        DateTime dateA = DateTime.tryParse(a.assignedDate ?? '') ?? DateTime(0);
                        DateTime dateB = DateTime.tryParse(b.assignedDate ?? '') ?? DateTime(0);
                        return dateB.compareTo(dateA);
                      });

                      // final ongoingTransactions = expandedTransactions
                      //   .where((tx) => tx.requestStatus == "Accepted" || tx.requestStatus == "Assigned" || tx.requestStatus == "Pending")
                      //   .take(10)
                      //   .toList();

                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final tomorrow = today.add(const Duration(days: 1));

                      final ongoingTransactions = expandedTransactions
                          .where((tx) {
                            // final statusOk = tx.requestStatus == "Accepted" || tx.requestStatus == "Assigned" || tx.requestStatus == "Pending";
                            final notCancelled = tx.stageId != "Cancelled";
                            // Get the relevant date depending on dispatch type
                            String? dateStr;
                            
                            if (tx.dispatchType == "ot") {
                              if (tx.requestStatus == "Accepted" || tx.requestStatus == "Assigned" || tx.requestStatus == "Pending"){
                                dateStr = tx.pickupDate;
                              }
                            } else if (tx.dispatchType == "dt") {
                              if (tx.requestStatus == "Accepted" || tx.requestStatus == "Assigned" || tx.requestStatus == "Pending"){
                                dateStr = tx.deliveryDate;
                              }
                            }

                            if (dateStr == null || dateStr.isEmpty) return false;

                            final date = DateTime.tryParse(dateStr);
                            if (date == null) return false;

                            final dateOnly = DateTime(date.year, date.month, date.day);

                            return notCancelled && (dateOnly == today || dateOnly == tomorrow);
                          })
                          .take(5)
                          .toList();
                     
                      
                      return CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (ongoingTransactions.isEmpty) 
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No transactions for the next two days.',
                                style: AppTextStyles.subtitle,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                          else
                          
                          
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = ongoingTransactions[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
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
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(15),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: mainColor,
                                                spreadRadius: 2,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text (
                                                          item.name!,
                                                          style: AppTextStyles.body.copyWith(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.9,
                                                            color: Colors.white,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 2,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              "Bkg Ref. No.: ",
                                                              style: AppTextStyles.caption.copyWith(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                               (item.freightBookingNumber?.toString() ?? 'N/A'),
                                                                style: AppTextStyles.caption.copyWith(
                                                                  color: Colors.white
                                                                ),
                                                                softWrap: true, // Text will wrap if it's too long
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                       
                                                        Row(
                                                          children: [
                                                            Text(
                                                              "Request No.: ",
                                                              style: AppTextStyles.caption.copyWith(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                                (item.requestNumber?.toString() ?? 'No Request Number Available'),
                                                                style: AppTextStyles.caption.copyWith(
                                                                  color: Colors.white
                                                                ),
                                                                softWrap: true, // Text will wrap if it's too long
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              "Date Assigned: ",
                                                              style: AppTextStyles.caption.copyWith(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                                color: Colors.white,
                                                              ),
                                                              
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                                formatDateTime(item.assignedDate),
                                                                style: AppTextStyles.caption.copyWith(
                                                                  color: Colors.white
                                                                ),
                                                                softWrap: true, // Text will wrap if it's too long
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    color: Color.fromARGB(255, 255, 255, 255),
                                                    size: 40,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    ),
                                  ),
                                );
                              },
                              childCount: ongoingTransactions.length,
                            ),
                          ),
                        ],
                      );
                    }, 
                    loading: () => const Center(child: CircularProgressIndicator()),  // Show loading spinner while fetching data
                    error: (err, stack) => RefreshIndicator (
                      onRefresh: _refreshTransaction,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.all(16),
                            child: Text(
                              err is Exception
                              ? err.toString().replaceFirst('Exception: ', '')
                              : err.toString(),
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold
                              ),
                              textAlign: TextAlign.center,
                            )
                          )
                        )
                      )
                    )
                     // Display error message if an error occur
                  ),
                )
              )
            ],
          )
          
        ),
      ),
    );
  }
}


