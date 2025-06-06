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

# Add Supabase env vars if not present
if ! grep -q 'SUPABASE_URL' "$ENV_FILE"; then
    echo 'SUPABASE_URL=your_supabase_url_here' >> "$ENV_FILE"
fi
if ! grep -q 'SUPABASE_SERVICE_ROLE_KEY' "$ENV_FILE"; then
    echo 'SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here' >> "$ENV_FILE"
fi

# Export Supabase env vars for Python scripts
export SUPABASE_URL=$(grep SUPABASE_URL "$ENV_FILE" | cut -d '=' -f2-)
export SUPABASE_SERVICE_ROLE_KEY=$(grep SUPABASE_SERVICE_ROLE_KEY "$ENV_FILE" | cut -d '=' -f2-)

# Activate Python virtual environment if it exists
if [ -d "$FRONTEND_DIR/../diabetes_env" ]; then
    echo "🐍 Activating Python virtual environment..."
    source "$FRONTEND_DIR/../diabetes_env/bin/activate"
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