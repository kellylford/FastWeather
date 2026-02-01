#!/bin/bash
# Webapp integrity checker - run before committing webapp changes

echo "🔍 Checking webapp integrity..."

# Check for required dialog elements
dialogs=("alert-details-dialog" "historical-weather-dialog" "precipitation-nowcast-dialog" "weather-around-me-dialog")
missing=0

for dialog in "${dialogs[@]}"; do
    if ! grep -q "id=\"$dialog\"" webapp/index.html; then
        echo "❌ Missing dialog: $dialog"
        missing=$((missing + 1))
    fi
done

# Check for required settings elements  
if ! grep -q "list-view-style" webapp/index.html; then
    echo "❌ Missing list-view-style setting"
    missing=$((missing + 1))
fi

# Check JavaScript references match HTML IDs
echo ""
echo "Checking JavaScript → HTML consistency..."
js_refs=$(grep -o 'getElementById([^)]*' webapp/app.js | cut -d"'" -f2 | sort -u)
html_ids=$(grep -o 'id="[^"]*"' webapp/index.html | cut -d'"' -f2 | sort -u)

orphaned=0
while IFS= read -r id; do
    # Skip dynamic IDs (contain variables)
    if [[ "$id" == *'$'* ]] || [[ "$id" == *'+'* ]]; then
        continue
    fi
    
    if ! echo "$html_ids" | grep -q "^$id$"; then
        echo "⚠️  JavaScript references missing ID: $id"
        orphaned=$((orphaned + 1))
    fi
done <<< "$js_refs"

echo ""
if [ $missing -eq 0 ] && [ $orphaned -eq 0 ]; then
    echo "✅ All checks passed!"
    exit 0
else
    echo "❌ Found $missing missing dialogs and $orphaned orphaned references"
    echo "   Review changes before committing"
    exit 1
fi
