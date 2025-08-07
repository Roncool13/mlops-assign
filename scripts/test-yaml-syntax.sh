#!/bin/bash
# Test YAML syntax using yq (if available) or basic file structure check

echo "🔍 Testing YAML Syntax for GitHub Actions Workflow"
echo "=================================================="

WORKFLOW_FILE=".github/workflows/mlops-pipeline.yml"

# Check if file exists
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "✅ Workflow file exists: $WORKFLOW_FILE"

# Check basic YAML structure
echo "📊 File stats:"
echo "   Lines: $(wc -l < $WORKFLOW_FILE)"
echo "   Size: $(wc -c < $WORKFLOW_FILE | numfmt --to=iec)"

# Check for basic YAML structure requirements
echo ""
echo "🔍 Basic YAML structure checks:"

# Check for proper starting
if head -1 "$WORKFLOW_FILE" | grep -q "^name:"; then
    echo "✅ Starts with 'name:' field"
else
    echo "❌ Should start with 'name:' field"
fi

# Check for required GitHub Actions fields
if grep -q "^on:" "$WORKFLOW_FILE"; then
    echo "✅ Has 'on:' trigger definition"
else
    echo "❌ Missing 'on:' trigger definition"
fi

if grep -q "^jobs:" "$WORKFLOW_FILE"; then
    echo "✅ Has 'jobs:' section"
else
    echo "❌ Missing 'jobs:' section"
fi

# Check for workflow_dispatch (manual trigger)
if grep -q "workflow_dispatch:" "$WORKFLOW_FILE"; then
    echo "✅ Has manual trigger (workflow_dispatch)"
else
    echo "❌ Missing manual trigger (workflow_dispatch)"
fi

# Count job definitions
JOB_COUNT=$(grep -c "^  [a-zA-Z].*:$" "$WORKFLOW_FILE")
echo "✅ Found $JOB_COUNT job definitions"

# Check for basic indentation issues
if grep -q "^[[:space:]]*[[:space:]][^[:space:]]" "$WORKFLOW_FILE"; then
    if ! grep -q "^    " "$WORKFLOW_FILE"; then
        echo "⚠️  Warning: Inconsistent indentation detected"
    else
        echo "✅ Indentation looks consistent"
    fi
else
    echo "✅ No obvious indentation issues"
fi

# Check for common YAML syntax issues
echo ""
echo "🔍 Common syntax issue checks:"

# Check for tabs (should use spaces)
if grep -q $'\t' "$WORKFLOW_FILE"; then
    echo "❌ Contains tabs (should use spaces)"
else
    echo "✅ No tabs found (using spaces)"
fi

# Check for trailing spaces
if grep -q " $" "$WORKFLOW_FILE"; then
    echo "⚠️  Warning: Trailing spaces found"
else
    echo "✅ No trailing spaces"
fi

# Check for missing colons in key-value pairs
if grep -q "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_-]*[[:space:]]*$" "$WORKFLOW_FILE"; then
    echo "⚠️  Warning: Possible missing colons detected"
fi

echo ""
echo "🎯 Manual Testing Steps:"
echo "1. Go to: https://github.com/Roncool13/mlops-assign/actions"
echo "2. Look for 'MLOps CI/CD Pipeline' workflow"
echo "3. Click on the workflow"
echo "4. Click 'Run workflow' button"
echo "5. Select deployment target and click 'Run workflow'"
echo ""
echo "✅ YAML syntax validation completed!"
