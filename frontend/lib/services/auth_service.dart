// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://yxe-driverapp-live.gothong.com/api',
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  Future<Map<String, dynamic>> login(String email, String password) async {
//   try {
//     final response = await _dio.post(
//       '/login',
//       data: {'email': email, 'password': password},
//     );

//     print('Raw Response: ${response.data}'); 

//     if (response.statusCode == 200) {
//       if (response.data is Map<String, dynamic>) {
//         print('✅ Login Success: ${response.data}');
//         return response.data;  
//       } else {
//         print('❌ Invalid response format: ${response.data}');
//         return {'error': 'Invalid response format'};
//       }
//     } else {
//       print('❌ Login failed with status: ${response.statusCode}');
//       return {'error': 'Login failed'};
//     }
//   } on DioException catch (e) {
//     if (e.response != null) {
//       print('❌ Dio Error Response: ${e.response?.data}');
//       print('Status Code: ${e.response?.statusCode}');
//     } else {
//       print('❌ Dio Error: ${e.message}');
//     }
//     return {'error': 'Login failed'};
//   } catch (e) {
//     print('❌ Unexpected Error: $e');
//     return {'error': 'Unexpected error occurred'};
//   }
// }
  // Future<Map<String, dynamic>> login(String email, String password) async {
  //   // bool isLoggedIn = false;

    try {
      final response = await _dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
        headers: {
          'Accept': 'application/json', // 👈 Include Accept again
          'login': email,               // 👈 Laravel expects this in headers
          'password': password,         // 👈 Laravel expects this too
        },
      ),
        
      );

      print('Response: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        // Backend returned an error
        print('Dio Error Response: ${e.response?.data}');
        print('Status Code: ${e.response?.statusCode}');
      } else {
        // No response from server (network issue)
        print('Dio Error: ${e.message}');
      }
      return {'error': 'Login failed'};
    } catch (e) {
      print('Unexpected Error: $e');
      return {'error': 'Unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> register(
      String name,
      String email,
      String mobile,
      String? companyCode,
      String password,
      File? picture) async {
    FormData formData = FormData.fromMap({
      'name': name,
      'email': email,
      'mobile': mobile,
      'company_code': companyCode,
      'password': password,
      if (picture != null)
        'picture': await MultipartFile.fromFile(
          picture.path,
          filename: picture.path.split('/').last,
        ),
    });

    final response = await _dio.post(
      '/register',
      data: formData, // Send the formData instead of plain data
      options: Options(
        contentType: 'multipart/form-data', // Ensure proper content type
      ),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await _dio.post(
      '/logout',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> update(
    String? name,
    String? email,
    String? mobile,
    String? companyCode,
    String? password,
    File? picture,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    FormData formData = FormData.fromMap({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (mobile != null) 'mobile': mobile,
      if (companyCode != null) 'companyCode': companyCode,
      if (password != null) 'password': password,
      if (picture != null)
        'picture': await MultipartFile.fromFile(
          picture.path,
          filename: picture.path.split('/').last,
        ),
    });
    try {
      final response = await _dio.put(
        '/update', // Your API endpoint
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Login':login
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
            'Failed to update profile. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // final response = await _dio.put(
  //   '/update', // Ensure this is your correct endpoint
  //   data: data,
  //   options: Options(
  //     headers: {
  //       'Authorization': 'Bearer $token',
  //       'Content-Type': 'application/json',
  //     },
  //   ),
  // );

  // return response.data;
}
