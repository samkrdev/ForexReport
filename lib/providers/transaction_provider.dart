import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  // Get today's transactions
  List<Transaction> get todayTransactions {
    final today = DateTime.now();
    return _transactions.where((transaction) {
      return transaction.timestamp.year == today.year &&
          transaction.timestamp.month == today.month &&
          transaction.timestamp.day == today.day;
    }).toList();
  }

  // Calculate commission as difference between sales and purchases for a specific date
  double getCommissionForDate(DateTime date) {
    final dateTransactions = _transactions.where((transaction) {
      return transaction.timestamp.year == date.year &&
          transaction.timestamp.month == date.month &&
          transaction.timestamp.day == date.day;
    });

    double totalSales = 0;
    double totalPurchases = 0;

    for (final transaction in dateTransactions) {
      if (transaction.type == TransactionType.sale) {
        totalSales += transaction.amountInINR;
      } else {
        totalPurchases += transaction.amountInINR;
      }
    }

    return totalSales - totalPurchases;
  }

  // Get today's commission
  double get todayCommission => getCommissionForDate(DateTime.now());

  // Get this week's commission data
  Map<String, double> getWeeklyCommissionData() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    Map<String, double> weeklyData = {};

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i];
      final dayMonth = '${dayName}\n${date.day}/${date.month}';
      weeklyData[dayMonth] = getCommissionForDate(date);
    }

    return weeklyData;
  }

  // Get commission breakdown by transaction type
  Map<String, double> getCommissionBreakdown() {
    final today = DateTime.now();
    final todayTransactions = _transactions.where((transaction) {
      return transaction.timestamp.year == today.year &&
          transaction.timestamp.month == today.month &&
          transaction.timestamp.day == today.day;
    });

    double publicSales = 0;
    double bulkSales = 0;
    double publicPurchases = 0;
    double dealerPurchases = 0;

    for (final transaction in todayTransactions) {
      if (transaction.type == TransactionType.sale) {
        if (transaction.subType == TransactionSubType.public) {
          publicSales += transaction.amountInINR;
        } else if (transaction.subType == TransactionSubType.bulk) {
          bulkSales += transaction.amountInINR;
        }
      } else {
        if (transaction.subType == TransactionSubType.public) {
          publicPurchases += transaction.amountInINR;
        } else if (transaction.subType == TransactionSubType.dealer) {
          dealerPurchases += transaction.amountInINR;
        }
      }
    }

    return {
      'publicSales': publicSales,
      'bulkSales': bulkSales,
      'publicPurchases': publicPurchases,
      'dealerPurchases': dealerPurchases,
    };
  }

  // Load transactions from local storage
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString('transactions') ?? '[]';

      final List<dynamic> transactionsList = json.decode(transactionsJson);

      _transactions =
          transactionsList.map((json) => Transaction.fromJson(json)).toList();

      // Sort by timestamp (newest first)
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      // Clear corrupted data and start fresh
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('transactions');
      } catch (clearError) {
        // Ignore clear errors
      }
      _transactions = []; // Initialize empty list on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save transactions to local storage
  Future<void> _saveTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = json.encode(
        _transactions.map((transaction) => transaction.toJson()).toList(),
      );
      await prefs.setString('transactions', transactionsJson);
    } catch (e) {
      debugPrint('Error saving transactions: $e');
    }
  }

  // Add a new transaction
  Future<void> addTransaction(Transaction transaction) async {
    _transactions.insert(0, transaction);
    notifyListeners();
    await _saveTransactions();
  }

  // Update an existing transaction
  Future<void> updateTransaction(Transaction updatedTransaction) async {
    final index =
        _transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      _transactions[index] = updatedTransaction;
      // Sort by timestamp (newest first)
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
      await _saveTransactions();
    }
  }

  // Delete a single transaction
  Future<void> deleteTransaction(String transactionId) async {
    _transactions.removeWhere((t) => t.id == transactionId);
    notifyListeners();
    await _saveTransactions();
  }

  // Delete transactions by date range
  Future<void> deleteTransactionsByRange(String range) async {
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (range) {
      case 'Today':
        cutoffDate = DateTime(now.year, now.month, now.day);
        _transactions.removeWhere((transaction) {
          return transaction.timestamp.year == cutoffDate.year &&
              transaction.timestamp.month == cutoffDate.month &&
              transaction.timestamp.day == cutoffDate.day;
        });
        break;
      case 'This week':
        cutoffDate = now.subtract(Duration(days: now.weekday - 1));
        _transactions.removeWhere((transaction) {
          return transaction.timestamp.isAfter(cutoffDate) ||
              transaction.timestamp.isAtSameMomentAs(cutoffDate);
        });
        break;
      case 'This month':
        cutoffDate = DateTime(now.year, now.month, 1);
        _transactions.removeWhere((transaction) {
          return transaction.timestamp.year == cutoffDate.year &&
              transaction.timestamp.month == cutoffDate.month;
        });
        break;
      case 'All':
        _transactions.clear();
        break;
    }

    notifyListeners();
    await _saveTransactions();
  }

  // Get transactions for export
  List<Transaction> getTransactionsForExport(
      {DateTime? startDate, DateTime? endDate}) {
    if (startDate == null && endDate == null) {
      return _transactions;
    }

    return _transactions.where((transaction) {
      if (startDate != null && transaction.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && transaction.timestamp.isAfter(endDate)) {
        return false;
      }
      return true;
    }).toList();
  }

  // Clear all data (for debugging)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('transactions');
      _transactions = [];
      notifyListeners();
    } catch (e) {
      // Ignore errors
    }
  }
}
