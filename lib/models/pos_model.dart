/// Order Item Model (Item in Cart)
class OrderItem {
  final int id;
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? image;
  final String unit; // 'sack', 'kg', or 'unit'

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.image,
    this.unit = 'unit',
  });

  String get cartKey => '${productId}_$unit';

  double get subtotal => price * quantity;
  double get total => subtotal;

  OrderItem copyWith({int? quantity, String? image, String? unit, double? price}) {
    return OrderItem(
      id: id,
      productId: productId,
      productName: productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      image: image ?? this.image,
      unit: unit ?? this.unit,
    );
  }
}

/// Order Model
class Order {
  final List<OrderItem> items;

  Order({required this.items});

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  int get itemCount => totalItems;

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  double get total => subtotal;

  bool containsProduct(String productId, [String? unit]) {
    if (unit != null) {
      return items.any((item) => item.productId == productId && item.unit == unit);
    }
    return items.any((item) => item.productId == productId);
  }

  int quantityFor(String productId, [String? unit]) {
    if (unit != null) {
      for (final item in items) {
        if (item.productId == productId && item.unit == unit) return item.quantity;
      }
      return 0;
    }
    // If unit is not specified, sum all units for that product
    int total = 0;
    for (final item in items) {
      if (item.productId == productId) total += item.quantity;
    }
    return total;
  }

  void addItem(OrderItem item) {
    final existingIndex = items.indexWhere(
      (existing) => existing.productId == item.productId && existing.unit == item.unit,
    );

    if (existingIndex != -1) {
      items[existingIndex] =
          items[existingIndex].copyWith(quantity: items[existingIndex].quantity + item.quantity);
    } else {
      items.add(item);
    }
  }

  void removeItem(String productId, [String? unit]) {
    if (unit != null) {
      items.removeWhere((item) => item.productId == productId && item.unit == unit);
    } else {
      items.removeWhere((item) => item.productId == productId);
    }
  }

  void incrementQuantity(String productId, [String? unit]) {
    final existingIndex = items.indexWhere(
      (existing) => existing.productId == productId && (unit == null || existing.unit == unit),
    );
    if (existingIndex != -1) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + 1,
      );
    }
  }

  void decrementQuantity(String productId, [String? unit]) {
    final existingIndex = items.indexWhere(
      (existing) => existing.productId == productId && (unit == null || existing.unit == unit),
    );
    if (existingIndex != -1) {
      if (items[existingIndex].quantity > 1) {
        items[existingIndex] = items[existingIndex].copyWith(
          quantity: items[existingIndex].quantity - 1,
        );
      } else {
        items.removeAt(existingIndex);
      }
    }
  }

  void updateQuantity(String productId, int quantity, [String? unit]) {
    final existingIndex = items.indexWhere(
      (existing) => existing.productId == productId && (unit == null || existing.unit == unit),
    );
    if (existingIndex != -1) {
      if (quantity <= 0) {
        items.removeAt(existingIndex);
      } else {
        items[existingIndex] = items[existingIndex].copyWith(quantity: quantity);
      }
    }
  }

  void clearOrder() {
    items.clear();
  }
}

/// POS Product Model
class POSProduct {
  final String id;
  final String name;
  final String categoryId;
  final String category;
  final String? image;
  final String description;
  final double price;
  final double? kiloPrice;
  final String? barcode;
  final int units;
  final int sold;
  final DateTime createdAt;
  final bool isArchived;

  POSProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.category,
    this.image,
    required this.description,
    required this.price,
    this.kiloPrice,
    this.barcode,
    required this.units,
    required this.sold,
    DateTime? createdAt,
    this.isArchived = false,
  }) : createdAt = createdAt ?? DateTime.now();

  int get stock => units;

  bool get isFeed {
    final c = category.trim().toLowerCase();
    return c == 'feeds' || c == 'feed';
  }

  bool get isMedicine {
    final c = category.trim().toLowerCase();
    return c == 'medicines' || c == 'medicine';
  }

  bool get hasKiloPrice => kiloPrice != null && kiloPrice! > 0;

  /// Price per kilo set explicitly by the store administrator.
  double get effectiveKiloPrice => kiloPrice ?? 0.0;

  /// Generates an uppercase acronym from a product name (e.g., "PIGROLAC Early Wean SUPERSTART" -> "PEWS").
  static String acronymFromName(String productName) {
    final words = productName
        .trim()
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'PRD';
    final buffer = StringBuffer();
    for (final w in words) {
      buffer.write(w[0].toUpperCase());
    }
    return buffer.toString();
  }

  /// Generates a formatted Acronym + Sequential Sort ID (e.g., "PEWS-001").
  static String formatAcronymId(String productName, {int? sortNumber}) {
    final acronym = acronymFromName(productName);
    if (sortNumber != null && sortNumber > 0) {
      return '$acronym-${sortNumber.toString().padLeft(3, '0')}';
    }
    return acronym;
  }

  /// Returns the display barcode / ID for this product using its acronym and optional sort number.
  String displayAcronymId({int? sortNumber}) {
    return formatAcronymId(name, sortNumber: sortNumber);
  }

  factory POSProduct.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final rawUnits = json['units'];
    final rawSold = json['sold'];
    final rawKiloPrice = json['kilo_price'] ?? json['retail_kilo_price'] ?? json['price_per_kilo'];
    final rawBarcode = json['barcode'] ?? json['sku'];

    return POSProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      categoryId: (json['category_id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      image: (json['image'] ?? json['image_url'] ?? json['img_url'] ?? json['photo_url'])?.toString(),
      description: (json['description'] ?? '').toString(),
      price: rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '0') ?? 0,
      kiloPrice: rawKiloPrice is num
          ? rawKiloPrice.toDouble()
          : (rawKiloPrice != null ? double.tryParse(rawKiloPrice.toString()) : null),
      barcode: rawBarcode?.toString().trim().isNotEmpty == true ? rawBarcode.toString().trim() : null,
      units: rawUnits is num ? rawUnits.toInt() : int.tryParse(rawUnits?.toString() ?? '0') ?? 0,
      sold: rawSold is num ? rawSold.toInt() : int.tryParse(rawSold?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      isArchived: json['is_archived'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'category': category,
      'image': image,
      'description': description,
      'price': price,
      'kilo_price': kiloPrice,
      'barcode': barcode,
      'units': units,
      'sold': sold,
      'created_at': createdAt.toIso8601String(),
      'is_archived': isArchived,
    };
  }
}
