#!/bin/bash

# Frontend directory
FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$FRONTEND_DIR/.env"

echo "🏥 Starting Diabetes&Me Frontend"

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    echo ""
    echo "Please create frontend/.env with:"
    echo "SPOONACULAR_API_KEY=your_key_here"
    echo "OPENAI_API_KEY=your_key_here"
    echo "ENVIRONMENT=development"
    exit 1
fi

# Read .env file and build dart-define arguments
DART_DEFINES=""
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ $key =~ ^[[:space:]]*# ]] && continue
    [[ -z "${key// }" ]] && continue
    
    # Clean up key and value
    key=$(echo "$key" | xargs)  # trim whitespace
    value=$(echo "$value" | xargs | sed 's/^["'"'"']//;s/["'"'"']$//')  # trim quotes
    
    if [ -n "$key" ] && [ -n "$value" ]; then
        DART_DEFINES="$DART_DEFINES --dart-define=$key=$value"
    fi
done < "$ENV_FILE"

# Navigate to frontend directory
cd "$FRONTEND_DIR"

echo "📱 Starting Flutter with environment variables..."
echo "🔧 Dart defines: $DART_DEFINES"
echo ""

# Run Flutter
flutter run $DART_DEFINES