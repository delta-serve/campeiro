#!/bin/bash
# health_check.sh - Verificação de saúde do serviço

BASE_URL="http://localhost:4195"

echo "=== Bento Health Check ==="

# Ping
if curl -sf "$BASE_URL/ping" > /dev/null; then
    echo "✓ Service is UP"
else
    echo "✗ Service is DOWN"
    exit 1
fi

# Ready
if curl -sf "$BASE_URL/ready" > /dev/null; then
    echo "✓ Service is READY"
else
    echo "⚠ Service is NOT READY"
fi

# Streams
streams=$(curl -s "$BASE_URL/streams" | jq -r 'keys | length' 2>/dev/null)
echo "Streams loaded: $streams"

exit 0
