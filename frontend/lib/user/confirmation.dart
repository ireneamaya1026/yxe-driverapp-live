// ignore_for_file: unused_import, avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:frontend/user/proof_of_delivery_screen.dart';
import 'package:frontend/widgets/progress_row.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  final String uid;
  final Transaction? transaction;

  const ConfirmationScreen({super.key, required this.uid, required this.transaction, required relatedFF, required requestNumber, required int id});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationState();
}

class _ConfirmationState extends ConsumerState<ConfirmationScreen> {
  String? uid;
  Transaction? transaction;
 
 late List<List<UploadImage>> _imageLists;

 late List<String> limit;

 final List<String> labels = [
  'Transfer of Liability Form',
  'HWB—Signed',
  'Delivery Receipt',
  'Packing List',
  'Delivery Note',
  'Stock Delivery Receipt',
  'Sales Invoice',
  'Stock Transfer',
  'POD'
 ];

List<String> getUploadLimit(){
  final requestNumber = widget.transaction?.requestNumber ?? '';
  
  if(widget.transaction?.dlRequestNumber == requestNumber && widget.transaction?.dlRequestStatus == "Ongoing") {
    print('dl_requestNumber: ${widget.transaction?.dlRequestNumber}');
    return [
      labels[0],
      labels[1],
      labels[2],
      labels[3],
      labels[4],
      labels[5],
      labels[6],

    ];
  } else if (widget.transaction?.plRequestNumber == requestNumber && widget.transaction?.plRequestStatus == "Assigned"){
    print('plRequestNumber: ${widget.transaction?.plRequestNumber}');
    return [
      labels[6],
      labels[7],

    ];
  } else {
    print('RequestNumber for upload: ${widget.transaction?.requestNumber}');
    return [labels.last];
    
  }
 }

