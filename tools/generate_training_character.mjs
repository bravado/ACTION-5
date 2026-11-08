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
  ['UpperArm_L', [16], [-0.4, 0.22, 0]],
  ['UpperArm_R', [17], [0.4, 0.22, 0]],
  ['Hand_L', [], [-0.17, -0.11, 0]],
  ['Hand_R', [], [0.17, -0.11, 0]],
  ['Leg_L', [14], [-0.2, -0.10, 0]],
  ['Leg_R', [15], [0.2, -0.10, 0]],
  ['Foot_L', [], [0, -0.30, -0.04]],
  ['Foot_R', [], [0, -0.30, -0.04]],
  ['BodyMesh', []],
  ['HeadMesh', []],
  // Real knee joints are required to fold the shins underneath the pelvis.
  ['Knee_L', [10], [0, -0.32, 0]],
  ['Knee_R', [11], [0, -0.32, 0]],
  // Elbows preserve existing Hand_L/Hand_R attachment names and sockets.
  ['Elbow_L', [6], [-0.18, -0.23, 0]],
  ['Elbow_R', [7], [0.18, -0.23, 0]],
];
const nodes = definitions.map(([name, children, translation], i) => ({
  name,
  ...(children.length ? { children } : {}),
  ...(translation ? { translation } : {}),
  ...((i === 12 || i === 13) ? { mesh: i - 12, skin: 0 } : {}),
}));
// Parent-first skin ordering: elbow before hand, knee before ankle.
const joints = [1, 2, 3, 4, 5, 16, 17, 6, 7, 8, 9, 14, 15, 10, 11];
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
  // Two genuinely skinned segments per arm; bending Elbow_* changes the
  // FOREARM mesh rather than pivoting a single rigid shoulder-to-hand bar.
  [[-.48, 1.39, 0], [.18, .33, .20], 4, 0],
  [[.48, 1.39, 0], [.18, .33, .20], 5, 0],
  [[-.64, 1.21, 0], [.17, .28, .19], 16, 0],
  [[.64, 1.21, 0], [.17, .28, .19], 17, 0],
  [[-.75, 1.10, -.03], [.22, .20, .22], 6, 2],
  [[.75, 1.10, -.03], [.22, .20, .22], 7, 2],
  // Split each leg into thigh and shin so knees can bend independently.
  [[-.20, .59, 0], [.23, .35, .25], 8, 1],
  [[.20, .59, 0], [.23, .35, .25], 9, 1],
  [[-.20, .27, 0], [.22, .34, .24], 14, 1],
  [[.20, .27, 0], [.22, .34, .24], 15, 1],
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
  // Seven authored poses make the strike readable at a fast tempo:
  // guard -> elbow folds for the windup -> shoulder drives the straightening
  // fist, torso twists into contact -> quick recoil. Right-hand socket stays
  // on Hand_R, while the elbow and forearm actually articulate.
  ['punch', .25, [
    [5, 'X',  [0, -.28, 1.50, 1.28, .65, .18, 0]],
    [17, 'X', [0, -1.05, .16, .27, -.35, -.15, 0]],
    [2, 'Y',  [0, -.14, .20, .16, .08, .02, 0]],
    [4, 'X',  [0, .10, -.20, -.13, 0, .02, 0]],
    [16, 'X', [0, -.30, -.22, -.25, -.10, 0, 0]],
  ]],
  // Anatomically staged front kick: knee lifts/loads FIRST while the shin
  // folds back, then the knee opens and the foot rises/extends toward -Z.
  // Ankle counter-rotates to keep the toe level, with counterbalancing
  // planted leg, torso and elbows; all return to rest before next action.
  ['kick', .333333, [
    [9, 'X',  [0, .88, 1.18, 1.06, .68, .25, 0]],
    [15, 'X', [0, -1.35, -.15, -.20, -.95, -.50, 0]],
    [11, 'X', [0, .52, -.75, -.70, .42, .25, 0]],
    [8, 'X',  [0, -.07, -.15, -.17, -.10, -.05, 0]],
    [14, 'X', [0, -.02, -.10, -.14, -.08, 0, 0]],
    [2, 'X',  [0, -.07, -.16, -.14, -.08, -.03, 0]],
    [5, 'X',  [0, .25, .42, .40, .29, .10, 0]],
    [17, 'X', [0, -.48, -.55, -.55, -.30, -.10, 0]],
    [4, 'X',  [0, .13, .28, .28, .16, .07, 0]],
    [16, 'X', [0, -.26, -.38, -.38, -.20, -.08, 0]],
  ]],
  ['hit', .52, [[2, 'X', [0, -.24, -.42, -.21, 0]]]],
  ['death', 1.4, [[1, 'Z', [0, .17, .8, 1.5, 1.52]]]],
  ['reload', 1, [[5, 'X', [0, .28, .62, .28, 0]]]],
  // Rig faces -Z: positive-X thighs bring the KNEES FORWARD.
  // Negative-X knee flexion folds the SHINS BACK beneath the hips; positive
  // ankle compensation keeps the feet near level. This is an anatomical
  // crouch, not a backward-bending knee or two straight seated legs.
  // Both -loop clips preserve the bend with alternating strides.
  ['crouch-loop', 1.2, [
    [1, 'T', [[0,0.6,0],[0,0.595,0],[0,0.59,0],[0,0.595,0],[0,0.6,0]]],
    [2, 'X', [-0.38,-0.38,-0.38,-0.38,-0.38]],
    [8, 'X', [0.98,0.98,0.98,0.98,0.98]],
    [9, 'X', [0.98,0.98,0.98,0.98,0.98]],
    [14, 'X', [-1.75,-1.75,-1.75,-1.75,-1.75]],
    [15, 'X', [-1.75,-1.75,-1.75,-1.75,-1.75]],
    [10, 'X', [0.78,0.78,0.78,0.78,0.78]],
    [11, 'X', [0.78,0.78,0.78,0.78,0.78]],
    [4, 'X', [0.24,0.24,0.24,0.24,0.24]],
    [5, 'X', [0.24,0.24,0.24,0.24,0.24]],
  ]],
  ['crouch_walk-loop', 0.95, [
    [1, 'T', [[0,0.6,0],[0,0.58,0],[0,0.6,0],[0,0.58,0],[0,0.6,0]]],
    [2, 'X', [-0.38,-0.4,-0.38,-0.36,-0.38]],
    [8, 'X', [0.98,1.12,0.98,0.84,0.98]],
    [9, 'X', [0.98,0.84,0.98,1.12,0.98]],
    [14, 'X', [-1.75,-1.93,-1.75,-1.59,-1.75]],
    [15, 'X', [-1.75,-1.59,-1.75,-1.93,-1.75]],
    [10, 'X', [0.78,0.82,0.78,0.78,0.78]],
    [11, 'X', [0.78,0.78,0.78,0.82,0.78]],
    [4, 'X', [0.2,0.34,0.2,0.08,0.2]],
    [5, 'X', [0.2,0.08,0.2,0.34,0.2]],
  ]],
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
        // The simple idle/locomotion/crouch clips keep five samples; punch
        // and kick use seven for a visible anticipation/contact/recoil arc.
        Array.from({ length: angles.length }, (_, index) =>
          index * length / (angles.length - 1)),
        'SCALAR', 5126, 0, true),
      output: accessor(
        axis === 'T' ? angles.flatMap(position => position)
          : angles.flatMap(a => quaternion(axis, a)),
        axis === 'T' ? 'VEC3' : 'VEC4'),
      interpolation: 'LINEAR',
    });
    channels.push({
      sampler: samplers.length - 1,
      target: { node: bone, path: axis === 'T' ? 'translation' : 'rotation' },
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
