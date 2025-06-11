import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../utils/theme.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VakhariaForex Dashboard'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<TransactionProvider>(context, listen: false)
                  .loadTransactions();
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          if (transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTodayCommissionCard(transactionProvider),
                const SizedBox(height: 24),
                _buildQuickStatsGrid(transactionProvider),
                const SizedBox(height: 24),
                _buildRecentTransactions(transactionProvider, context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayCommissionCard(TransactionProvider provider) {
    final commission = provider.todayCommission;
    final isPositive = commission >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                .withOpacity(0.1),
            (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                .withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
              .withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                .withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                            .withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                  size: 24,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Today\'s Net',
            style: TextStyle(
              color: AppTheme.textMedium,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${NumberFormat('#,##,###.##').format(commission.abs())}',
              style: TextStyle(
                color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isPositive ? 'Sales > Purchases' : 'Purchases > Sales',
                style: TextStyle(
                  color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid(TransactionProvider provider) {
    final todayTransactions = provider.todayTransactions;
    final todaySales = todayTransactions
        .where((t) => t.type == TransactionType.sale)
        .fold(0.0, (sum, t) => sum + t.amountInINR);
    final todayPurchases = todayTransactions
        .where((t) => t.type == TransactionType.purchase)
        .fold(0.0, (sum, t) => sum + t.amountInINR);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile layout - vertical stacking with better spacing
          return Column(
            children: [
              _buildStatCard(
                'Sales Today',
                '₹${NumberFormat('#,###.##').format(todaySales)}',
                Icons.trending_up,
                AppTheme.successGreen,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Purchases Today',
                '₹${NumberFormat('#,###.##').format(todayPurchases)}',
                Icons.trending_down,
                AppTheme.infoBlue,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Transactions',
                '${todayTransactions.length}',
                Icons.receipt_long,
                AppTheme.accentGold,
              ),
            ],
          );
        } else {
          // Desktop layout - horizontal
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Sales Today',
                  '₹${NumberFormat('#,###.##').format(todaySales)}',
                  Icons.trending_up,
                  AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Purchases Today',
                  '₹${NumberFormat('#,###.##').format(todayPurchases)}',
                  Icons.trending_down,
                  AppTheme.infoBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Transactions',
                  '${todayTransactions.length}',
                  Icons.receipt_long,
                  AppTheme.accentGold,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard(
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
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
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

  Widget _buildRecentTransactions(
      TransactionProvider provider, BuildContext context) {
    final recentTransactions = provider.todayTransactions.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              if (recentTransactions.isNotEmpty)
                TextButton(
                  onPressed: () {
                    // Navigate to Reports screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentTransactions.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text(
                'No transactions today',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 16,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final transaction = recentTransactions[index];
                  return _buildTransactionTile(transaction);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final isPositive = transaction.type == TransactionType.sale;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPositive ? AppTheme.successGreen : AppTheme.errorRed)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transaction.type.name.toUpperCase()} - ${transaction.subType.name.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${NumberFormat('#,###.##').format(transaction.amount)} ${transaction.currency}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat('#,###.##').format(transaction.amountInINR)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(transaction.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
