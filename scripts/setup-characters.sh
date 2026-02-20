#!/bin/bash
# AgentDock Character Image Setup
# Place PNG images in ~/.agentdock/characters/

set -e

CHAR_DIR="$HOME/.agentdock/characters"
mkdir -p "$CHAR_DIR"

echo "=== AgentDock Character Setup ==="
echo ""
echo "Character directory: $CHAR_DIR"
echo ""

# Check existing images
count=$(ls "$CHAR_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -gt "0" ]; then
    echo "Found $count existing images:"
    ls -la "$CHAR_DIR"/*.png
    echo ""
fi

echo "=== Required Images ==="
echo ""
echo "  bear_idle.png      bear_working.png      bear_thinking.png"
echo "  pig_idle.png       pig_working.png       pig_thinking.png"
echo "  cat_idle.png       cat_working.png       cat_thinking.png"
echo ""
echo "Minimum: 3 images (bear_idle.png, pig_idle.png, cat_idle.png)"
echo "App falls back to idle image if status-specific image is missing."
echo ""
echo "Recommended size: 512x512px or 1024x1024px (PNG with transparent background)"
echo ""

echo "=== Image Generation Prompts (Midjourney v6.1) ==="
echo ""
echo "--- Bear (Backend Developer) ---"
echo 'A chubby friendly brown bear character, 3D Pixar animation render style, wearing a dark navy hoodie, sitting at an open laptop, warm studio lighting, white background, full body view, expressive eyes, detailed fur texture --v 6.1 --ar 1:1'
echo ""
echo "--- Pig (Creative Director) ---"
echo 'A cute pink pig character, 3D Pixar animation render style, wearing round glasses and a pink blazer, sitting at a laptop, creative expression, white background, warm studio lighting, full body, smooth skin --v 6.1 --ar 1:1'
echo ""
echo "--- Cat (Tech Researcher) ---"
echo 'An elegant gray silver cat character, 3D Pixar animation render style, wearing a formal gray suit, silver fur, sitting at a laptop, scholarly expression, white background, warm studio lighting, full body, detailed fur --v 6.1 --ar 1:1'
echo ""

echo "=== State Variations (use --cref for consistency) ==="
echo ""
echo "idle:     relaxed posture, slight smile, hands resting"
echo "working:  leaning forward, typing on keyboard, focused expression"
echo "thinking: leaning back, hand on chin, contemplative, looking upward"
echo ""

echo "=== Background Removal ==="
echo ""
echo "Option 1 (Python - recommended):"
echo "  pip install rembg"
echo "  rembg i input.png output.png"
echo ""
echo "Option 2 (Batch all images):"
echo "  for f in $CHAR_DIR/*.png; do rembg i \"\$f\" \"\$f\"; done"
echo ""
echo "Option 3 (Web): https://remove.bg"
echo ""

echo "=== After adding images ==="
echo "Use menu bar: AgentDock > Reload Characters"
echo "Or restart the app."
echo ""

open "$CHAR_DIR"
