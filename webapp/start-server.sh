#!/bin/bash
# Start FastWeather webapp local server on Mac

cd "$(dirname "$0")"

echo "🌤️  Starting FastWeather local server..."
echo "📍 Server will run at: http://localhost:8000"
echo "🛑 Press Ctrl+C to stop"
echo ""

# Check if port 8000 is already in use
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8000 is already in use"
    echo "   Kill existing process? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        lsof -ti:8000 | xargs kill -9
        echo "   Process killed"
    else
        echo "   Using alternative port 8001..."
        PORT=8001
    fi
else
    PORT=8000
fi

# Open browser after short delay
(sleep 2 && open "http://localhost:${PORT}") &

# Start Python HTTP server
python3 -m http.server ${PORT}
