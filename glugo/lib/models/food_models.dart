class FoodComponent {
  final String name;
  final double carbsG;
  final int quantity;
  final String unit;

  FoodComponent({
    required this.name,
    required this.carbsG,
    required this.quantity,
    required this.unit,
  });

  // Create from JSON
  factory FoodComponent.fromJson(Map<String, dynamic> json) {
    return FoodComponent(
      name: json['name'] ?? 'Unknown',
      carbsG: (json['carbs_g'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      unit: json['unit'] ?? 'serving',
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'carbs_g': carbsG,
      'quantity': quantity,
      'unit': unit,
    };
  }

  // Create a copy with modified values
  FoodComponent copyWith({
    String? name,
    double? carbsG,
    int? quantity,
    String? unit,
  }) {
    return FoodComponent(
      name: name ?? this.name,
      carbsG: carbsG ?? this.carbsG,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}