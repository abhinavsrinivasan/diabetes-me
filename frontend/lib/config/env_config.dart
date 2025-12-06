class EnvConfig {
  // Production API keys (hardcoded for App Store release)
  static const String _prodSpoonacularKey = 'dd6b4d10cbf0480c8c0e6fc7f5e9a317';
  static const String _prodOpenaiKey = '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';
  static const String _prodSupabaseUrl = 'https://abdckgwrcuzjlmspcdqy.supabase.co';
  static const String _prodSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiZGNrZ3dyY3V6amxtc3BjZHF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyMzQ0NjEsImV4cCI6MjA2NDgxMDQ2MX0.G3ryMaTA45K8tahH5RV30cStLDJdHT88sciLlN2dMvA';

  // Load from dart-define (for development) or use production keys
  static const String spoonacularApiKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
    defaultValue: _prodSpoonacularKey, // Falls back to production key
  );

  static const String openaiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: _prodOpenaiKey, // Falls back to production key
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _prodSupabaseUrl, // Falls back to production URL
  );

  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: _prodSupabaseKey, // Falls back to production key
  );

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'production',
  );

  // Helper getters
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get hasSpoonacularKey => spoonacularApiKey.isNotEmpty;
  static bool get hasOpenAIKey => openaiApiKey.isNotEmpty;

  // Validation method (simplified for production)
  static void validateApiKeys() {
    if (isDevelopment) {
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
    // In production, keys are hardcoded so no validation needed
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
