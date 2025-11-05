// ignore_for_file: avoid_print, use_build_context_synchronously, unused_import

import 'dart:io';
import 'dart:math';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/notifiers/transaction_notifier.dart';
import 'package:frontend/provider/accepted_transaction.dart' as accepted_transaction;
import 'package:frontend/provider/transaction_provider.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/transaction_details.dart';
import 'package:frontend/util/transaction_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/provider/accepted_transaction.dart';
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
  Future<List<Transaction>>? _futureTransactions;

  @override
  void initState() {
    super.initState();
   
    Future.microtask(() {
      ref.invalidate(filteredItemsProviderForTransactionScreen);
      setState(() {
        _futureTransactions = ref.read(filteredItemsProviderForTransactionScreen.future);
      });
    });
  }

  Future<void> _refreshTransaction() async {
    print("Refreshing transactions");
    try {
      ref.invalidate(bookingProvider);
      final freshFuture = ref.refresh(filteredItemsProviderForTransactionScreen.future);
    setState(() {
      _futureTransactions = freshFuture;
    });
      print("REFRESHED!");
    } catch (e) {
      print('DID NOT REFRESH!');
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

    final asyncTx = ref.watch(filteredItemsProviderForTransactionScreen.future);

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
                  future: asyncTx,
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
                            onTap: () {
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

  Widget _buildDownloadButton(String fileName, Uint8List bytes) {
    return SizedBox(
      child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton.icon(
            onPressed: () async {
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

            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(bytes);

            print('✅ File saved: ${file.path}');
          } catch (e) {
            print('❌ Save failed: $e');
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
