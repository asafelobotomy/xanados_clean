#!/usr/bin/env python3
"""
Create a simple PNG icon without external dependencies
"""

def create_simple_png_icon():
    """Create a simple PNG using basic drawing"""
    # Create a simple 256x256 PNG icon data manually
    # This is a very basic approach using raw PNG data
    
    import struct
    import zlib
    
    width, height = 256, 256
    
    # Create RGBA pixel data - simple blue circle with white X
    pixels = []
    center_x, center_y = width // 2, height // 2
    radius = 100
    
    for y in range(height):
        row = []
        for x in range(width):
            # Distance from center
            dx = x - center_x
            dy = y - center_y
            distance = (dx*dx + dy*dy) ** 0.5
            
            if distance <= radius:
                # Inside circle - blue background
                r, g, b, a = 23, 147, 209, 255
                
                # Add white X
                if (abs(dx - dy) < 8 and abs(dx) < 60) or (abs(dx + dy) < 8 and abs(dx) < 60):
                    r, g, b, a = 255, 255, 255, 255
                    
            else:
                # Outside circle - transparent
                r, g, b, a = 0, 0, 0, 0
            
            row.extend([r, g, b, a])
        pixels.extend(row)
    
    # Convert to bytes
    pixel_data = bytes(pixels)
    
    # Create PNG file
    def write_png(filename, width, height, pixel_data):
        def write_chunk(f, chunk_type, data):
            f.write(struct.pack('>I', len(data)))
            f.write(chunk_type)
            f.write(data)
            crc = zlib.crc32(chunk_type + data) & 0xffffffff
            f.write(struct.pack('>I', crc))
        
        with open(filename, 'wb') as f:
            # PNG signature
            f.write(b'\x89PNG\r\n\x1a\n')
            
            # IHDR chunk
            ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
            write_chunk(f, b'IHDR', ihdr)
            
            # IDAT chunk - compress pixel data
            compressor = zlib.compressobj()
            png_data = b''
            for y in range(height):
                # Filter type 0 (None) for each row
                row_data = b'\x00' + pixel_data[y * width * 4:(y + 1) * width * 4]
                png_data += compressor.compress(row_data)
            png_data += compressor.flush()
            
            write_chunk(f, b'IDAT', png_data)
            
            # IEND chunk
            write_chunk(f, b'IEND', b'')
    
    write_png('xanados_icon.png', width, height, pixel_data)
    print("Simple PNG icon created: xanados_icon.png")

if __name__ == "__main__":
    create_simple_png_icon()
