// lib/services/barcode_scanner_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NutritionInfo {
  final String productName;
  final String brand;
  final double servingSize;
  final String servingSizeUnit;
  final double calories;
  final double totalCarbs;
  final double sugars;
  final double addedSugars;
  final double fiber;
  final double protein;
  final double fat;
  final double sodium;
  final List<String> ingredients;
  final String imageUrl;

  NutritionInfo({
    required this.productName,
    required this.brand,
    required this.servingSize,
    required this.servingSizeUnit,
    required this.calories,
    required this.totalCarbs,
    required this.sugars,
    required this.addedSugars,
    required this.fiber,
    required this.protein,
    required this.fat,
    required this.sodium,
    required this.ingredients,
    required this.imageUrl,
  });

  // Calculate net carbs (total carbs - fiber)
  double get netCarbs => (totalCarbs - fiber).clamp(0, double.infinity);

  factory NutritionInfo.fromOpenFoodFacts(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    final nutriments = product['nutriments'] ?? {};
    
    return NutritionInfo(
      productName: product['product_name'] ?? 'Unknown Product',
      brand: product['brands'] ?? 'Unknown Brand',
      servingSize: _parseDouble(nutriments['serving_size']) ?? 100.0,
      servingSizeUnit: 'g',
      calories: _parseDouble(nutriments['energy-kcal_100g']) ?? 0.0,
      totalCarbs: _parseDouble(nutriments['carbohydrates_100g']) ?? 0.0,
      sugars: _parseDouble(nutriments['sugars_100g']) ?? 0.0,
      addedSugars: _parseDouble(nutriments['added-sugars_100g']) ?? 0.0,
      fiber: _parseDouble(nutriments['fiber_100g']) ?? 0.0,
      protein: _parseDouble(nutriments['proteins_100g']) ?? 0.0,
      fat: _parseDouble(nutriments['fat_100g']) ?? 0.0,
      sodium: _parseDouble(nutriments['sodium_100g']) ?? 0.0,
      ingredients: _parseIngredients(product['ingredients_text'] ?? ''),
      imageUrl: product['image_front_url'] ?? '',
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> _parseIngredients(String ingredientsText) {
    if (ingredientsText.isEmpty) return [];
    return ingredientsText
        .split(',')
        .map((ingredient) => ingredient.trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toList();
  }
}

enum DiabetesFriendliness {
  friendly,
  caution,
  avoid,
}

class DiabetesRating {
  final DiabetesFriendliness rating;
  final String explanation;
  final List<String> reasons;
  final int score; // 0-100, higher is better

  DiabetesRating({
    required this.rating,
    required this.explanation,
    required this.reasons,
    required this.score,
  });

  String get displayText {
    switch (rating) {
      case DiabetesFriendliness.friendly:
        return 'Diabetes-Friendly';
      case DiabetesFriendliness.caution:
        return 'Use Caution';
      case DiabetesFriendliness.avoid:
        return 'Consider Avoiding';
    }
  }

  String get emoji {
    switch (rating) {
      case DiabetesFriendliness.friendly:
        return '🟢';
      case DiabetesFriendliness.caution:
        return '🟡';
      case DiabetesFriendliness.avoid:
        return '🔴';
    }
  }
}

class ProductScanResult {
  final NutritionInfo nutritionInfo;
  final DiabetesRating diabetesRating;
  final List<AlternativeProduct> alternatives;

  ProductScanResult({
    required this.nutritionInfo,
    required this.diabetesRating,
    required this.alternatives,
  });
}

class AlternativeProduct {
  final String name;
  final String brand;
  final String reason;
  final String imageUrl;

  AlternativeProduct({
    required this.name,
    required this.brand,
    required this.reason,
    required this.imageUrl,
  });
}

class BarcodeScannerService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  
  static Future<ProductScanResult?> scanProduct(String barcode) async {
    try {
      debugPrint('Scanning barcode: $barcode');
      
      // Fetch nutrition info from Open Food Facts
      final nutritionInfo = await _fetchNutritionInfo(barcode);
      if (nutritionInfo == null) {
        debugPrint('No nutrition info found for barcode: $barcode');
        return null;
      }
      
      // Calculate diabetes rating
      final diabetesRating = _calculateDiabetesRating(nutritionInfo);
      
      // Get alternatives (mock data for now - could integrate with recipe database)
      final alternatives = _getAlternatives(nutritionInfo, diabetesRating);
      
      return ProductScanResult(
        nutritionInfo: nutritionInfo,
        diabetesRating: diabetesRating,
        alternatives: alternatives,
      );
      
    } catch (e) {
      debugPrint('Error scanning product: $e');
      return null;
    }
  }
  
  static Future<NutritionInfo?> _fetchNutritionInfo(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_openFoodFactsBaseUrl/$barcode.json'),
        headers: {
          'User-Agent': 'DiabetesAndMe/1.0 (Contact: your-email@example.com)',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if product exists
        if (data['status'] != 1) {
          debugPrint('Product not found in Open Food Facts');
          return null;
        }
        
        return NutritionInfo.fromOpenFoodFacts(data);
      } else {
        debugPrint('Failed to fetch nutrition info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching nutrition info: $e');
      return null;
    }
  }
  
  static DiabetesRating _calculateDiabetesRating(NutritionInfo info) {
    int score = 100;
    List<String> reasons = [];
    String explanation = '';
    
    // Analyze sugars (per 100g)
    if (info.sugars > 20) {
      score -= 40;
      reasons.add('High sugar content (${info.sugars.toStringAsFixed(1)}g per 100g)');
    } else if (info.sugars > 10) {
      score -= 20;
      reasons.add('Moderate sugar content (${info.sugars.toStringAsFixed(1)}g per 100g)');
    } else if (info.sugars < 5) {
      reasons.add('Low sugar content (${info.sugars.toStringAsFixed(1)}g per 100g)');
    }
    
    // Analyze total carbs (per 100g)
    if (info.totalCarbs > 45) {
      score -= 30;
      reasons.add('High carbohydrate content (${info.totalCarbs.toStringAsFixed(1)}g per 100g)');
    } else if (info.totalCarbs > 30) {
      score -= 15;
      reasons.add('Moderate carbohydrate content (${info.totalCarbs.toStringAsFixed(1)}g per 100g)');
    }
    
    // Analyze fiber (positive factor)
    if (info.fiber >= 5) {
      score += 10;
      reasons.add('Good fiber content (${info.fiber.toStringAsFixed(1)}g per 100g)');
    } else if (info.fiber < 2) {
      score -= 10;
      reasons.add('Low fiber content (${info.fiber.toStringAsFixed(1)}g per 100g)');
    }
    
    // Analyze net carbs
    if (info.netCarbs > 40) {
      score -= 25;
      reasons.add('High net carbs (${info.netCarbs.toStringAsFixed(1)}g per 100g)');
    }
    
    // Check for added sugars
    if (info.addedSugars > 15) {
      score -= 20;
      reasons.add('Contains added sugars (${info.addedSugars.toStringAsFixed(1)}g per 100g)');
    }
    
    // Analyze protein (positive factor for blood sugar stability)
    if (info.protein >= 10) {
      score += 5;
      reasons.add('Good protein content helps stabilize blood sugar');
    }
    
    // Determine rating based on score
    DiabetesFriendliness rating;
    if (score >= 70) {
      rating = DiabetesFriendliness.friendly;
      explanation = 'This product has characteristics that make it suitable for people managing diabetes. It\'s relatively low in sugar and/or high in fiber.';
    } else if (score >= 40) {
      rating = DiabetesFriendliness.caution;
      explanation = 'This product should be consumed mindfully. Consider portion sizes and pair with protein or healthy fats to minimize blood sugar impact.';
    } else {
      rating = DiabetesFriendliness.avoid;
      explanation = 'This product is high in sugar and/or carbohydrates with little fiber, which may cause significant blood sugar spikes.';
    }
    
    return DiabetesRating(
      rating: rating,
      explanation: explanation,
      reasons: reasons,
      score: score.clamp(0, 100),
    );
  }
  
  static List<AlternativeProduct> _getAlternatives(NutritionInfo info, DiabetesRating rating) {
    // Mock alternatives - in a real app, you might query your recipe database
    // or a curated list of diabetes-friendly alternatives
    
    if (rating.rating == DiabetesFriendliness.friendly) {
      return []; // No alternatives needed for friendly products
    }
    
    // Sample alternatives based on product category (you could make this smarter)
    List<AlternativeProduct> alternatives = [];
    
    if (info.productName.toLowerCase().contains('bar') || 
        info.productName.toLowerCase().contains('snack')) {
      alternatives.addAll([
        AlternativeProduct(
          name: 'KIND Dark Chocolate Nuts & Sea Salt',
          brand: 'KIND',
          reason: 'Lower added sugar, higher fiber and protein',
          imageUrl: '',
        ),
        AlternativeProduct(
          name: 'RXBAR Peanut Butter',
          brand: 'RXBAR',
          reason: 'No added sugar, made with whole food ingredients',
          imageUrl: '',
        ),
      ]);
    } else if (info.productName.toLowerCase().contains('cereal')) {
      alternatives.addAll([
        AlternativeProduct(
          name: 'Steel Cut Oats',
          brand: 'Generic',
          reason: 'Lower glycemic index, higher fiber',
          imageUrl: '',
        ),
        AlternativeProduct(
          name: 'Fiber One Original',
          brand: 'General Mills',
          reason: 'Very high fiber, lower net carbs',
          imageUrl: '',
        ),
      ]);
    }
    
    return alternatives;
  }
  
  // Helper method to format nutrition values for display
  static String formatNutritionValue(double value, String unit) {
    if (value == 0) return '0$unit';
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$unit';
  }
}