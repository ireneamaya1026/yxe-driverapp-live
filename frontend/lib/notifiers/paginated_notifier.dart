import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/transaction_model.dart';
import 'package:frontend/notifiers/auth_notifier.dart';
import 'package:frontend/notifiers/paginated_state.dart';
import 'package:frontend/provider/base_url_provider.dart';
import 'package:http/http.dart' as http;

class PaginatedNotifier extends StateNotifier<PaginatedTransactionState>{
  PaginatedNotifier(this.ref, this.endpoint) : super(PaginatedTransactionState.initial());

  final Ref ref;
  final String endpoint;

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      // Simulate fetching data from an API
      final baseUrl = ref.watch(baseUrlProvider);
      final auth = ref.watch(authNotifierProvider);
      final uid =auth.uid;
      final password = auth.password ?? '';
      final login = auth.login ?? '';

      final response = await http.get(
          Uri.parse('$baseUrl/api/odoo/booking/$endpoint?uid=$uid&page=${state.currentPage + 1}&limit=5&password=$password&login=$login',),
        
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          "password": password,
          "login": login,
        },
      );

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          final result = decoded['data'] ?? [];
          final List list = result['transactions'] as List;
          final currentPage = result['current_page'];
          final lastPage = result['last_page'];

          // print("Response body for show all booking: ${response.body}");

          final newTransactions = list.map((item) => Transaction.fromJson(item)).toList();

          state = state.copyWith(
            transactions: [...state.transactions, ...newTransactions],
            currentPage: currentPage,
            hasMore: currentPage < lastPage,
            isLoading: false,
          );
        } else {
          throw Exception('Failed to fetch page');
        }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
     
  }

  Future<void> refresh() async {
    state = PaginatedTransactionState.initial();
      await fetchNextPage();
  }
}

final bookingProvider = StateNotifierProvider.family<
    PaginatedNotifier, PaginatedTransactionState, String>((ref, endpoint) {
  return PaginatedNotifier(ref, endpoint);
});