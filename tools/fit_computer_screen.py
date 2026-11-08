"""Calibrate the HI3D main glass from mesh geometry and its green texture region.

Run with Python + numpy on macOS; sips decodes the embedded JPEG locally.
The generated profile is in source-model coordinates, so placement/scaling remain editable.
"""
import json
import struct
import subprocess
import tempfile
from collections import deque
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'models/hi3d/computer.glb'
raw = SOURCE.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
gltf = json.loads(raw[20:20 + length])
binary = memoryview(raw)[28 + length:]
primitive = gltf['meshes'][0]['primitives'][0]

def accessor(index):
    item = gltf['accessors'][index]
    view = gltf['bufferViews'][item['bufferView']]
    dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[item['componentType']]
    width = {'VEC3': 3, 'VEC2': 2, 'SCALAR': 1}[item['type']]
    return np.frombuffer(binary, dtype=dtype, count=item['count'] * width,
                         offset=view.get('byteOffset', 0) + item.get('byteOffset', 0)).reshape(-1, width)

positions = accessor(primitive['attributes']['POSITION'])
uvs = accessor(primitive['attributes']['TEXCOORD_0'])
texture_index = gltf['materials'][primitive['material']]['pbrMetallicRoughness']['baseColorTexture']['index']
image_index = gltf['textures'][texture_index]['source']
view = gltf['bufferViews'][gltf['images'][image_index]['bufferView']]
with tempfile.TemporaryDirectory(prefix='computer_glass_') as temporary:
    jpg, bmp = Path(temporary) / 'albedo.jpg', Path(temporary) / 'albedo.bmp'
    jpg.write_bytes(binary[view['byteOffset']:view['byteOffset'] + view['byteLength']])
    subprocess.run(['sips', '-s', 'format', 'bmp', str(jpg), '--out', str(bmp)], check=True, capture_output=True)
    bitmap = bmp.read_bytes()
    offset = struct.unpack_from('<I', bitmap, 10)[0]
    width, height = struct.unpack_from('<ii', bitmap, 18)
    bits = struct.unpack_from('<H', bitmap, 28)[0]
    stride = ((width * bits + 31) // 32) * 4
    image = np.frombuffer(bitmap, np.uint8, count=stride * abs(height), offset=offset).reshape(abs(height), stride)
    image = image[:, :width * (bits // 8)].reshape(abs(height), width, bits // 8)[:, :, :3][:, :, ::-1]
    if height > 0:
        image = image[::-1]
    colors = image[np.clip((uvs[:, 1] * abs(height)).astype(int), 0, abs(height) - 1),
                   np.clip((uvs[:, 0] * width).astype(int), 0, width - 1)].astype(float)

mask = ((positions[:, 2] > .085) & (positions[:, 1] > -.17)
        & (colors[:, 1] > colors[:, 0] * 1.18) & (colors[:, 1] > colors[:, 2] * 1.01))
points = positions[mask].astype(float)
# Keep the largest projected component, excluding the circular meter below the screen.
width, height = 512, 400
ix = np.clip(((points[:, 0] + .35) / .75 * width).astype(int), 0, width - 1)
iy = np.clip(((.18 - points[:, 1]) / .48 * height).astype(int), 0, height - 1)
occupied = np.zeros((height, width), bool)
occupied[iy, ix] = True
expanded = occupied.copy()
for dy in range(-2, 3):
    for dx in range(-2, 3):
        expanded |= np.roll(occupied, (dy, dx), (0, 1))
labels = np.zeros((height, width), int)
sizes = []
for cy, cx in zip(*np.where(expanded)):
    if labels[cy, cx]:
        continue
    label, count = len(sizes) + 1, 0
    queue = deque([(cy, cx)])
    labels[cy, cx] = label
    while queue:
        yy, xx = queue.popleft()
        count += 1
        for dy, dx in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
            ny, nx = yy + dy, xx + dx
            if 0 <= ny < height and 0 <= nx < width and expanded[ny, nx] and not labels[ny, nx]:
                labels[ny, nx] = label
                queue.append((ny, nx))
    sizes.append(count)
points = points[labels[iy, ix] == int(np.argmax(sizes)) + 1]
assert len(points) > 10000, 'Not enough main-glass samples; inspect the model before fitting.'

def convex_hull(xy):
    ordered = sorted(set(map(tuple, xy)))
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for point in ordered:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(ordered):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return np.array(lower[:-1] + upper[:-1])

outline = convex_hull(points[:, :2])
minimum, maximum = outline.min(0), outline.max(0)
center_xy = (minimum + maximum) * .5
size_xy = maximum - minimum
x, y = points[:, 0], points[:, 1]
design = np.array([np.ones(len(x)), x, y, x * x, x * y, y * y]).T
keep = np.ones(len(x), bool)
for _ in range(5):
    coefficients = np.linalg.lstsq(design[keep], points[keep, 2], rcond=None)[0]
    residual = points[:, 2] - design @ coefficients
    keep = abs(residual) < max(.003, np.percentile(abs(residual), 85))

def depth(x, y):
    return float(np.array([1, x, y, x * x, x * y, y * y]) @ coefficients)

center = np.array([*center_xy, depth(*center_xy)])
# A narrow inset keeps the generated glass/rim seam visible. Curved depth follows the glass.
outline = center_xy + (outline - center_xy) * .994
segments = np.linalg.norm(np.roll(outline, -1, axis=0) - outline, axis=1)
arc = np.r_[0, np.cumsum(segments)]
samples = np.linspace(0, arc[-1], 96, endpoint=False)
resampled = []
for sample in samples:
    index = min(len(outline) - 1, np.searchsorted(arc, sample, side='right') - 1)
    weight = (sample - arc[index]) / segments[index]
    resampled.append(outline[index] * (1 - weight) + outline[(index + 1) % len(outline)] * weight)
outline = np.array(resampled)
vertices, texture_uvs = [], []

def add_vertex(point):
    vertex = np.array([*point, depth(*point) + .004]) - center
    vertices.append(np.round(vertex, 7).tolist())
    uv = (point - minimum) / size_xy
    texture_uvs.append([round(float(uv[0]), 7), round(float(1 - uv[1]), 7)])

add_vertex(center_xy)
rings = 12
for ring in range(1, rings + 1):
    for point in outline:
        add_vertex(center_xy + (point - center_xy) * ring / rings)
indices = []
for index in range(96):
    indices.extend([0, 1 + (index + 1) % 96, 1 + index])
for ring in range(1, rings):
    inner, outer = 1 + (ring - 1) * 96, 1 + ring * 96
    for index in range(96):
        following = (index + 1) % 96
        indices.extend([inner + index, outer + following, outer + index,
                        inner + index, inner + following, outer + following])
profile = {'source': 'res://models/hi3d/computer.glb', 'sample_count': len(points),
           'center': center.tolist(), 'size': size_xy.tolist(),
           'outline': [texture_uvs[1 + (rings - 1) * 96 + i] for i in range(96)],
           'vertices': vertices, 'uvs': texture_uvs, 'indices': indices,
           'median_fit_error': float(np.median(abs(residual)))}
output = ROOT / 'art/screen/hi3d_computer.json'
output.write_text(json.dumps(profile, separators=(',', ':')) + '\n')
print(f'{output}: {len(points)} samples, {len(vertices)} vertices, {len(indices) // 3} triangles')
