class InventoryRowAdapter {
  const InventoryRowAdapter();

  Map<String, dynamic> normalize(Map<String, dynamic> row, {required String sourceTable}) {
    final image = row['image'] ?? row['image_url'] ?? row['img_url'] ?? row['photo_url'];
    if (sourceTable == 'inventory_products') {
      final copy = Map<String, dynamic>.from(row);
      if (image != null && (copy['image'] == null || copy['image'].toString().isEmpty)) {
        copy['image'] = image;
      }
      return copy;
    }

    final id = row['id'] ?? row['product_id'] ?? '';
    final name = row['name'] ?? row['product_name'] ?? '';
    final category = row['category'] ?? '';
    final price = row['price'] ?? row['unit_price'] ?? 0;
    final units = row['units'] ?? row['current_stock'] ?? 0;
    final sold = row['sold'] ?? 0;
    final description = row['description'] ?? '';
    final createdAt = row['created_at'];
    final isArchived = row['is_archived'] ?? false;

    return {
      'id': id,
      'name': name,
      'category_id': category.toString().toLowerCase().replaceAll(' ', '_'),
      'category': category,
      'description': description,
      'price': price,
      'units': units,
      'sold': sold,
      'image': image,
      'created_at': createdAt,
      'is_archived': isArchived,
    };
  }
}

List<Map<String, dynamic>> normalizeInventoryRows(
  List<dynamic> rows, {
  required String sourceTable,
}) {
  final adapter = InventoryRowAdapter();
  return rows
      .whereType<Map>()
      .map((row) => adapter.normalize(Map<String, dynamic>.from(row), sourceTable: sourceTable))
      .toList();
}
