import 'package:frontend/models/transaction_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// StateNotifier for managing and updating transaction list
class TransactionListNotifier extends StateNotifier<List<Transaction>> {
  TransactionListNotifier() : super([]);

  void loadTransactions(List<Transaction> transactions) {
    state = transactions;
  }

  bool get hasData => state.isNotEmpty;

  void clear(){
    state = [];
  }


  // Method to update a transaction’s status
  void updateTransactionStatus(int id, String newStatus) {
    state = [
      for (final transaction in state)
        if (transaction.id == id)
          transaction.copyWith(status: newStatus)
        else
          transaction,
    ];
  }
}

// Provider to use the TransactionListNotifier
final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, List<Transaction>>(
    (ref) => TransactionListNotifier(),
);

// Provider to get the list of pending transactions
final pendingTransactionProvider = Provider<List<Transaction>>((ref) {
  final allTransactions = ref.watch(transactionListProvider);
  return allTransactions
      .where((transaction) => transaction.status == 'Pending')
      .toList();
});

// AcceptedTransaction provider
final acceptedTransactionProvider = Provider((ref) {
  final allTransactions = ref.watch(transactionListProvider);
  return allTransactions
      .where((transaction) => transaction.status == 'Ongoing')
      .toSet();
});

final rejectedTransactionProvider = Provider((ref) {
  final allTransactions = ref.watch(transactionListProvider);
  return allTransactions
      .where((transaction) => transaction.status == 'Rejected')
      .toSet();
});

// final ongoingTransactionProvider = Provider((ref) {
//   final allTransactions = ref.watch(transactionListProvider);
//   return allTransactions
//       .where((transaction) => transaction.status == 'Ongoing')
//       .toSet();
// });

final completedTransactionProvider = Provider((ref) {
  final allTransactions = ref.watch(transactionListProvider);
  return allTransactions
      .where((transaction) => transaction.status == 'Completed')
      .toSet();
});

final todayTransactionProvider =
    StateNotifierProvider<TransactionListNotifier, List<Transaction>>(
  (ref) => TransactionListNotifier(),
);

final ongoingTransactionProvider =
    StateNotifierProvider<TransactionListNotifier, List<Transaction>>(
  (ref) => TransactionListNotifier(),
);

final historyTransactionProvider =
    StateNotifierProvider<TransactionListNotifier, List<Transaction>>(
  (ref) => TransactionListNotifier(),
);


