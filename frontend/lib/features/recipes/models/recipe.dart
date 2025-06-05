import 'package:uuid/uuid.dart';

class Recipe {
  final int id;
  final String title;
  final String image;
  final int carbs;
  final int sugar;
  final int calories;
  final String category;
  final String cuisine;
  final List<String> ingredients;
  final List<String> instructions;

  Recipe({
    required this.id,
    required this.title,
    required this.image,
    required this.carbs,
    required this.sugar,
    required this.calories,
    required this.category,
    required this.cuisine,
    required this.ingredients,
    required this.instructions,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'],
      image: json['image'],
      carbs: json['carbs'] is int ? json['carbs'] : int.tryParse(json['carbs'].toString()) ?? 0,
      sugar: json['sugar'] is int ? json['sugar'] : int.tryParse(json['sugar'].toString()) ?? 0,
      calories: json['calories'] is int ? json['calories'] : int.tryParse(json['calories'].toString()) ?? 0,
      category: json['category'],
      cuisine: json['cuisine'] ?? 'American', // Default to American if not provided
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'carbs': carbs,
      'sugar': sugar,
      'calories': calories,
      'category': category,
      'cuisine': cuisine,
      'ingredients': ingredients,
      'instructions': instructions,
    };
  }
}