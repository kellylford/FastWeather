#!/usr/bin/env python3
"""Create placeholder icons for FastWeather PWA"""

from PIL import Image, ImageDraw, ImageFont

def create_icon(size, filename):
    """Create a simple icon with FW text on blue background"""
    # Create image with blue background
    img = Image.new('RGB', (size, size), color='#2563eb')
    draw = ImageDraw.Draw(img)
    
    # Try to use a nice font, fallback to default
    try:
        font_size = int(size * 0.35)
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()
    
    # Draw white "FW" text centered
    text = "FW"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size - text_width) / 2
    y = (size - text_height) / 2 - bbox[1]
    
    draw.text((x, y), text, fill='white', font=font)
    
    # Save
    img.save(filename, 'PNG')
    print(f"✓ Created {filename} ({size}x{size})")

if __name__ == '__main__':
    create_icon(192, 'icon-192.png')
    create_icon(512, 'icon-512.png')
    print("\nPlaceholder icons created successfully!")
    print("You can replace these with your own weather-themed icons later.")
