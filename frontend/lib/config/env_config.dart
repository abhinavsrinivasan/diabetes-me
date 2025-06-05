class EnvConfig {
  // Load from dart-define arguments
  static const String spoonacularApiKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
    defaultValue: '',
  );
  
  static const String openaiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );
  
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  // Helper getters
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get hasSpoonacularKey => spoonacularApiKey.isNotEmpty;
  static bool get hasOpenAIKey => openaiApiKey.isNotEmpty;
  
  // Validation method
  static void validateApiKeys() {
    final missing = <String>[];
    
    if (!hasSpoonacularKey) {
      missing.add('SPOONACULAR_API_KEY');
    }
    
    if (missing.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missing.join(', ')}\n'
        'Please add them to your .env file or run with --dart-define'
      );
    }
  }
  
  // Debug info (development only)
  static void printDebugInfo() {
    if (isDevelopment) {
      print('🔧 Environment: $environment');
      print('🔑 Spoonacular API: ${hasSpoonacularKey ? "✅ Configured" : "❌ Missing"}');
      print('🤖 OpenAI API: ${hasOpenAIKey ? "✅ Configured" : "❌ Missing"}');
    }
  }
}