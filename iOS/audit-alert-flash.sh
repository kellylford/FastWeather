#!/bin/bash
# Alert Flash Detection Audit Script
# Run this to check for potential alert flashing issues

echo "🔍 Scanning for potential alert flash issues..."
echo ""

# Check for alerts with dynamic state references
echo "⚠️  Checking for alerts with dynamic state ($ interpolation)..."
grep -rn "\.alert.*\$" iOS/FastWeather/Views/ 2>/dev/null | grep -v "isPresented" || echo "✅ None found"
echo ""

echo "⚠️  Checking for alerts with .rawValue..."
grep -rn "\.alert.*\.rawValue" iOS/FastWeather/Views/ 2>/dev/null || echo "✅ None found"
echo ""

echo "⚠️  Checking for confirmation dialogs with dynamic state..."
grep -rn "\.confirmationDialog.*\$" iOS/FastWeather/Views/ 2>/dev/null | grep -v "isPresented" || echo "✅ None found"
echo ""

# Check for alerts without flash detection
echo "📊 Checking flash detection coverage..."
alert_count=$(grep -r "\.alert(" iOS/FastWeather/Views/ 2>/dev/null | wc -l | tr -d ' ')
dialog_count=$(grep -r "\.confirmationDialog(" iOS/FastWeather/Views/ 2>/dev/null | wc -l | tr -d ' ')
detection_count=$(grep -r "ALERT FLASH DETECTED" iOS/FastWeather/Views/ 2>/dev/null | wc -l | tr -d ' ')

total=$((alert_count + dialog_count))

echo "Total alerts/dialogs: $total"
echo "Flash detection added: $detection_count"

if [ "$total" -eq "$detection_count" ]; then
    echo "✅ All alerts have flash detection!"
else
    echo "⚠️  Missing flash detection on $((total - detection_count)) alert(s)"
    echo ""
    echo "Alerts without detection:"
    # This is a simplified check - manual review recommended
    grep -rn "\.alert\|\.confirmationDialog" iOS/FastWeather/Views/ 2>/dev/null | grep -v "ALERT FLASH DETECTED"
fi

echo ""
echo "📋 Summary:"
echo "  - Review any items flagged above"
echo "  - Check iOS/ALERT_FLASH_PREVENTION.md for guidelines"
echo "  - Run app and watch console for '⚠️ ALERT FLASH DETECTED' warnings"
echo ""
echo "✨ Audit complete!"
