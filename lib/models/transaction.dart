enum TransactionType { sale, purchase }

enum TransactionSubType { public, bulk, dealer }

class Transaction {
  final String id;
  final TransactionType type;
  final TransactionSubType subType;
  final double amount;
  final String currency;
  final double conversionRate;
  final double amountInINR;
  final DateTime timestamp;
  final String? customerName;
  final String? dealerName;
  final String? notes;

  Transaction({
    required this.id,
    required this.type,
    required this.subType,
    required this.amount,
    required this.currency,
    required this.conversionRate,
    required this.amountInINR,
    required this.timestamp,
    this.customerName,
    this.dealerName,
    this.notes,
  });

  // Available currencies
  static const List<String> availableCurrencies = [
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
    'INR',
  ];

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'subType': subType.name,
      'amount': amount,
      'currency': currency,
      'conversionRate': conversionRate,
      'amountInINR': amountInINR,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'customerName': customerName,
      'dealerName': dealerName,
      'notes': notes,
    };
  }

  // Create from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    try {
      return Transaction(
        id: json['id'] ?? '',
        type: TransactionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TransactionType.sale,
        ),
        subType: TransactionSubType.values.firstWhere(
          (e) => e.name == json['subType'],
          orElse: () => TransactionSubType.public,
        ),
        amount: (json['amount'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'USD',
        conversionRate: (json['conversionRate'] ?? 1.0).toDouble(),
        amountInINR: (json['amountInINR'] ?? 0).toDouble(),
        timestamp: json['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
            : DateTime.now(),
        customerName: json['customerName'],
        dealerName: json['dealerName'],
        notes: json['notes'],
      );
    } catch (e) {
      print('Error parsing transaction JSON: $e');
      print('JSON data: $json');
      // Return a default transaction if parsing fails
      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: TransactionType.sale,
        subType: TransactionSubType.public,
        amount: 0,
        currency: 'USD',
        conversionRate: 1.0,
        amountInINR: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  // Copy with method for updates
  Transaction copyWith({
    String? id,
    TransactionType? type,
    TransactionSubType? subType,
    double? amount,
    String? currency,
    double? conversionRate,
    double? amountInINR,
    DateTime? timestamp,
    String? customerName,
    String? dealerName,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      conversionRate: conversionRate ?? this.conversionRate,
      amountInINR: amountInINR ?? this.amountInINR,
      timestamp: timestamp ?? this.timestamp,
      customerName: customerName ?? this.customerName,
      dealerName: dealerName ?? this.dealerName,
      notes: notes ?? this.notes,
    );
  }
}
