import 'package:flutter/material.dart';
import 'package:frontend/theme/colors.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:frontend/user/confirmation.dart';
import 'package:frontend/user/detailed_details.dart';
import 'package:frontend/user/schedule.dart';

class ProgressRow extends StatelessWidget {
  final int currentStep;
  final String uid;
  final dynamic transaction;
  final dynamic relatedFF;

  const ProgressRow({
    super.key,
    required this.currentStep,
    required this.uid,
    required this.transaction,
    required this.relatedFF,
  });

  @override
  Widget build(BuildContext context) {
    final stepLabels = [
      'Delivery Log',
      'Schedule',
      'Confirmation',
    ];

    final stepPage = [
      DetailedDetailScreen(uid: uid, transaction: transaction, relatedFF: relatedFF),
      ScheduleScreen(uid: uid, transaction: transaction, relatedFF: relatedFF),
      ConfirmationScreen(uid: uid, transaction: transaction, relatedFF: relatedFF, requestNumber: transaction?.requestNumber ?? '', id: transaction?.id ?? 0,),
    ];

    return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3 * 2 - 1, (index) {
      // Step indices: 0, 2, 4; Connector indices: 1, 3
      if (index.isEven) {
        int stepIndex = index ~/ 2;
        int displayStep = stepIndex + 1; // For display purposes (1, 2, 3)
        bool isCurrent = displayStep == currentStep;

        Color stepColor = displayStep < currentStep
            ? mainColor // Completed
            : isCurrent
                ? mainColor // Current
                : Colors.grey; // Upcoming

        

        return GestureDetector(
          onTap: () {
              final errorMessage = _checkPrerequisites(
                transaction,
                transaction.requestNumber ?? "",
                relatedFF,
              );

              if (errorMessage != null) {
                showDialog(
                  context: context, 
                  builder: (BuildContext ctx) {
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
                        errorMessage,
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
                  });
                
              } else {
                // ✅ Safe to navigate
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => stepPage[stepIndex],
                  ),
                );
              }
            },
            child: buildStep(stepLabels[stepIndex], stepColor, isCurrent)
        );
      }else {
        int connectorIndex = (index - 1) ~/ 2 + 1;
        Color connectorColor;
        switch(connectorIndex) {
          case 1:
            connectorColor = currentStep > 1 ? mainColor : Colors.grey;
            break;
          case 2:
            connectorColor = currentStep > 2 ? mainColor : Colors.grey;
            break;
          case 3:
            connectorColor = currentStep > 3 ? mainColor : Colors.grey;
            break;
          default:
            connectorColor = Colors.grey;
        } // Upcoming

        return buildConnector(connectorColor);
      }
    }),
  );
  }
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
          )
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

  String? _checkPrerequisites(dynamic transaction, String requestNumber, dynamic relatedFF) {
  
    // print('Related FF Stage ID from Progress Roww: ${relatedFF?.stageId}');

 
    if (requestNumber == transaction.plRequestNumber &&
        transaction.deRequestStatus == "Ongoing"){ 
          return null;
          }

    if (requestNumber == transaction.dlRequestNumber &&
        transaction.dlRequestStatus == "Ongoing") { 
          return null;
          }

    if (requestNumber == transaction.deRequestNumber &&
        transaction.deRequestStatus == "Ongoing") { 
          return null;
          }

    if (requestNumber == transaction.peRequestNumber &&
        transaction.peRequestStatus == "Ongoing") { 
          return null;
          }

    if(transaction.freightForwarderName!.isEmpty) {
      return "Associated Freight Forwarding Vendor has not yet been assigned.";
    }

    // ✅ If FF stage is expected but temporarily missing, skip validation
    if (requestNumber == transaction.deRequestNumber &&
        transaction.deRequestStatus == "Ongoing" &&
        relatedFF == null) { 
          return null;
          }

    if (requestNumber == transaction.deRequestNumber &&
        relatedFF.stageId == "Vendor Accepted") { 
          return null;
          }


      if (requestNumber == transaction.plRequestNumber &&
          transaction.deRequestStatus != "Completed" && transaction.deRequestStatus != "Backload") {
        return "Delivery Empty should be completed first.";
      }

     if (requestNumber == transaction.dlRequestNumber &&
      (relatedFF == null || relatedFF.stageId?.trim() != "Completed")) {
    return "Associated Freight Forwarding should be completed first.";
  }

  // if (requestNumber == transaction.deRequestNumber &&
  //     (relatedFF == null || relatedFF.stageId?.trim() != "Vendor Accepted")) {
  //   return "Associated Freight Forwarding Vendor has not yet been assigned.";
  // }


    if (requestNumber == transaction.peRequestNumber &&
        transaction.dlRequestStatus != "Completed") {
      return "Delivery Laden should be completed first.";
    }

    return null;
  }
}

