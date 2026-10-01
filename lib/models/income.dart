class Income {
  final int? id;
  final double amount;
  final String note; // e.g. 'Allowance from Mom', optional
  final DateTime date;

  Income({this.id, required this.amount, this.note = '', required this.date});

  Income copyWith({int? id, double? amount, String? note, DateTime? date}) {
    return Income(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'],
      amount: map['amount'],
      note: map['note'] as String? ?? '',
      date: DateTime.parse(map['date']),
    );
  }
}
