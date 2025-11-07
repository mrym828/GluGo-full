class GlucoseReading {
  final String id;
  final DateTime timestamp;
  final double value;
  final String? trendArrow;
  final String? source;
  final String? mealTiming;
  final String? mood;
  final String? notes;

  GlucoseReading({
    required this.id,
    required this.timestamp,
    required this.value,
    this.trendArrow,
    this.source,
    this.mealTiming,
    this.mood,
    this.notes,
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    return GlucoseReading(
      id: json['id'].toString(),
      timestamp: DateTime.parse(json['timestamp']),
      value: _parseDouble(json['glucose_level'] ?? json['value']),
      trendArrow: json['trend_arrow'],
      source: json['source'],
      mealTiming: json['meal_timing'],
      mood: json['mood'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'glucose_level': value,
      'value': value,
      'trend_arrow': trendArrow,
      'source': source,
      'meal_timing': mealTiming,
      'mood': mood,
      'notes': notes,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  GlucoseReading copyWith({
    String? id,
    DateTime? timestamp,
    double? value,
    String? trendArrow,
    String? source,
    String? mealTiming,
    String? mood,
    String? notes,
  }) {
    return GlucoseReading(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      value: value ?? this.value,
      trendArrow: trendArrow ?? this.trendArrow,
      source: source ?? this.source,
      mealTiming: mealTiming ?? this.mealTiming,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
    );
  }
}