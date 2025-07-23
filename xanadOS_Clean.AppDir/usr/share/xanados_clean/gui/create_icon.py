#!/usr/bin/env python3
"""
Create an icon for xanadOS Clean using PIL
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    def create_icon():
        # Create a 256x256 image with a gradient background
        size = 256
        image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        
        # Create a circular background with Arch Linux colors
        center = size // 2
        radius = center - 10
        
        # Arch blue gradient
        for i in range(radius):
            alpha = int(255 * (1 - i / radius))
            color = (23, 147, 209, alpha)  # Arch Linux blue
            draw.ellipse([center-radius+i, center-radius+i, 
                         center+radius-i, center+radius-i], fill=color)
        
        # Add gear/maintenance symbol
        gear_radius = radius * 0.6
        gear_points = []
        import math
        
        # Create gear shape
        for i in range(8):
            angle = i * math.pi / 4
            # Outer points
            x1 = center + (gear_radius + 15) * math.cos(angle)
            y1 = center + (gear_radius + 15) * math.sin(angle)
            gear_points.extend([x1, y1])
            
            # Inner points
            angle2 = (i + 0.5) * math.pi / 4
            x2 = center + gear_radius * math.cos(angle2)
            y2 = center + gear_radius * math.sin(angle2)
            gear_points.extend([x2, y2])
        
        # Draw gear
        draw.polygon(gear_points, fill=(255, 255, 255, 200))
        
        # Add center circle
        center_radius = gear_radius * 0.3
        draw.ellipse([center-center_radius, center-center_radius,
                     center+center_radius, center+center_radius], 
                     fill=(255, 255, 255, 255))
        
        # Try to add text
        try:
            font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 24)
        except:
            font = ImageFont.load_default()
        
        # Add "X" in center
        text = "X"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        text_x = center - text_width // 2
        text_y = center - text_height // 2
        draw.text((text_x, text_y), text, fill=(23, 147, 209, 255), font=font)
        
        return image
    
    # Create and save icon
    icon = create_icon()
    icon.save('xanados_icon.png')
    
    # Create different sizes for AppImage
    for size in [16, 32, 48, 64, 128, 256]:
        resized = icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(f'xanados_icon_{size}.png')
    
    print("Icons created successfully!")
    
except ImportError:
    print("PIL not available, creating simple icon...")
    # Create a simple SVG icon as fallback
    svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
    <circle cx="128" cy="128" r="120" fill="#1793D1" stroke="#ffffff" stroke-width="4"/>
    <circle cx="128" cy="128" r="80" fill="none" stroke="#ffffff" stroke-width="8"/>
    <circle cx="128" cy="128" r="40" fill="none" stroke="#ffffff" stroke-width="6"/>
    <text x="128" y="140" font-family="Arial" font-size="48" font-weight="bold" 
          text-anchor="middle" fill="white">X</text>
    <path d="M 128,48 L 138,68 L 158,58 L 148,78 L 168,88 L 148,98 L 158,118 L 138,108 L 128,128 
             L 118,108 L 98,118 L 108,98 L 88,88 L 108,78 L 98,58 L 118,68 Z" 
          fill="white" opacity="0.3"/>
</svg>'''
    
    with open('xanados_icon.svg', 'w', encoding='utf-8') as f:
        f.write(svg_content)
    
    print("SVG icon created as fallback")

def create_simple_icon():
    """Create a simple PNG icon using basic tools"""
    # Create a simple SVG icon as fallback
    svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
    <circle cx="128" cy="128" r="120" fill="#1793D1" stroke="#ffffff" stroke-width="4"/>
    <circle cx="128" cy="128" r="80" fill="none" stroke="#ffffff" stroke-width="8"/>
    <circle cx="128" cy="128" r="40" fill="none" stroke="#ffffff" stroke-width="6"/>
    <text x="128" y="140" font-family="Arial" font-size="48" font-weight="bold" 
          text-anchor="middle" fill="white">X</text>
    <path d="M 128,48 L 138,68 L 158,58 L 148,78 L 168,88 L 148,98 L 158,118 L 138,108 L 128,128 
             L 118,108 L 98,118 L 108,98 L 88,88 L 108,78 L 98,58 L 118,68 Z" 
          fill="white" opacity="0.3"/>
</svg>'''
    
    with open('xanados_icon.svg', 'w', encoding='utf-8') as f:
        f.write(svg_content)
    
    print("SVG icon created")

if __name__ == "__main__":
    create_simple_icon()
