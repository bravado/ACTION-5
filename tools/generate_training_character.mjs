// ACTION-5 original reference asset generator (MIT).
// node tools/generate_training_character.mjs
// Produces a deterministic skinned glTF 2.0 binary (.glb) without external
// packages, textures, Blender downloads or proprietary animation clips.
import { mkdirSync, writeFileSync } from 'node:fs';

const outputPath = 'demo/assets/action5_training_character.glb';
const definitions = [
  ['Rig', [1, 12, 13]],
  ['Hips', [2, 8, 9], [0, 0.85, 0]],
  ['Spine', [3, 4, 5], [0, 0.45, 0]],
  ['Head', [], [0, 0.33, 0]],
  ['UpperArm_L', [6], [-0.4, 0.22, 0]],
  ['UpperArm_R', [7], [0.4, 0.22, 0]],
  ['Hand_L', [], [-0.35, -0.34, 0]],
  ['Hand_R', [], [0.35, -0.34, 0]],
  ['Leg_L', [10], [-0.2, -0.10, 0]],
  ['Leg_R', [11], [0.2, -0.10, 0]],
  ['Foot_L', [], [0, -0.62, -0.04]],
  ['Foot_R', [], [0, -0.62, -0.04]],
  ['BodyMesh', []],
  ['HeadMesh', []],
];
const nodes = definitions.map(([name, children, translation], i) => ({
  name,
  ...(children.length ? { children } : {}),
  ...(translation ? { translation } : {}),
  ...(i >= 12 ? { mesh: i - 12, skin: 0 } : {}),
}));
const joints = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
const positions = nodes.map(() => [0, 0, 0]);
function walk(node, parent) {
  const local = nodes[node].translation || [0, 0, 0];
  positions[node] = local.map((value, axis) => value + parent[axis]);
  for (const child of nodes[node].children || []) walk(child, positions[node]);
}
walk(0, [0, 0, 0]);

const bytes = [];
const bufferViews = [];
const accessors = [];
function pack(values, component) {
  const uint16 = component === 5123;
  const data = new ArrayBuffer(values.length * (uint16 ? 2 : 4));
  const view = new DataView(data);
  values.forEach((value, i) => uint16
    ? view.setUint16(i * 2, value, true)
    : view.setFloat32(i * 4, value, true));
  return new Uint8Array(data);
}
function accessor(values, type, component = 5126, target = null, bounds = false) {
  while (bytes.length % 4) bytes.push(0);
  const offset = bytes.length;
  const data = pack(values, component);
  for (const value of data) bytes.push(value);
  bufferViews.push({
    buffer: 0, byteOffset: offset, byteLength: data.length,
    ...(target ? { target } : {}),
  });
  const size = { SCALAR: 1, VEC3: 3, VEC4: 4, MAT4: 16 }[type];
  const result = {
    bufferView: bufferViews.length - 1,
    componentType: component,
    count: values.length / size,
    type,
  };
  if (bounds) {
    const axes = type === 'VEC3' ? 3 : 1;
    result.min = Array.from({ length: axes }, (_, k) =>
      Math.min(...values.filter((_, i) => i % size === k)));
    result.max = Array.from({ length: axes }, (_, k) =>
      Math.max(...values.filter((_, i) => i % size === k)));
  }
  accessors.push(result);
  return accessors.length - 1;
}

