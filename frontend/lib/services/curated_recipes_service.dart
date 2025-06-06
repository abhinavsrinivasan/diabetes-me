import 'package:supabase_flutter/supabase_flutter.dart';

class CuratedRecipesService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchAllRecipes() async {
    final response = await _client
        .from('curated_recipes')
        .select()
        .order('id');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchRecipesPage({int page = 1, int pageSize = 20}) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;
    final response = await _client
        .from('curated_recipes')
        .select()
        .order('id')
        .range(from, to);
    return List<Map<String, dynamic>>.from(response);
  }
}
