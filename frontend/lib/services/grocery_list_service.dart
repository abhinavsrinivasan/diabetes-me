import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class GroceryItem {
  final String id;
  final String name;
  final String category;
  final bool isCompleted;
  final DateTime addedAt;

  GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    this.isCompleted = false,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isCompleted': isCompleted,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      isCompleted: json['isCompleted'] ?? false,
      addedAt: DateTime.parse(json['addedAt']),
    );
  }

  GroceryItem copyWith({
    String? id,
    String? name,
    String? category,
    bool? isCompleted,
    DateTime? addedAt,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

class GroceryListService {
  static Future<String?> _getUserEmail() async {
    final token = await AuthService().getToken();
    if (token == null) return null;
    
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        return payload['sub'] ?? payload['email'];
      }
    } catch (e) {
      debugPrint('Error decoding token: $e');
    }
    return null;
  }

  static String _categorizeIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();
    
    if (lower.contains('chicken') || lower.contains('beef') || lower.contains('pork') || 
        lower.contains('turkey') || lower.contains('fish') || lower.contains('salmon') ||
        lower.contains('tofu') || lower.contains('tempeh')) {
      return 'Protein';
    } else if (lower.contains('milk') || lower.contains('cheese') || lower.contains('yogurt') ||
               lower.contains('butter') || lower.contains('cream') || lower.contains('egg')) {
      return 'Dairy & Eggs';
    } else if (lower.contains('apple') || lower.contains('banana') || lower.contains('berry') ||
               lower.contains('orange') || lower.contains('grape') || lower.contains('lemon') ||
               lower.contains('lime') || lower.contains('avocado')) {
      return 'Fruits';
    } else if (lower.contains('lettuce') || lower.contains('spinach') || lower.contains('broccoli') ||
               lower.contains('carrot') || lower.contains('onion') || lower.contains('tomato') ||
               lower.contains('pepper') || lower.contains('cucumber') || lower.contains('zucchini') ||
               lower.contains('mushroom') || lower.contains('celery') || lower.contains('kale')) {
      return 'Vegetables';
    } else if (lower.contains('bread') || lower.contains('rice') || lower.contains('pasta') ||
               lower.contains('cereal') || lower.contains('oats') || lower.contains('flour') ||
               lower.contains('quinoa') || lower.contains('barley')) {
      return 'Grains & Bread';
    } else if (lower.contains('oil') || lower.contains('vinegar') || lower.contains('sauce') ||
               lower.contains('salt') || lower.contains('pepper') || lower.contains('spice') ||
               lower.contains('herb') || lower.contains('garlic') || lower.contains('ginger') ||
               lower.contains('cumin') || lower.contains('paprika') || lower.contains('basil') ||
               lower.contains('oregano') || lower.contains('thyme') || lower.contains('rosemary')) {
      return 'Condiments & Spices';
    } else if (lower.contains('nuts') || lower.contains('almond') || lower.contains('walnut') ||
               lower.contains('peanut') || lower.contains('cashew') || lower.contains('pistachio') ||
               lower.contains('seeds') || lower.contains('chia') || lower.contains('flax')) {
      return 'Nuts & Seeds';
    } else if (lower.contains('beans') || lower.contains('lentil') || lower.contains('chickpea') ||
               lower.contains('kidney bean') || lower.contains('black bean') || lower.contains('pinto')) {
      return 'Legumes';
    } else {
      return 'Other';
    }
  }

  static Future<void> addToGroceryList(String ingredient) async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    final groceryListJson = prefs.getString('grocery_list_$userEmail');
    List<GroceryItem> groceryList = [];

    if (groceryListJson != null) {
      final List<dynamic> groceryData = json.decode(groceryListJson);
      groceryList = groceryData.map((item) => GroceryItem.fromJson(item)).toList();
    }

    // Check if ingredient already exists
    final existingIndex = groceryList.indexWhere(
      (item) => item.name.toLowerCase() == ingredient.toLowerCase()
    );

    if (existingIndex == -1) {
      // Add new item
      final newItem = GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: ingredient,
        category: _categorizeIngredient(ingredient),
        addedAt: DateTime.now(),
      );
      groceryList.add(newItem);

      await prefs.setString(
        'grocery_list_$userEmail',
        json.encode(groceryList.map((item) => item.toJson()).toList()),
      );
    }
  }

  static Future<void> removeFromGroceryList(String itemId) async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    final groceryListJson = prefs.getString('grocery_list_$userEmail');
    if (groceryListJson == null) return;

    final List<dynamic> groceryData = json.decode(groceryListJson);
    List<GroceryItem> groceryList = groceryData.map((item) => GroceryItem.fromJson(item)).toList();

    groceryList.removeWhere((item) => item.id == itemId);

    await prefs.setString(
      'grocery_list_$userEmail',
      json.encode(groceryList.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> toggleItemCompleted(String itemId) async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    final groceryListJson = prefs.getString('grocery_list_$userEmail');
    if (groceryListJson == null) return;

    final List<dynamic> groceryData = json.decode(groceryListJson);
    List<GroceryItem> groceryList = groceryData.map((item) => GroceryItem.fromJson(item)).toList();

    final index = groceryList.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      groceryList[index] = groceryList[index].copyWith(
        isCompleted: !groceryList[index].isCompleted,
      );

      await prefs.setString(
        'grocery_list_$userEmail',
        json.encode(groceryList.map((item) => item.toJson()).toList()),
      );
    }
  }

  static Future<List<GroceryItem>> getGroceryList() async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final groceryListJson = prefs.getString('grocery_list_$userEmail');
    if (groceryListJson == null) return [];

    final List<dynamic> groceryData = json.decode(groceryListJson);
    return groceryData.map((item) => GroceryItem.fromJson(item)).toList();
  }

  static Future<void> clearCompletedItems() async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    final groceryListJson = prefs.getString('grocery_list_$userEmail');
    if (groceryListJson == null) return;

    final List<dynamic> groceryData = json.decode(groceryListJson);
    List<GroceryItem> groceryList = groceryData.map((item) => GroceryItem.fromJson(item)).toList();

    groceryList.removeWhere((item) => item.isCompleted);

    await prefs.setString(
      'grocery_list_$userEmail',
      json.encode(groceryList.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> clearAllItems() async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('grocery_list_$userEmail');
  }

  static Map<String, List<GroceryItem>> groupByCategory(List<GroceryItem> items) {
    final Map<String, List<GroceryItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }
}