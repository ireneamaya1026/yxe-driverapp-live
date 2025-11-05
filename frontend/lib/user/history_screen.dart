// ignore_for_file: unused_import, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_custom_clippers/flutter_custom_clippers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/consolidation_model.dart';
import 'package:frontend/models/consolidation_extension.dart';
import 'package:frontend/models/driver_reassignment_model.dart';
import 'package:frontend/models/milestone_history_model.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
import 'package:frontend/provider/reject_provider.dart';
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/history_details.dart';
import 'package:frontend/user/rejection_details.dart';
import 'package:frontend/user/show_all_history.dart';
import 'package:frontend/user/transaction_details.dart';
import 'package:frontend/util/transaction_utils.dart';
import 'package:frontend/views/transaction_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerStatefulWidget{
  final Map<String, dynamic> user;
   final Transaction? transaction;
  const HistoryScreen({super.key, required this.user,  this.transaction});

  @override
  // ignore: library_private_types_in_public_api
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryScreen> {
  String? uid;
 Future<List<Transaction>>? _futureTransactions;
// ------------------- LEG HELPERS -------------------
  String? _getLegForTransaction(Transaction tx) {
    final legRequestMap = {
      'de': tx.deRequestNumber,
      'pl': tx.plRequestNumber,
      'dl': tx.dlRequestNumber,
      'pe': tx.peRequestNumber,
    };
    final entry = legRequestMap.entries.firstWhere(
      (e) => e.value == tx.requestNumber,
      orElse: () => const MapEntry('', null),
    );
    return entry.key.isEmpty ? null : entry.key;
  }

MilestoneHistoryModel? _getLatestMilestoneForLeg(Transaction tx, String leg) {
  if (tx.history == null || tx.history!.isEmpty) return null;

  // Filter history by dispatchId and leg
  final matchingHistory = tx.history!
      .where((h) =>
          h.dispatchId.toString() == tx.id.toString() &&
          h.fclCode.toUpperCase().startsWith(leg.toUpperCase()) && // optional if your FCL codes use leg prefixes
          h.actualDatetime?.isNotEmpty == true)
      .toList();

  if (matchingHistory.isEmpty) {
    // If none match by FCL prefix, fallback to any milestone for this dispatchId
    final fallbackHistory = tx.history!
        .where((h) =>
            h.dispatchId.toString() == tx.id.toString() &&
            h.actualDatetime.isNotEmpty == true)
        .toList();

    if (fallbackHistory.isEmpty) return null;

    fallbackHistory.sort((a, b) {
      final aTime = DateTime.tryParse(a.actualDatetime) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b.actualDatetime) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return fallbackHistory.first;
  }

  // Sort by latest datetime
  matchingHistory.sort((a, b) {
    final aTime = DateTime.tryParse(a.actualDatetime!) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = DateTime.tryParse(b.actualDatetime!) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });

  return matchingHistory.first;
}


Map<String, String> getCompletedTransactionDatetime(Transaction tx) {
  final leg = _getLegForTransaction(tx);
  MilestoneHistoryModel? milestone;

  if (leg != null) {
    milestone = _getLatestMilestoneForLeg(tx, leg);
  }

  String? rawDateTime;

if (tx.requestStatus == 'Completed') {
  rawDateTime = tx.completedTime?.isNotEmpty == true
      ? tx.completedTime
      : milestone?.actualDatetime ?? tx.backloadConsolidation?.consolidatedDatetime ?? tx.writeDate;
} else if (tx.requestStatus == 'Backload') {
  rawDateTime = tx.backloadConsolidation?.consolidatedDatetime?.isNotEmpty == true
      ? tx.backloadConsolidation?.consolidatedDatetime
      : milestone?.actualDatetime ?? tx.completedTime ?? tx.writeDate;
} else if (tx.stageId == 'Cancelled') {
  rawDateTime = tx.writeDate?.isNotEmpty == true
      ? tx.writeDate
      : milestone?.actualDatetime ?? tx.completedTime ?? tx.backloadConsolidation?.consolidatedDatetime;
} else {
  rawDateTime = milestone?.actualDatetime ?? tx.completedTime ?? tx.backloadConsolidation?.consolidatedDatetime ?? tx.writeDate;
}


  return separateDateTime(rawDateTime);
}

  


 @override
void initState() {
  super.initState();
  Future.microtask(() {
    setState(() {
      _futureTransactions = ref.read(filteredItemsProviderForHistoryScreen.future);
    });
  });
}

  Future<void> _refreshTransaction() async {
    print("Refreshing transactions");
    try {
      ref.invalidate(filteredItemsProviderForHistoryScreen);
      setState(() {
        _futureTransactions = ref.read(filteredItemsProviderForHistoryScreen.future);
      });
      print("REFRESHED!");
    } catch (e) {
      print('DID NOT REFRESH!');
    }
  }


  Map< String, String> separateDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) {
      return {"date": "N/A", "time": "N/A"}; // Return default values if null or empty
    }

    try {
      DateTime datetime = DateTime.parse("${dateTime}Z").toLocal();

      return {
        "date": DateFormat('dd MMM , yyyy').format(datetime),
        "time": DateFormat('hh:mm a').format(datetime),
      };
    } catch (e) {
      print("Error parsing date: $e");
      return {"date": "N/A", "time": "N/A"}; // Return default values on error
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color.fromARGB(255, 28, 157, 114);
      case 'Cancelled':
        return  Colors.red;
      case 'Rejected':
        return  Colors.grey;
      default:
      return Colors.grey;
    }
  }

  
  
  @override
  Widget build(BuildContext context) {
     
  
    
    final acceptedTransaction = ref.watch(accepted_transaction.acceptedTransactionProvider);

    

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
             Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical:10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'History',
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
                            builder: (context) => AllHistoryScreen(uid: uid ?? '', transaction: null,),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 3.0),
                child: Divider(
                  color: Colors.grey,
                  thickness: 1,
                ),
              ),


           
            Expanded (
              child: RefreshIndicator(
                onRefresh: _refreshTransaction,
                child: FutureBuilder<List<Transaction>>(
                  future: _futureTransactions,
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
                    final currentDriverName = ref.watch(authNotifierProvider).driverName?.toString() ?? '';
                 
                   
                     //  / Step 1: Expand all normal transactions for this driver
                  final expandedTransactions = TransactionUtils.expandTransactions(
                    transactionList, // your normal transactions list
                    driverId ?? '',
                  );

                  // ✅ STEP 2: Collect ALL reassigned items from every transaction
                  final allReassignments = transactionList
                      .where((t) => t.reassigned != null && t.reassigned!.isNotEmpty)
                      .expand((t) => t.reassigned!)
                      .toList();

                  // ✅ STEP 3: Expand them for the current driver
                  final reassignedTransactions = TransactionUtils.expandReassignments(
                    allReassignments,
                    driverId ?? '',
                    currentDriverName,
                    transactionList, // pass all transactions for parent lookup
                  );


                  // Step 3: Merge normal + reassigned
                  final allTransactions = [
                    ...expandedTransactions,
                    ...reassignedTransactions
                  ];

                  // Deduplicate by ID + request number
                  final dedupedTransactions = <Transaction>[];
                  for (final tx in allTransactions) {
                    if (!dedupedTransactions.any((t) =>
                        t.id == tx.id && t.requestNumber == tx.requestNumber)) {
                      dedupedTransactions.add(tx);
                    }
                  }

                  final recent5Transactions = dedupedTransactions
                    .where((tx) {
                      if (tx.isReassigned == true) return true; // always include reassigned
                      return ['Cancelled', 'Completed'].contains(tx.stageId) ||
                          ['Backload', 'Completed'].contains(tx.requestStatus);
                    })
                    .toList()
                  ..sort((a, b) {
                    DateTime getRecentDate(Transaction t) {
                      final completed = DateTime.tryParse(t.completedTime ?? '');
                      final cancelled = DateTime.tryParse(t.writeDate ?? '');
                      final backload = DateTime.tryParse(t.backloadConsolidation?.consolidatedDatetime ?? '');
                      final reassigned = (t.isReassigned == true && (t.reassigned?.isNotEmpty ?? false))
                          ? DateTime.tryParse(t.reassigned!.first.createDate)
                          : null;

                      // prioritize reassignment first, then completed/backload/cancelled
                      return reassigned ?? completed ?? backload ?? cancelled ?? DateTime.fromMillisecondsSinceEpoch(0);
                    }

                    return getRecentDate(b).compareTo(getRecentDate(a)); // descending (most recent first)
                  });

                final ongoingTransactions = recent5Transactions.take(5).toList();


                   
                   
                    String getStatusLabel(Transaction item, String currentDriverId, String currentDriverName) {
  final status = item.requestStatus?.trim();
  final stage = item.stageId?.trim();

  final isReassigned = item.reassigned?.any(
        (r) =>
            (r.driverId.toString() == currentDriverId ||
                r.driverName.toLowerCase().contains(currentDriverName.toLowerCase())) &&
            r.requestNumber == item.requestNumber,
      ) ??
      false;

  // If completed or cancelled, always show those first
  if (status == 'Completed' || status == 'Backload') return status!;
  if (stage == 'Completed' || stage == 'Cancelled') return stage!;

  // Only show Reassigned if it's not completed/cancelled
  if ((item.isReassigned == true || isReassigned) &&
      status != 'Completed' &&
      stage != 'Completed' &&
      stage != 'Cancelled') {
    return 'Reassigned';
  }

  return '—';
}
                           

             
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
                                    'No history transactions yet.',
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
                      itemCount: ongoingTransactions.length,
                      itemBuilder: (context, index) {
                        final item = ongoingTransactions[index];
                        final statusLabel = getStatusLabel(item, driverId ?? '', currentDriverName);

                          final dateTimeMap = getCompletedTransactionDatetime(item);
                        final displayDate = dateTimeMap['date']!;
                        final displayTime = dateTimeMap['time']!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                         
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => HistoryDetailScreen(
                                    transaction: item,
                                    uid: uid ?? '',
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0); // from right
                                    const end = Offset.zero;
                                    const curve = Curves.ease;

                                    final tween =
                                        Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    final offsetAnimation = animation.drive(tween);

                                    return SlideTransition(
                                      position: offsetAnimation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                    
                                      // Space between label and value
                                      Text(
                                        "Dispatch No.: ",
                                        style: AppTextStyles.caption.copyWith(
                                          color: darkerBgColor,
                                        ),
                                      ),
                                      Text(
                                        item.bookingRefNo ?? '—',
                                        style: AppTextStyles.caption.copyWith(
                                          color: mainColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: getStatusColor((statusLabel).trim()),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                             statusLabel,
                                              style: AppTextStyles.caption.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "Request ID: ",
                                        style: AppTextStyles.caption.copyWith(
                                          color: darkerBgColor,
                                        ),
                                      ),
                                      Text(
                                        (item.requestNumber?.toString() ?? 'No Request Number Available'),
                                        style: AppTextStyles.caption.copyWith(
                                          color: mainColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 150,
                                        ),
                                       
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                             displayDate,
                                              style: AppTextStyles.caption.copyWith(
                                                color: mainColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                    ],
                                  ),
                                 
                                  Row(
                                    children: [
                                      Text(
                                        "View Details →",
                                        style: AppTextStyles.caption.copyWith(
                                          color: mainColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                     
                                     const Spacer(),
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 150,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              displayTime,
                                              style: AppTextStyles.caption.copyWith(
                                                color: mainColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
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




