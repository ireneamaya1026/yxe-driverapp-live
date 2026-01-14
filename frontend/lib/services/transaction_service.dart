// Import for jsonEncode to convert Map to JSON if needed

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

final transactionServiceProvider =
    Provider<TransactionService>((ref) => TransactionService());

class TransactionService {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.76.86:8080/api',
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  Future<Map<String, dynamic>> submit(
      int userId,
      double amount,
      DateTime? transactionDate,
      String description,
      String transactionId,
      String booking,
      String location,
      String destination,
      DateTime? eta,
      DateTime? etd,
      String status,
      Uint8List signature,
      List<File?> transactionImages) async {
    // Convert Uint8List transaction images to MultipartFile
    List<MultipartFile> imageFiles =
        transactionImages.where((file) => file != null).map((file) {
      return MultipartFile.fromFileSync(
        file!.path,
        filename: file.path.split('/').last,
        contentType:
            MediaType('image', 'jpeg'), // Adjust MIME type as necessary
      );
    }).toList();

    FormData formData = FormData.fromMap({
      'user_id': userId,
      'amount': amount,
      'transaction_date': transactionDate?.toIso8601String(),
      'description': description,
      'transaction_id': transactionId,
      'booking': booking,
      'location': location,
      'destination': destination,
      'eta': eta?.toIso8601String(),
      'etd': etd?.toIso8601String(),
      'status': status,
      'signature_path': MultipartFile.fromBytes(
        signature,
        filename: '$signature.png',
        contentType: MediaType('image', 'png'),

        // Specify MIME type here
      ),
      'transaction_image_path': imageFiles,
    });

    try {
      // Send the POST request with the data as FormData for multipart support
      final response = await _dio.post(
        '/createTransaction',
        data: formData, // Use FormData here
        options: Options(
          headers: {
            'Accept': 'application/json', // Ensure proper format
            'Content-Type': 'multipart/form-data', // Required for file uploads
          },
        ),
      );

      // If the response is a Map, return it; otherwise, print an error
      if (response.data is Map<String, dynamic>) {
        return response.data;
      } else {
        print('Unexpected response format: ${response.data}');
        return {};
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors
      print('Dio error occurred: ${e.message}');
      if (e.response != null) {
        print('Error data: ${e.response?.data}');
      }
      throw Exception('Failed to submit transaction: ${e.message}');
    } catch (e) {
      // Handle any other errors
      print('Unexpected error: $e');
      throw Exception('An unexpected error occurred');
    }
  }
}