  Future<void> _pickImage(int index) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final List<XFile> pickedFile = await picker.pickMultiImage();
                  if (mounted && pickedFile.isNotEmpty) {
                  final validFiles = <UploadImage>[];

                  for (final xfile in pickedFile) {
                    final file = File(xfile.path);
                    final sizeInMB = (await file.length()) / (1024 * 1024);

                    if (sizeInMB > 10) {
                      // ❌ Too large — show message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "❌ ${xfile.name} is too large (${sizeInMB.toStringAsFixed(2)} MB). Max allowed: 10 MB.",
                              style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating, // ✅ Makes it float with margin
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder( // ✅ Rounded corners
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.red, // ✅ Soft black, not pure #000
                        elevation: 6,
                          ),
                        );
                      }
                    } else {
                      // ✅ Valid file
                      validFiles.add(
                        UploadImage(file: file, label: limit[index]),
                      );
                    }
                  }

                  // ✅ Only add valid files
                  if (validFiles.isNotEmpty) {
                    setState(() {
                      _imageLists[index].addAll(validFiles);
                    });
                  }
                }
                  navigator.pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final XFile? pickedFile =
                      await picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null && mounted) {
                  final file = File(pickedFile.path);
                  final sizeInMB = (await file.length()) / (1024 * 1024);

                  if (sizeInMB > 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "❌ ${pickedFile.name} is too large (${sizeInMB.toStringAsFixed(2)} MB). Max allowed: 10 MB.",
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating, // ✅ Makes it float with margin
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder( // ✅ Rounded corners
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.red, // ✅ Soft black, not pure #000
                        elevation: 6,
                      ),
                    );
                  } else {
                    setState(() {
                      _imageLists[index].add(
                        UploadImage(file: file, label: limit[index]),
                      );
                    });
                  }
                }
                  navigator.pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _convertImagestoBase64(List<File> images) async {
    List<String> base64Images = [];

    for (File image in images) {
      final bytes = await image.readAsBytes();
      base64Images.add(base64Encode(bytes));
    }
    return base64Images;
  }

  Future<Map<String, dynamic>> buildUploadMap() async {
    final Map<String, dynamic> uploadMap = {};
    for (int i = 0; i < limit.length; i++) {
      final label = limit[i];

      if(_imageLists[i].isNotEmpty) {
        final upload = _imageLists[i].first;
        final file = upload.file;

        final ext = file.path.split('.').last.toLowerCase();
        final safeExt = (ext == 'jpg' || ext == 'png') ? ext: 'jpg';

        final bytes = await file.readAsBytes();

        final base64Str = base64Encode(bytes);

        final filename = '${label.replaceAll(' ', '_')}.$safeExt';

        uploadMap[label] = {
          'filename': filename,
          'content': base64Str,
        };
      }else{
        uploadMap[label] = null;
      }
    }
    return uploadMap;
  }


  
   
  @override
  void initState() {
    super.initState();
    limit = getUploadLimit();
    _imageLists = List.generate(limit.length, (_) => <UploadImage>[]);
  }

  String getNullableValue(String? value, {String fallback = ''}) {
    return value ?? fallback;
  }
  
  @override
  Widget build(BuildContext context) {

    print('Confirmation Screen - Transaction Request Number: ${widget.transaction?.requestNumber}');
   
  int currentStep = 3; // Assuming Confirmation is step 3 (0-based index)

  final bookingNumber = widget.transaction?.bookingRefNumber;

    final allTransactions = ref.watch(transactionListProvider);
    // print("All Transaction: $allTransactions");

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
   

   
    return WillPopScope(
  onWillPop: () async {
    return await _showConfirmationDialog(context);
  },
  child: Scaffold(
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
              ProgressRow(currentStep: currentStep, uid: widget.uid, transaction: widget.transaction,relatedFF: relatedFF,),

              const SizedBox(height: 20),

             GridView.builder(
                itemCount: limit.length,
                shrinkWrap: true, // ✅ prevents unbounded height error
            physics: const NeverScrollableScrollPhysics(), // ✅ disables nested scrolling
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
              itemBuilder: (context,index) {
              
                return Container (
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column (
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        limit[index],
                        style:  AppTextStyles.caption,
                      ),
                      // const SizedBox(height: 5),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // const SizedBox(width:),
                              ..._imageLists[index].map((upload) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          upload.file,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _imageLists[index].remove(upload);
                                            });
                                          },
                                          child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.red,
                                            child: Icon(Icons.close, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              GestureDetector(
                                onTap: () => _pickImage(index),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: const Icon(Icons.camera_alt_outlined,
                                      size: 40,
                                      color: mainColor
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  )
                );
              }
            
            ),

              // ...List.generate(5, (index) {
              //   return Column(
              //     children: [
              //       Padding(
              //         padding: const EdgeInsets.all(16.0), // Add padding inside the container
              //         child: Container(
              //           height: 150,
              //           width: 150,
              //           padding: const EdgeInsets.all(16.0), // Add padding inside the container
              //           decoration: BoxDecoration(
              //             color: bgColor,
              //             borderRadius: BorderRadius.circular(20.0), // Rounded edges
              //           ),
              //           child: SingleChildScrollView(
              //             scrollDirection: Axis.horizontal,
              //             child: Row(
              //               children: [
              //                 const SizedBox(width: 10),
              //                 ..._imageLists[index].map((file) {
              //                   return Padding(
              //                     padding: const EdgeInsets.only(right: 10),
              //                     child: Stack(
              //                       children: [
              //                         ClipRRect(
              //                           borderRadius: BorderRadius.circular(8),
              //                           child: Image.file(
              //                             file,
              //                             width: 100,
              //                             height: 100,
              //                             fit: BoxFit.cover,
              //                           ),
              //                         ),
              //                         Positioned(
              //                           top: 2,
              //                           right: 2,
              //                           child: GestureDetector(
              //                             onTap: () {
              //                               setState(() {
              //                                 _imageLists[index].remove(file);
              //                               });
              //                             },
              //                             child: const CircleAvatar(
              //                               radius: 12,
              //                               backgroundColor: Colors.red,
              //                               child: Icon(Icons.close, size: 16, color: Colors.white),
              //                             ),
              //                           ),
              //                         ),
              //                       ],
              //                     ),
              //                   );
              //                 }).toList(),
              //               ],
              //             ),
              //           ),
              //         ),
              //       ),
              //       const SizedBox(height: 10),
              //       Center(
              //         child: GestureDetector(
              //           onTap: () => _pickImage(index),
              //           child: Container(
              //             width: 80,
              //             height: 80,
              //             decoration: BoxDecoration(
              //               color: Colors.white,
              //               borderRadius: BorderRadius.circular(12),
              //               border: Border.all(color: Colors.grey.shade400),
              //             ),
              //             child: const Icon(Icons.camera_alt_outlined,
              //                 size: 40,
              //                 color: mainColor
              //             ),
              //           ),
              //         ),
              //       ),
              //       const SizedBox(height: 10),
              //       Center(
              //         child: Text(
              //           'Upload Picture as Proof of Delivery',
              //           style: AppTextStyles.caption.copyWith(
              //             color: Colors.black54,
              //           ),
              //         ),
              //       ),
              //     ],
              //   );
              // }),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:() async {
                      final hasAnyImage = _imageLists.any((list) => list.isNotEmpty);
                      if (!hasAnyImage) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(
                                'Upload Error!', 
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.bold
                                ),
                                textAlign: TextAlign.center,
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Please select at least one image.',
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.black87
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  const Icon (
                                    Icons.image_outlined,
                                    color: bgColor,
                                    size: 100
                                  )
                                ],
                              ),
                              actions: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 200,
                                      child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      }, 
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: Text(
                                        "Try Again",
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white,
                                        )
                                      )
                                    ),
                                    )
                                  )
                                )
                              ],
                            );
                          }
                        );
                      } else {
                        final validImages = _imageLists
    .expand((list) => list)
    .map((upload) => upload.file) // ✅ extract File from UploadImage
    .toList();

                        if (validImages.isEmpty) {
                          return;
                        }
                        final navigator  = Navigator.of(context);
                        final base64Images =  await _convertImagestoBase64(validImages);
                        print('Base64 Image: $base64Images\n');
                        final uploadMap = await buildUploadMap();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => ProofOfDeliveryScreen(uid: widget.uid, transaction: widget.transaction, base64ImagesWithLabels: uploadMap),
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
                      "Confirm",
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  )
                )
              ],
            )
            
          ),
          NavigationMenu(
            onItemTap: (index) async {
              // Intercept menu taps
              final shouldLeave = await _showConfirmationDialog(context);
              if (shouldLeave) {
                switch (index) {
                  case 0:
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                  case 1:
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                  case 2:
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                }
              }
            },
          ),
        ],
      )
      
   
   ) // bottomNavigationBar: const NavigationMenu(),
    );
  }

   Widget progressRow(int currentStep) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3 * 2 - 1, (index) {
      // Step indices: 0, 2, 4; Connector indices: 1, 3
      if (index.isEven) {
        int stepIndex = index ~/ 2 + 1;
        Color stepColor = stepIndex < currentStep
            ? mainColor     // Completed
            : stepIndex == currentStep
                ? mainColor  // Active
                : Colors.grey;     // Upcoming

        bool isCurrent = stepIndex == currentStep;

        String label;
        switch (stepIndex) {
          case 1:
            label = "Delivery Log";
            break;
          case 2:
            label = "Schedule";
            break;
          case 3:
          default:
            label = "Confirmation";
        }

        return buildStep(label, stepColor, isCurrent);
      } else {
        int connectorIndex = (index - 1) ~/ 2 + 1;
        Color connectorColor = connectorIndex < currentStep
            ? mainColor
            : Colors.grey;

        return buildConnector(connectorColor);
      }
    }),
  );
}


  /// Single Progress Step Widget
 Widget buildStep(String label, Color color, bool isCurrent) {
  return Column(
    children: [
      CircleAvatar(
        radius: 10,
        backgroundColor: color,
        child: isCurrent
            ? const CircleAvatar(
                radius: 7,
                backgroundColor: Colors.white,
              )
            : null,
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
        ),
      ),
    ],
  );
}


  /// Connector Line Between Steps
  Widget buildConnector(Color color) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: 
        Container(
          width: 40,
          height: 4,
          color: color,
        ),
    );
  }
}

class UploadImage {
  final File file;
  final String label;

  UploadImage({required this.file, required this.label});
}

Future<bool> _showConfirmationDialog(BuildContext context) async {
   final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:  Text(
            "Are you sure?",
            style: AppTextStyles.title.copyWith(
              color: mainColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          content: Text(
            "Leaving now will discard any changes you made.",
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(
              color: Colors.black87
            ),
          ),

          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded (
                  child: Padding (
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("Stay", style: AppTextStyles.body.copyWith(color: Colors.white)),
                    ),
                  )
                ),
                Expanded (
                  child: Padding (
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text("Leave", style: AppTextStyles.body.copyWith(color: Colors.white)),
                    ),
                  )
                )
              ],
            ),
          ],
        );
      },
    );
    return shouldLeave ?? false; // return true if user confirms leave
}