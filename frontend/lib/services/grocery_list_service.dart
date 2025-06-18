import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // For Supabase insertion (without id, let database generate it)
  Map<String, dynamic> toSupabaseInsert(String userId) {
    return {
      'user_id': userId,
      'name': name,
      'category': category,
      'is_completed': isCompleted,
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

  // Factory for Supabase data
  factory GroceryItem.fromSupabase(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      isCompleted: json['is_completed'] ?? false,
      addedAt: DateTime.parse(json['created_at']),
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
  static final _supabase = Supabase.instance.client;

  static Future<String?> _getUserId() async {
    final user = _supabase.auth.currentUser;
    return user?.id;
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
    try {
      final userId = await _getUserId();
      if (userId == null) {
        debugPrint('Error: User not logged in');
        return;
      }

      // Check if ingredient already exists
      final existingItem = await _supabase
          .from('grocery_list_items')
          .select()
          .eq('user_id', userId)
          .ilike('name', ingredient)
          .maybeSingle();

      if (existingItem == null) {
        // Add new item
        final newItem = GroceryItem(
          id: '', // Will be generated by database
          name: ingredient,
          category: _categorizeIngredient(ingredient),
          addedAt: DateTime.now(),
        );

        await _supabase
            .from('grocery_list_items')
            .insert(newItem.toSupabaseInsert(userId));

        debugPrint('✅ Added $ingredient to grocery list');
      } else {
        debugPrint('⚠️ $ingredient already exists in grocery list');
      }
    } catch (e) {
      debugPrint('❌ Error adding to grocery list: $e');
      rethrow;
    }
  }

  static Future<void> removeFromGroceryList(String itemId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;

      await _supabase
          .from('grocery_list_items')
          .delete()
          .eq('id', itemId)
          .eq('user_id', userId);

      debugPrint('✅ Removed item from grocery list');
    } catch (e) {
      debugPrint('❌ Error removing from grocery list: $e');
      rethrow;
    }
  }

  static Future<void> toggleItemCompleted(String itemId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;

      // Get current item to toggle its status
      final currentItem = await _supabase
          .from('grocery_list_items')
          .select('is_completed')
          .eq('id', itemId)
          .eq('user_id', userId)
          .single();

      final newStatus = !(currentItem['is_completed'] ?? false);

      await _supabase
          .from('grocery_list_items')
          .update({'is_completed': newStatus})
          .eq('id', itemId)
          .eq('user_id', userId);

      debugPrint('✅ Toggled item completion status');
    } catch (e) {
      debugPrint('❌ Error toggling item completion: $e');
      rethrow;
    }
  }

  static Future<List<GroceryItem>> getGroceryList() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return [];

      final response = await _supabase
          .from('grocery_list_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map<GroceryItem>((item) => GroceryItem.fromSupabase(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching grocery list: $e');
      return [];
    }
  }

  static Future<void> clearCompletedItems() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;

      await _supabase
          .from('grocery_list_items')
          .delete()
          .eq('user_id', userId)
          .eq('is_completed', true);

      debugPrint('✅ Cleared completed items');
    } catch (e) {
      debugPrint('❌ Error clearing completed items: $e');
      rethrow;
    }
  }

  static Future<void> clearAllItems() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;

      await _supabase
          .from('grocery_list_items')
          .delete()
          .eq('user_id', userId);

      debugPrint('✅ Cleared all items');
    } catch (e) {
      debugPrint('❌ Error clearing all items: $e');
      rethrow;
    }
  }

  static Map<String, List<GroceryItem>> groupByCategory(List<GroceryItem> items) {
    final Map<String, List<GroceryItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }
}