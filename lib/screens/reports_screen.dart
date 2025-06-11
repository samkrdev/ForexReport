import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../utils/theme.dart';
import '../utils/download_utils.dart';
import 'dart:convert' show utf8;
import 'dart:typed_data';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showCustomerDealer = true;
  bool _showNotes = true;

  // Field-based filter properties
  TransactionType? _filterType;
  TransactionSubType? _filterSubType;
  String? _filterCurrency;
  String? _filterCustomerDealer;
  double? _minAmount;
  double? _maxAmount;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final filteredTransactions = _getFilteredTransactions(provider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reports'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.loadTransactions(),
              ),
            ],
          ),
          body: Container(
            decoration: AppTheme.backgroundGradient,
            child: Column(
              children: [
                // Filter status and date range controls
                _buildFilterControls(),

                // Advanced Filters button - ALWAYS visible
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAdvancedFilterModal,
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(_hasActiveFilters()
                              ? 'Advanced Filters (Active)'
                              : 'Advanced Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasActiveFilters()
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade100,
                            foregroundColor: _hasActiveFilters()
                                ? Colors.white
                                : AppTheme.textDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        // Center content for large screens
                        constraints: constraints.maxWidth > 1200
                            ? const BoxConstraints(maxWidth: 1200)
                            : null,
                        margin: constraints.maxWidth > 1200
                            ? EdgeInsets.symmetric(
                                horizontal: (constraints.maxWidth - 1200) / 2)
                            : null,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (filteredTransactions.isEmpty)
                                _buildEmptyState()
                              else ...[
                                // Summary cards
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child:
                                      _buildSummaryCards(filteredTransactions),
                                ),
                                const SizedBox(height: 20),

                                // Transaction list
                                if (constraints.maxWidth < 800)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildColumnToggles(),
                                        const SizedBox(height: 16),
                                        _buildMobileTransactionCards(
                                            filteredTransactions),
                                      ],
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildColumnToggles(),
                                        const SizedBox(height: 16),
                                        Container(
                                          decoration: AppTheme.cardDecoration,
                                          child: _buildDesktopTransactionTable(
                                              filteredTransactions),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Export and Delete Options at bottom
                if (filteredTransactions.isNotEmpty) _buildActionButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Transaction> _getFilteredTransactions(TransactionProvider provider) {
    List<Transaction> transactions = provider.getTransactionsForExport(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Apply field-based filters
    if (_filterType != null) {
      transactions = transactions.where((transaction) {
        return transaction.type == _filterType;
      }).toList();
    }

    if (_filterSubType != null) {
      transactions = transactions.where((transaction) {
        return transaction.subType == _filterSubType;
      }).toList();
    }

    if (_filterCurrency != null) {
      transactions = transactions.where((transaction) {
        return transaction.currency == _filterCurrency;
      }).toList();
    }

    // Apply customer/dealer filter
    if (_filterCustomerDealer != null) {
      transactions = transactions.where((transaction) {
        return transaction.customerName?.contains(_filterCustomerDealer!) ==
                true ||
            transaction.dealerName?.contains(_filterCustomerDealer!) == true;
      }).toList();
    }

    // Apply amount filter
    if (_minAmount != null || _maxAmount != null) {
      transactions = transactions.where((transaction) {
        bool matchesMin =
            _minAmount == null || transaction.amount >= _minAmount!;
        bool matchesMax =
            _maxAmount == null || transaction.amount <= _maxAmount!;
        return matchesMin && matchesMax;
      }).toList();
    }

    return transactions;
  }

  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Date Range Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              if (_startDate != null ||
                  _endDate != null ||
                  _filterType != null ||
                  _filterSubType != null ||
                  _filterCurrency != null ||
                  _filterCustomerDealer != null ||
                  _minAmount != null ||
                  _maxAmount != null)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Active filters display
          if (_startDate != null ||
              _endDate != null ||
              _filterType != null ||
              _filterSubType != null ||
              _filterCurrency != null ||
              _filterCustomerDealer != null ||
              _minAmount != null ||
              _maxAmount != null) ...[
            const Text(
              'Active Filters:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_startDate != null)
                  _buildFilterChip(
                    'From: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
                    () => setState(() => _startDate = null),
                  ),
                if (_endDate != null)
                  _buildFilterChip(
                    'To: ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                    () => setState(() => _endDate = null),
                  ),
                if (_filterType != null)
                  _buildFilterChip(
                    'Type: ${_filterType!.name.toUpperCase()}',
                    () => setState(() => _filterType = null),
                  ),
                if (_filterSubType != null)
                  _buildFilterChip(
                    'Sub Type: ${_filterSubType!.name.toUpperCase()}',
                    () => setState(() => _filterSubType = null),
                  ),
                if (_filterCurrency != null)
                  _buildFilterChip(
                    'Currency: $_filterCurrency',
                    () => setState(() => _filterCurrency = null),
                  ),
                if (_filterCustomerDealer != null)
                  _buildFilterChip(
                    'Name: $_filterCustomerDealer',
                    () => setState(() => _filterCustomerDealer = null),
                  ),
                if (_minAmount != null)
                  _buildFilterChip(
                    'Min Amount: ${NumberFormat('#,###.##').format(_minAmount!)}',
                    () => setState(() => _minAmount = null),
                  ),
                if (_maxAmount != null)
                  _buildFilterChip(
                    'Max Amount: ${NumberFormat('#,###.##').format(_maxAmount!)}',
                    () => setState(() => _maxAmount = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Date selection row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectStartDate(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _startDate != null
                            ? AppTheme.primaryBlue
                            : Colors.grey,
                        width: _startDate != null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: _startDate != null
                          ? AppTheme.primaryBlue.withOpacity(0.05)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _startDate == null
                              ? 'Start Date'
                              : DateFormat('dd/MM/yyyy').format(_startDate!),
                          style: TextStyle(
                            color: _startDate != null
                                ? AppTheme.primaryBlue
                                : AppTheme.textMedium,
                            fontWeight: _startDate != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: _startDate != null
                              ? AppTheme.primaryBlue
                              : AppTheme.textLight,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectEndDate(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _endDate != null
                            ? AppTheme.primaryBlue
                            : Colors.grey,
                        width: _endDate != null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: _endDate != null
                          ? AppTheme.primaryBlue.withOpacity(0.05)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _endDate == null
                              ? 'End Date'
                              : DateFormat('dd/MM/yyyy').format(_endDate!),
                          style: TextStyle(
                            color: _endDate != null
                                ? AppTheme.primaryBlue
                                : AppTheme.textMedium,
                            fontWeight: _endDate != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: _endDate != null
                              ? AppTheme.primaryBlue
                              : AppTheme.textLight,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick filter buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterButton('Today', _setTodayFilter),
              _buildQuickFilterButton('This Week', _setThisWeekFilter),
              _buildQuickFilterButton('This Month', _setThisMonthFilter),
              _buildQuickFilterButton('Last 7 Days', _setLast7DaysFilter),
              _buildQuickFilterButton('Last 30 Days', _setLast30DaysFilter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterButton(String label, VoidCallback onPressed) {
    final isActive = _isQuickFilterActive(label);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? AppTheme.primaryBlue : Colors.grey[100],
        foregroundColor: isActive ? Colors.white : AppTheme.textMedium,
        elevation: isActive ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isActive ? AppTheme.primaryBlue : Colors.grey[300]!,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  bool _isQuickFilterActive(String filterType) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filterType) {
      case 'Today':
        return _startDate != null &&
            _endDate != null &&
            _startDate!.isAtSameMomentAs(today) &&
            _endDate!.isAtSameMomentAs(today
                .add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1)));
      case 'This Week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek
            .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return _startDate != null &&
            _endDate != null &&
            _startDate!.isAtSameMomentAs(startOfWeek) &&
            _endDate!.isAtSameMomentAs(endOfWeek);
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(milliseconds: 1));
        return _startDate != null &&
            _endDate != null &&
            _startDate!.isAtSameMomentAs(startOfMonth) &&
            endOfMonth.difference(_endDate!).inDays.abs() <= 1;
      case 'Last 7 Days':
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        return _startDate != null &&
            _endDate != null &&
            _startDate!.isAtSameMomentAs(sevenDaysAgo) &&
            _endDate!.isAtSameMomentAs(today
                .add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1)));
      case 'Last 30 Days':
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        return _startDate != null &&
            _endDate != null &&
            _startDate!.isAtSameMomentAs(thirtyDaysAgo) &&
            _endDate!.isAtSameMomentAs(today
                .add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1)));
      default:
        return false;
    }
  }

  void _clearAllFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filterType = null;
      _filterSubType = null;
      _filterCurrency = null;
      _filterCustomerDealer = null;
      _minAmount = null;
      _maxAmount = null;
    });
  }

  void _setTodayFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _startDate = today;
      _endDate = today
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
    });
  }

  void _setThisWeekFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    setState(() {
      _startDate = startOfWeek;
      _endDate = endOfWeek;
    });
  }

  void _setThisMonthFilter() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));
    setState(() {
      _startDate = startOfMonth;
      _endDate = endOfMonth;
    });
  }

  void _setLast7DaysFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    setState(() {
      _startDate = sevenDaysAgo;
      _endDate = today
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
    });
  }

  void _setLast30DaysFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));
    setState(() {
      _startDate = thirtyDaysAgo;
      _endDate = today
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
    });
  }

  Widget _buildSummaryCards(List<Transaction> transactions) {
    double totalSales = 0;
    double totalPurchases = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.sale) {
        totalSales += transaction.amountInINR;
      } else {
        totalPurchases += transaction.amountInINR;
      }
    }

    final commission = totalSales - totalPurchases;

    final layoutBuilder = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile layout - vertical stacking with better spacing (like dashboard)
          return Column(
            children: [
              _buildSummaryCard(
                'Total Sales',
                '₹${NumberFormat('#,##,###.##').format(totalSales)}',
                Icons.trending_up,
                AppTheme.successGreen,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Total Purchases',
                '₹${NumberFormat('#,##,###.##').format(totalPurchases)}',
                Icons.trending_down,
                AppTheme.infoBlue,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Net Difference',
                '₹${NumberFormat('#,##,###.##').format(commission)}',
                Icons.account_balance_wallet,
                commission >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
              ),
            ],
          );
        } else {
          // Desktop layout - horizontal (like dashboard)
          return Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Sales',
                  '₹${NumberFormat('#,##,###.##').format(totalSales)}',
                  Icons.trending_up,
                  AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Total Purchases',
                  '₹${NumberFormat('#,##,###.##').format(totalPurchases)}',
                  Icons.trending_down,
                  AppTheme.infoBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Net Difference',
                  '₹${NumberFormat('#,##,###.##').format(commission)}',
                  Icons.account_balance_wallet,
                  commission >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
            ],
          );
        }
      },
    );

    return layoutBuilder;
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 110,
        maxHeight: 130,
      ),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration.copyWith(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.05),
            Colors.white.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.visibility),
                  onSelected: (value) {
                    setState(() {
                      if (value == 'toggle_customer') {
                        _showCustomerDealer = !_showCustomerDealer;
                      } else if (value == 'toggle_notes') {
                        _showNotes = !_showNotes;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_customer',
                      child: Row(
                        children: [
                          Icon(_showCustomerDealer
                              ? Icons.visibility
                              : Icons.visibility_off),
                          const SizedBox(width: 8),
                          const Text('Name'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_notes',
                      child: Row(
                        children: [
                          Icon(_showNotes
                              ? Icons.visibility
                              : Icons.visibility_off),
                          const SizedBox(width: 8),
                          const Text('Notes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Advanced filter button (always visible)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showAdvancedFilterModal,
              icon: const Icon(Icons.filter_list),
              label: Text(_hasActiveFieldFilters()
                  ? 'Filters Applied'
                  : 'Advanced Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasActiveFieldFilters()
                    ? AppTheme.primaryBlue
                    : Colors.grey[100],
                foregroundColor: _hasActiveFieldFilters()
                    ? Colors.white
                    : AppTheme.textMedium,
                elevation: _hasActiveFieldFilters() ? 2 : 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _hasActiveFieldFilters()
                        ? AppTheme.primaryBlue
                        : Colors.grey[300]!,
                  ),
                ),
              ),
            ),
          ),

          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No transactions found',
                  style: TextStyle(color: AppTheme.textLight),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  // Mobile view - use cards
                  return _buildMobileTransactionCards(transactions);
                } else {
                  // Desktop view - use table
                  return _buildDesktopTransactionTable(transactions);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionCards(List<Transaction> transactions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // For big screens, use grid layout with max width cards
        if (constraints.maxWidth > 1200) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _buildTransactionCard(transaction);
            },
          );
        } else {
          // Regular list for smaller screens
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildTransactionCard(transaction),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isPositive = transaction.type == TransactionType.sale;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
              .withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Transaction Type Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isPositive
                              ? AppTheme.successGreen
                              : AppTheme.errorRed)
                          .withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${transaction.type.name.toUpperCase()} - ${transaction.subType.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                    ),
                  ),
                ),
                const Spacer(),
                // Action Buttons
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showEditTransactionDialog(transaction),
                  tooltip: 'Edit',
                  color: AppTheme.primaryBlue,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _showDeleteTransactionDialog(transaction),
                  tooltip: 'Delete',
                  color: AppTheme.errorRed,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(transaction.timestamp),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            // Amount Details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,###.##').format(transaction.amount)} ${transaction.currency}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rate',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat('#.##').format(transaction.conversionRate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INR Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${NumberFormat('#,###.##').format(transaction.amountInINR)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Optional Customer/Dealer
            if (_showCustomerDealer &&
                (transaction.customerName != null ||
                    transaction.dealerName != null)) ...[
              const SizedBox(height: 12),
              Text(
                '${transaction.type == TransactionType.sale ? 'Customer' : 'Dealer'}: ${transaction.customerName ?? transaction.dealerName}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
            ],

            // Optional Notes
            if (_showNotes &&
                transaction.notes != null &&
                transaction.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${transaction.notes}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTransactionTable(List<Transaction> transactions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        dataRowHeight: 64,
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: [
          const DataColumn(label: Text('Date')),
          const DataColumn(label: Text('Type')),
          const DataColumn(label: Text('Sub Type')),
          const DataColumn(label: Text('Amount')),
          const DataColumn(label: Text('Currency')),
          const DataColumn(label: Text('Rate')),
          const DataColumn(label: Text('INR Amount')),
          if (_showCustomerDealer) const DataColumn(label: Text('Name')),
          if (_showNotes) const DataColumn(label: Text('Notes')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: transactions.map((transaction) {
          return DataRow(
            cells: [
              DataCell(
                  Text(DateFormat('dd/MM/yy').format(transaction.timestamp))),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: transaction.type == TransactionType.sale
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    transaction.type.name.toUpperCase(),
                    style: TextStyle(
                      color: transaction.type == TransactionType.sale
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(Text(transaction.subType.name.toUpperCase())),
              DataCell(
                  Text(NumberFormat('#,###.##').format(transaction.amount))),
              DataCell(Text(transaction.currency)),
              DataCell(Text(
                  NumberFormat('#.##').format(transaction.conversionRate))),
              DataCell(
                Text(
                  '₹${NumberFormat('#,###.##').format(transaction.amountInINR)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (_showCustomerDealer)
                DataCell(
                  Text(
                    transaction.customerName ?? transaction.dealerName ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (_showNotes)
                DataCell(
                  Text(
                    transaction.notes ?? '-',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showEditTransactionDialog(transaction),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () =>
                          _showDeleteTransactionDialog(transaction),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _startDate = DateTime(date.year, date.month, date.day);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      });
    }
  }

  Future<void> _exportToCsv() async {
    try {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final transactions = _getFilteredTransactions(provider);

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final List<List<dynamic>> csvData = [
        [
          'Date',
          'Time',
          'Type',
          'Sub Type',
          'Amount',
          'Currency',
          'Rate',
          'INR Amount',
          if (_showCustomerDealer) 'Name',
          if (_showNotes) 'Notes'
        ]
      ];

      for (final transaction in transactions) {
        csvData.add([
          DateFormat('dd/MM/yyyy').format(transaction.timestamp),
          DateFormat('HH:mm').format(transaction.timestamp),
          transaction.type.name.toUpperCase(),
          transaction.subType.name.toUpperCase(),
          transaction.amount,
          transaction.currency,
          transaction.conversionRate,
          transaction.amountInINR,
          if (_showCustomerDealer)
            transaction.customerName ?? transaction.dealerName ?? '',
          if (_showNotes) transaction.notes ?? '',
        ]);
      }

      final String csv = const ListToCsvConverter().convert(csvData);

      final filename =
          'vakharia_forex_report_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        DownloadUtils.downloadCsv(csv, filename);
      } else {
        await DownloadUtils.downloadCsv(csv, filename);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final transactions = _getFilteredTransactions(provider);

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _exportToPDF(transactions);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToPDF(List<Transaction> transactions) async {
    final pdf = pw.Document();

    // Calculate summary data
    final totalSales = transactions
        .where((t) => t.type == TransactionType.sale)
        .fold(0.0, (sum, t) => sum + t.amountInINR);
    final totalPurchases = transactions
        .where((t) => t.type == TransactionType.purchase)
        .fold(0.0, (sum, t) => sum + t.amountInINR);
    final netAmount = totalSales - totalPurchases;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader(),
        footer: (context) => _buildPdfFooter(context),
        build: (context) {
          return [
            // Title and date range
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Transaction Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      'Filter: ${_getActiveFilterDescription()}',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Summary section with color-coded boxes
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildPdfSummaryBox(
                      'Total Sales',
                      'Rs.${NumberFormat('#,###.##').format(totalSales)}',
                      PdfColors.green,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildPdfSummaryBox(
                      'Total Purchases',
                      'Rs.${NumberFormat('#,###.##').format(totalPurchases)}',
                      PdfColors.red,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildPdfSummaryBox(
                      'Net Amount',
                      'Rs.${NumberFormat('#,###.##').format(netAmount)}',
                      netAmount >= 0 ? PdfColors.green : PdfColors.red,
                    ),
                  ),
                ],
              ),
            ),

            // Transaction count
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text(
                'Total Transactions: ${transactions.length}',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),

            // Transactions table
            if (transactions.isNotEmpty) ...[
              pw.Text(
                'Transaction Details',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildPdfTransactionTable(transactions),
            ] else
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'No transactions found for the selected period',
                  style: const pw.TextStyle(
                      fontSize: 14, color: PdfColors.grey600),
                ),
              ),
          ];
        },
      ),
    );

    // Save and share PDF
    final bytes = await pdf.save();

    final filename =
        'VakhariaForex_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    if (kIsWeb) {
      DownloadUtils.downloadPdf(bytes, filename);
    } else {
      await DownloadUtils.downloadPdf(bytes, filename);
    }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'VakhariaForex',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Transaction Report',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _buildPdfSummaryBox(String title, String value, PdfColor color) {
    // Use more accessible colors with better contrast
    final PdfColor backgroundColor;
    final PdfColor borderColor;
    final PdfColor titleColor;
    final PdfColor valueColor;

    if (color == PdfColors.green) {
      backgroundColor =
          const PdfColor.fromInt(0xFFE8F5E8); // Light green background
      borderColor = const PdfColor.fromInt(0xFF2D5A2D); // Dark green border
      titleColor = const PdfColor.fromInt(0xFF1B4332); // Very dark green text
      valueColor = const PdfColor.fromInt(0xFF2D5A2D); // Dark green for value
    } else if (color == PdfColors.red) {
      backgroundColor =
          const PdfColor.fromInt(0xFFFDE8E8); // Light red background
      borderColor = const PdfColor.fromInt(0xFF8B0000); // Dark red border
      titleColor = const PdfColor.fromInt(0xFF800000); // Maroon text
      valueColor = const PdfColor.fromInt(0xFF8B0000); // Dark red for value
    } else {
      backgroundColor =
          const PdfColor.fromInt(0xFFE3F2FD); // Light blue background
      borderColor = const PdfColor.fromInt(0xFF1565C0); // Dark blue border
      titleColor = const PdfColor.fromInt(0xFF0D47A1); // Very dark blue text
      valueColor = const PdfColor.fromInt(0xFF1565C0); // Dark blue for value
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              color: titleColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTransactionTable(List<Transaction> transactions) {
    // Define columns based on visibility settings
    final columns = <pw.TableColumnWidth>[];
    final headers = <String>[];

    // Always show basic columns with proper widths for original field names
    columns.addAll([
      const pw.FlexColumnWidth(1.0), // Date
      const pw.FlexColumnWidth(
          1.4), // Transaction Type - increased for full text
      const pw.FlexColumnWidth(1.2), // Sub Type
      const pw.FlexColumnWidth(1.1), // Amount
      const pw.FlexColumnWidth(0.8), // Currency
      const pw.FlexColumnWidth(0.9), // Rate
      const pw.FlexColumnWidth(1.3), // INR Amount
    ]);

    headers.addAll([
      'Date',
      'Transaction Type',
      'Sub Type',
      'Amount',
      'Currency',
      'Rate',
      'INR Amount'
    ]);

    // Add optional columns
    if (_showCustomerDealer) {
      columns.add(const pw.FlexColumnWidth(1.6));
      headers.add('Name');
    }

    if (_showNotes) {
      columns.add(const pw.FlexColumnWidth(2.2));
      headers.add('Notes');
    }

    return pw.Table(
      columnWidths: Map.fromIterables(
        List.generate(columns.length, (i) => i),
        columns,
      ),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: headers
              .map((header) => _buildPdfCell(
                    header,
                    isHeader: true,
                    textStyle: pw.TextStyle(
                      fontSize: 9, // Reduced back to 9 for headers to fit
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ))
              .toList(),
        ),

        // Data rows
        ...transactions.map((transaction) {
          final cells = <pw.Widget>[];

          // Basic cells
          cells.addAll([
            _buildPdfCell(DateFormat('dd/MM/yy').format(transaction.timestamp)),
            _buildPdfCell(
              transaction.type.name.toUpperCase(),
              backgroundColor: transaction.type == TransactionType.sale
                  ? const PdfColor.fromInt(0xFFE8F5E8)
                  : const PdfColor.fromInt(0xFFFDE8E8),
              textColor: transaction.type == TransactionType.sale
                  ? const PdfColor.fromInt(0xFF1B4332)
                  : const PdfColor.fromInt(0xFF800000),
            ),
            _buildPdfCell(transaction.subType.name.toUpperCase()),
            _buildPdfCell(NumberFormat('#,###.##').format(transaction.amount)),
            _buildPdfCell(transaction.currency),
            _buildPdfCell(
                NumberFormat('#.##').format(transaction.conversionRate)),
            _buildPdfCell(
              'Rs.${NumberFormat('#,###.##').format(transaction.amountInINR)}',
              textStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: transaction.type == TransactionType.sale
                    ? const PdfColor.fromInt(0xFF1B4332)
                    : const PdfColor.fromInt(0xFF800000),
              ),
            ),
          ]);

          // Optional cells
          if (_showCustomerDealer) {
            cells.add(_buildPdfCell(
              transaction.customerName ?? transaction.dealerName ?? '-',
            ));
          }

          if (_showNotes) {
            cells.add(_buildPdfCell(
              transaction.notes ?? '-',
              maxLines: 2,
            ));
          }

          return pw.TableRow(children: cells);
        }).toList(),
      ],
    );
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool isHeader = false,
    pw.TextStyle? textStyle,
    PdfColor? backgroundColor,
    PdfColor? textColor,
    int maxLines = 1,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 5, vertical: 7), // Increased padding
      color: backgroundColor,
      child: pw.Text(
        text,
        style: textStyle ??
            pw.TextStyle(
              fontSize: isHeader ? 10 : 9, // Increased from 9:8
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color:
                  textColor ?? (isHeader ? PdfColors.grey800 : PdfColors.black),
            ),
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  void _showDeleteConfirmation(String range) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $range Transactions'),
        content: Text(
            'Are you sure you want to delete all transactions from $range? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteTransactions(range);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransactions(String range) async {
    try {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      await provider.deleteTransactionsByRange(range);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$range transactions deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditTransactionDialog(Transaction transaction) {
    final formKey = GlobalKey<FormState>();
    final amountController =
        TextEditingController(text: transaction.amount.toString());
    final rateController =
        TextEditingController(text: transaction.conversionRate.toString());
    final customerDealerController = TextEditingController(
      text: transaction.customerName ?? transaction.dealerName ?? '',
    );
    final notesController =
        TextEditingController(text: transaction.notes ?? '');

    TransactionType selectedType = transaction.type;
    TransactionSubType selectedSubType = transaction.subType;
    String selectedCurrency = transaction.currency;
    DateTime selectedDate = transaction.timestamp;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<TransactionType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: TransactionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionSubType>(
                    value: selectedSubType,
                    decoration: const InputDecoration(labelText: 'Sub Type'),
                    items: TransactionSubType.values.map((subType) {
                      return DropdownMenuItem(
                        value: subType,
                        child: Text(subType.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSubType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: Transaction.availableCurrencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCurrency = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: rateController,
                    decoration:
                        const InputDecoration(labelText: 'Conversion Rate'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter conversion rate';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: customerDealerController,
                    decoration: InputDecoration(
                      labelText: selectedType == TransactionType.sale
                          ? 'Customer Name'
                          : 'Dealer Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(amountController.text);
                  final rate = double.parse(rateController.text);

                  final updatedTransaction = transaction.copyWith(
                    type: selectedType,
                    subType: selectedSubType,
                    amount: amount,
                    currency: selectedCurrency,
                    conversionRate: rate,
                    amountInINR: amount * rate,
                    timestamp: selectedDate,
                    customerName: selectedType == TransactionType.sale
                        ? customerDealerController.text
                        : null,
                    dealerName: selectedType == TransactionType.purchase
                        ? customerDealerController.text
                        : null,
                    notes: notesController.text.isNotEmpty
                        ? notesController.text
                        : null,
                  );

                  await Provider.of<TransactionProvider>(context, listen: false)
                      .updateTransaction(updatedTransaction);

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTransactionDialog(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this transaction?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transaction.type.name.toUpperCase()} - ${transaction.subType.name.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('Amount: ${transaction.amount} ${transaction.currency}'),
                  Text(
                      'INR: Rs.${NumberFormat('#,###.##').format(transaction.amountInINR)}'),
                  Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(transaction.timestamp)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Provider.of<TransactionProvider>(context, listen: false)
                  .deleteTransaction(transaction.id);

              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getActiveFilterDescription() {
    List<String> filters = [];

    if (_startDate != null && _endDate != null) {
      // Check if it matches a quick filter
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (_startDate!.isAtSameMomentAs(today) &&
          _endDate!.isAtSameMomentAs(today
              .add(const Duration(days: 1))
              .subtract(const Duration(milliseconds: 1)))) {
        filters.add('Today');
      } else if (_isQuickFilterActive('This Week')) {
        filters.add('This Week');
      } else if (_isQuickFilterActive('This Month')) {
        filters.add('This Month');
      } else if (_isQuickFilterActive('Last 7 Days')) {
        filters.add('Last 7 Days');
      } else if (_isQuickFilterActive('Last 30 Days')) {
        filters.add('Last 30 Days');
      } else {
        filters.add(
            '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}');
      }
    } else if (_startDate != null) {
      filters.add('From: ${DateFormat('dd/MM/yyyy').format(_startDate!)}');
    } else if (_endDate != null) {
      filters.add('To: ${DateFormat('dd/MM/yyyy').format(_endDate!)}');
    }

    if (_filterType != null ||
        _filterSubType != null ||
        _filterCurrency != null ||
        _filterCustomerDealer != null ||
        _minAmount != null ||
        _maxAmount != null) {
      filters.add('Advanced Filters');
    }

    return filters.isEmpty ? 'All Transactions' : filters.join(', ');
  }

  bool _hasActiveFieldFilters() {
    return _filterType != null ||
        _filterSubType != null ||
        _filterCurrency != null ||
        _filterCustomerDealer != null ||
        _minAmount != null ||
        _maxAmount != null;
  }

  void _showAdvancedFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filterType = null;
                              _filterSubType = null;
                              _filterCurrency = null;
                              _filterCustomerDealer = null;
                              _minAmount = null;
                              _maxAmount = null;
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filter content
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterSection(
                        'Transaction Type',
                        DropdownButtonFormField<TransactionType>(
                          value: _filterType,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select transaction type',
                          ),
                          items: TransactionType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _filterType = value;
                            });
                          },
                        ),
                      ),
                      _buildFilterSection(
                        'Sub Type',
                        DropdownButtonFormField<TransactionSubType>(
                          value: _filterSubType,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select sub type',
                          ),
                          items: TransactionSubType.values.map((subType) {
                            return DropdownMenuItem(
                              value: subType,
                              child: Text(subType.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _filterSubType = value;
                            });
                          },
                        ),
                      ),
                      _buildFilterSection(
                        'Currency',
                        DropdownButtonFormField<String>(
                          value: _filterCurrency,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select currency',
                          ),
                          items: [
                            'USD',
                            'EUR',
                            'GBP',
                            'AUD',
                            'CAD',
                            'CHF',
                            'JPY',
                            'SEK',
                            'NOK',
                            'DKK',
                            'SGD',
                            'HKD',
                            'NZD',
                            'INR'
                          ].map((currency) {
                            return DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _filterCurrency = value;
                            });
                          },
                        ),
                      ),
                      _buildFilterSection(
                        'Amount Range',
                        Column(
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Minimum Amount',
                                prefixText: '₹ ',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _minAmount = double.tryParse(value);
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Maximum Amount',
                                prefixText: '₹ ',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _maxAmount = double.tryParse(value);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Apply button
              Container(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 24),
      ],
    );
  }

  bool _hasActiveFilters() {
    return _filterType != null ||
        _filterSubType != null ||
        _filterCurrency != null ||
        _minAmount != null ||
        _maxAmount != null ||
        (_filterCustomerDealer != null && _filterCustomerDealer!.isNotEmpty);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or date range',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnToggles() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Text(
            'Show:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 16),
          _buildToggleButton(
            'Name',
            _showCustomerDealer,
            () {
              setState(() {
                _showCustomerDealer = !_showCustomerDealer;
              });
            },
          ),
          const SizedBox(width: 12),
          _buildToggleButton(
            'Notes',
            _showNotes,
            () {
              setState(() {
                _showNotes = !_showNotes;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isVisible, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isVisible
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isVisible
                ? AppTheme.primaryBlue.withOpacity(0.3)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: isVisible ? AppTheme.primaryBlue : AppTheme.textLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isVisible ? AppTheme.primaryBlue : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _exportToCsv,
              icon: const Icon(Icons.file_download),
              label: const Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _exportToPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            icon: const Icon(Icons.delete, color: Colors.red),
            onSelected: (value) {
              final range = value.replaceFirst('delete_', '');
              _showDeleteConfirmation(range);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_Today',
                child: Text('Delete Today'),
              ),
              const PopupMenuItem(
                value: 'delete_This week',
                child: Text('Delete This Week'),
              ),
              const PopupMenuItem(
                value: 'delete_This month',
                child: Text('Delete This Month'),
              ),
              const PopupMenuItem(
                value: 'delete_All',
                child: Text('Delete All'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
