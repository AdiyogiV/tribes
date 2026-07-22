#!/bin/bash

echo "🎯 Optimizing app images for size reduction..."

cd assets/images

# Create backup
mkdir -p backup
cp *.png backup/ 2>/dev/null || true

# Optimize large images (>1MB) more aggressively
echo "📸 Optimizing large images..."

# For images > 1MB, reduce to 50% quality and resize if needed
for img in dhaara7.png dhaara8.png dhaara11.png dhaara12.png; do
  if [ -f "$img" ]; then
    echo "  Optimizing $img..."
    # Get original size
    original_size=$(ls -lh "$img" | awk '{print $5}')
    echo "    Original: $original_size"
    
    # Use ImageMagick to optimize (install with: brew install imagemagick)
    if command -v magick &> /dev/null; then
      # Resize to max 800px width, 70% quality, strip metadata
      magick "$img" -resize 800x800\> -quality 70 -strip "optimized_$img"
      
      # Replace original if optimization worked
      if [ -f "optimized_$img" ]; then
        mv "optimized_$img" "$img"
        new_size=$(ls -lh "$img" | awk '{print $5}')
        echo "    Optimized: $new_size ✅"
      fi
    else
      echo "    ⚠️  ImageMagick not installed. Install with: brew install imagemagick"
    fi
  fi
done

# Optimize smaller images with lighter compression
echo "📷 Optimizing smaller images..."
for img in 2.png icon.png icon_transparent.png user.png placeholder.png error.png logo.png; do
  if [ -f "$img" ]; then
    echo "  Optimizing $img..."
    original_size=$(ls -lh "$img" | awk '{print $5}')
    echo "    Original: $original_size"
    
    if command -v magick &> /dev/null; then
      # 85% quality for smaller images, strip metadata
      magick "$img" -quality 85 -strip "optimized_$img"
      
      if [ -f "optimized_$img" ]; then
        mv "optimized_$img" "$img"
        new_size=$(ls -lh "$img" | awk '{print $5}')
        echo "    Optimized: $new_size ✅"
      fi
    fi
  fi
done

echo ""
echo "🎉 Image optimization complete!"
echo "📊 Size comparison:"
ls -lah *.png | head -10

cd ../..
