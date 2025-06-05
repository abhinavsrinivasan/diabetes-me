#!/bin/bash

# Same as run_dev.sh but with --release flag
FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$FRONTEND_DIR/.env"

echo "🏥 Starting Diabetes&Me Frontend (Production Mode)"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    exit 1
fi

DART_DEFINES=""
while IFS='=' read -r key value || [ -n "$key" ]; do
    [[ $key =~ ^[[:space:]]*# ]] && continue
    [[ -z "${key// }" ]] && continue
    
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs | sed 's/^["'"'"']//;s/["'"'"']$//')
    
    if [ -n "$key" ] && [ -n "$value" ]; then
        DART_DEFINES="$DART_DEFINES --dart-define=$key=$value"
    fi
done < "$ENV_FILE"

cd "$FRONTEND_DIR"

echo "📱 Starting Flutter in RELEASE mode..."
flutter run --release $DART_DEFINES