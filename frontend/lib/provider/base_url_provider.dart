import 'package:flutter_riverpod/flutter_riverpod.dart';

final baseUrlProvider = Provider<String>((ref) {
  // You can change the base URL here
  return 'https://yxe-driverapp-beta.gothong.com'; // Replace with your actual base URL
  // return 'http://192.168.76.86:8080'; 
});