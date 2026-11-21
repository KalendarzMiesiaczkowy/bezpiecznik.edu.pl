#!/usr/bin/env python3
"""Usage: slice.py <gallery.png> <out-prefix> [y0 y1 ...pairs in logical px]
Without pairs: prints the content height. Crops are in logical px (image is 2x)."""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
bg = im.getpixel((2, im.height - 2))
if len(sys.argv) <= 3:
    y = im.height - 1
    while y > 0 and all(im.getpixel((x, y)) == bg for x in range(0, im.width, 8)):
        y -= 4
    print('content height (logical):', y // 2)
else:
    a = list(map(int, sys.argv[3:]))
    for i in range(0, len(a), 2):
        out = f'{sys.argv[2]}-{i // 2 + 1}.png'
        im.crop((0, a[i] * 2, im.width, a[i + 1] * 2)).save(out)
        print(out)
