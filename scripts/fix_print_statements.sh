#!/bin/bash

# Script to replace print() statements with appropriate AppLogger calls
# Based on context analysis

echo "🔧 Replacing print statements with AppLogger..."

# Navigate to services directory
cd lib/services

# Create a comprehensive replacement function
replace_prints() {
    for file in $(find . -name "*.dart" -type f); do
        echo "Processing: $file"
        
        # Replace error-related prints with AppLogger.e
        sed -i '' \
        -e 's/print('\''Error[^'\'']*/AppLogger.e('"'"'/g' \
        -e 's/print("Error[^"]*/AppLogger.e("/g' \
        -e 's/print('\''Failed[^'\'']*/AppLogger.e('"'"'/g' \
        -e 's/print("Failed[^"]*/AppLogger.e("/g' \
        \
        -e 's/print('\''Warning[^'\'']*/AppLogger.w('"'"'/g' \
        -e 's/print("Warning[^"]*/AppLogger.w("/g' \
        -e 's/print('\''Invalid[^'\'']*/AppLogger.w('"'"'/g' \
        -e 's/print("Invalid[^"]*/AppLogger.w("/g' \
        \
        -e 's/print('\''Compression failed[^'\'']*/AppLogger.e('"'"'/g' \
        -e 's/print("Compression failed[^"]*/AppLogger.e("/g' \
        -e 's/print('\''Upload[^'\'']*/AppLogger.i('"'"'/g' \
        -e 's/print("Upload[^"]*/AppLogger.i("/g' \
        \
        -e 's/print('\''Updated[^'\'']*/AppLogger.i('"'"'/g' \
        -e 's/print("Updated[^"]*/AppLogger.i("/g' \
        -e 's/print('\''Deleted[^'\'']*/AppLogger.i('"'"'/g' \
        -e 's/print("Deleted[^"]*/AppLogger.i("/g' \
        \
        -e 's/print('\''.*debug[^'\'']*/AppLogger.d('"'"'/g' \
        -e 's/print(".*debug[^"]*/AppLogger.d("/g' \
        \
        -e 's/print('\''[^'\'']*/AppLogger.d('"'"'/g' \
        -e 's/print("[^"]*/AppLogger.d("/g' \
        "$file"
        
        # Add category parameter and close parentheses properly
        sed -i '' \
        -e 's/AppLogger\.\([eidw]\)(\([^)]*\))/AppLogger.\1(\2, category: LogCategory.general)/g' \
        "$file"
    done
}

# Run the replacement
replace_prints

echo "✅ Print statement replacement completed!"

# Count remaining print statements
remaining=$(grep -r "print(" . --include="*.dart" | wc -l)
echo "📊 Remaining print statements: $remaining"