const corners = [
  [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
  [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1],
];
const faces = [
  [[0, 0, -1], [0, 3, 2, 1]],
  [[0, 0, 1], [4, 5, 6, 7]],
  [[1, 0, 0], [1, 2, 6, 5]],
  [[-1, 0, 0], [0, 4, 7, 3]],
  [[0, 1, 0], [3, 7, 6, 2]],
  [[0, -1, 0], [0, 1, 5, 4]],
];
function cube(center, size, bone, material) {
  const p = [], normals = [], j = [], weights = [], indices = [];
  let k = 0;
  for (const [normal, quad] of faces) {
    for (const corner of quad) {
      p.push(...corners[corner].map((value, axis) =>
        center[axis] + value * size[axis] / 2));
      normals.push(...normal);
      j.push(joints.indexOf(bone), 0, 0, 0);
      weights.push(1, 0, 0, 0);
    }
    indices.push(k, k + 1, k + 2, k, k + 2, k + 3);
    k += 4;
  }
  return {
    attributes: {
      POSITION: accessor(p, 'VEC3', 5126, 34962, true),
      NORMAL: accessor(normals, 'VEC3', 5126, 34962),
      JOINTS_0: accessor(j, 'VEC4', 5123, 34962),
      WEIGHTS_0: accessor(weights, 'VEC4', 5126, 34962),
    },
    indices: accessor(indices, 'SCALAR', 5123, 34963),
    material, mode: 4,
  };
}
const bodyParts = [
  [[0, .94, 0], [.47, .38, .28], 1, 1],
  [[0, 1.30, 0], [.68, .44, .35], 2, 0],
  [[-.46, 1.20, 0], [.20, .45, .22], 4, 0],
  [[.46, 1.20, 0], [.20, .45, .22], 5, 0],
  [[-.70, .91, 0], [.18, .34, .20], 6, 2],
  [[.70, .91, 0], [.18, .34, .20], 7, 2],
  [[-.20, .49, 0], [.23, .65, .25], 8, 1],
  [[.20, .49, 0], [.23, .65, .25], 9, 1],
  [[-.2, .14, -.09], [.26, .21, .43], 10, 3],
  [[.2, .14, -.09], [.26, .21, .43], 11, 3],
];
const headParts = [
  [[0, 1.67, 0], [.38, .38, .37], 3, 2],
  [[0, 1.68, -.20], [.20, .11, .03], 3, 4],
];
const meshes = [
  { name: 'BodyMesh', primitives: bodyParts.map(part => cube(...part)) },
  { name: 'HeadMesh', primitives: headParts.map(part => cube(...part)) },
];
const colors = [
  [.11, .66, .76, 1], [.13, .24, .34, 1], [.82, .52, .31, 1],
  [.08, .11, .20, 1], [.94, .67, .31, 1],
];
const materials = colors.map(color => ({
  pbrMetallicRoughness: {
    baseColorFactor: color, metallicFactor: 0, roughnessFactor: .82,
  },
}));

const inverse = [];
for (const joint of joints) {
  const [x, y, z] = positions[joint];
  inverse.push(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1);
}
const skins = [{
  name: 'ACTION5Humanoid',
  joints, skeleton: 1,
  inverseBindMatrices: accessor(inverse, 'MAT4'),
}];

const clipDefinitions = [
  ['idle', 1.6, [[2, 'Z', [0, .018, 0, -.018, 0]],
                  [3, 'Y', [0, .04, 0, -.04, 0]]]],
  ['walk', .86, [[4, 'X', [0, .4, 0, -.4, 0]],
                 [5, 'X', [0, -.4, 0, .4, 0]],
                 [8, 'X', [0, -.47, 0, .47, 0]],
                 [9, 'X', [0, .47, 0, -.47, 0]]]],
  ['run', .58, [[4, 'X', [0, .75, 0, -.75, 0]],
                [5, 'X', [0, -.75, 0, .75, 0]],
                [8, 'X', [0, -.8, 0, .8, 0]],
                [9, 'X', [0, .8, 0, -.8, 0]]]],
  ['punch', .64, [[5, 'X', [0, .24, 1.35, .9, 0]],
                  [2, 'Y', [0, .06, .18, .09, 0]]]],
  ['kick', .74, [[9, 'X', [0, .25, 1.12, .8, 0]],
                 [4, 'X', [0, -.15, -.25, -.1, 0]]]],
  ['hit', .52, [[2, 'X', [0, -.24, -.42, -.21, 0]]]],
  ['death', 1.4, [[1, 'Z', [0, .17, .8, 1.5, 1.52]]]],
  ['reload', 1, [[5, 'X', [0, .28, .62, .28, 0]]]],
];
function quaternion(axis, angle) {
  const s = Math.sin(angle / 2), c = Math.cos(angle / 2);
  return axis === 'X' ? [s, 0, 0, c]
    : axis === 'Y' ? [0, s, 0, c] : [0, 0, s, c];
}
const animations = clipDefinitions.map(([name, length, tracks]) => {
  const samplers = [], channels = [];
  for (const [bone, axis, angles] of tracks) {
    samplers.push({
      input: accessor(
        [0, length / 4, length / 2, length * .75, length],
        'SCALAR', 5126, 0, true),
      output: accessor(angles.flatMap(a => quaternion(axis, a)), 'VEC4'),
      interpolation: 'LINEAR',
    });
    channels.push({
      sampler: samplers.length - 1,
      target: { node: bone, path: 'rotation' },
    });
  }
  return { name, samplers, channels };
});
const gltf = {
  asset: {
    version: '2.0',
    generator: 'ACTION-5 original rig builder',
    copyright: 'MIT-licensed original model and clips 2026',
  },
  scene: 0,
  scenes: [{ nodes: [0] }],
  nodes, skins, meshes, materials, animations,
  buffers: [{ byteLength: bytes.length }],
  bufferViews, accessors,
};

const json = Array.from(Buffer.from(JSON.stringify(gltf), 'utf8'));
while (json.length % 4) json.push(32);
while (bytes.length % 4) bytes.push(0);
const length = 12 + 8 + json.length + 8 + bytes.length;
const binary = Buffer.alloc(length);
binary.writeUInt32LE(0x46546c67, 0); // glTF
binary.writeUInt32LE(2, 4);
binary.writeUInt32LE(length, 8);
binary.writeUInt32LE(json.length, 12);
binary.writeUInt32LE(0x4e4f534a, 16); // JSON
Buffer.from(json).copy(binary, 20);
const offset = 20 + json.length;
binary.writeUInt32LE(bytes.length, offset);
binary.writeUInt32LE(0x004e4942, offset + 4); // BIN
Buffer.from(bytes).copy(binary, offset + 8);

mkdirSync('demo/assets', { recursive: true });
writeFileSync(outputPath, binary);
console.log('Wrote', outputPath, binary.length, 'bytes;', joints.length,
  'bones;', animations.map(a => a.name).join(', '));
