// Product Category Model
class ProductCategory {
  final String id;
  final String name;
  final String icon;

  ProductCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }
}

// Product Model
class Product {
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

  Product({
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
    required this.createdAt,
    this.isArchived = false,
  });

  bool get isFeed {
    final c = category.trim().toLowerCase();
    return c == 'feeds' || c == 'feed';
  }

  bool get hasKiloPrice => kiloPrice != null && kiloPrice! > 0;

  double get effectiveKiloPrice => kiloPrice ?? 0.0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final rawUnits = json['units'];
    final rawSold = json['sold'];
    final rawKiloPrice = json['kilo_price'] ?? json['retail_kilo_price'] ?? json['price_per_kilo'];
    final rawBarcode = json['barcode'] ?? json['sku'];

    return Product(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      categoryId: (json['category_id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      image: (json['image'] ?? json['image_url'])?.toString(),
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
