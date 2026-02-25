#!/bin/bash
# Double-click launcher for FastWeather webapp

cd "$(dirname "$0")/webapp"
exec ./start-server.sh
