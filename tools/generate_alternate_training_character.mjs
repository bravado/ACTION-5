// ACTION-5 original alternate-rig fixture generator (MIT).
// Run after generate_training_character.mjs. This is deliberately a different
// imported .glb with renamed bones, mesh nodes and animation clips; the test
// uses only SkeletonProfile mappings, never a custom engine-code branch.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const inputPath = 'demo/assets/action5_training_character.glb';
const outputPath = 'tests/fixtures/alternate_training_character.glb';
const boneNames = {
  Rig: 'AlternateRig',
  Hips: 'Pelvis',
  Spine: 'Torso',
  Head: 'Skull',
  UpperArm_L: 'UpperL',
  UpperArm_R: 'UpperR',
  Hand_L: 'Grip_L',
  Hand_R: 'Grip_R',
  Leg_L: 'Thigh_L',
  Leg_R: 'Thigh_R',
  Foot_L: 'Toe_L',
  Foot_R: 'Toe_R',
  Knee_L: 'KneeAlternate_L',
  Knee_R: 'KneeAlternate_R',
  BodyMesh: 'AlternateBody',
  HeadMesh: 'AlternateHead',
};
const clipNames = {
  idle: 'rest', walk: 'stride', run: 'sprint', punch: 'jab',
  kick: 'boot', hit: 'flinch', death: 'collapse', reload: 'rearm',
  'crouch-loop': 'squat-loop', 'crouch_walk-loop': 'squat_stride-loop',
};

const original = readFileSync(inputPath);
if (original.readUInt32LE(0) !== 0x46546c67 ||
    original.readUInt32LE(4) !== 2 ||
    original.readUInt32LE(16) !== 0x4e4f534a) {
  throw Error('Expected the original generated binary glTF v2');
}
const jsonLength = original.readUInt32LE(12);
const binOffset = 20 + jsonLength;
if (original.readUInt32LE(binOffset + 4) !== 0x004e4942) {
  throw Error('Original model is missing the binary buffer');
}
const binaryLength = original.readUInt32LE(binOffset);
const binary = original.subarray(binOffset + 8, binOffset + 8 + binaryLength);
const model = JSON.parse(original.subarray(20, binOffset).toString('utf8'));

for (const node of model.nodes) {
  if (boneNames[node.name]) node.name = boneNames[node.name];
}
for (const mesh of model.meshes) {
  if (boneNames[mesh.name]) mesh.name = boneNames[mesh.name];
}
for (const animation of model.animations) {
  if (!clipNames[animation.name]) throw Error('Unmapped source clip: ' + animation.name);
  animation.name = clipNames[animation.name];
}
model.skins[0].name = 'AlternateHumanoid';
// Distinguish the fixture visually; both are original MIT assets.
model.materials[0].pbrMetallicRoughness.baseColorFactor = [0.78, 0.27, 0.66, 1];
model.asset.generator = 'ACTION-5 alternate rig regression fixture';
model.asset.copyright = 'Original MIT-licensed model replacement fixture 2026';

let json = Buffer.from(JSON.stringify(model), 'utf8');
const jsonPadding = (4 - json.length % 4) % 4;
if (jsonPadding) json = Buffer.concat([json, Buffer.alloc(jsonPadding, 0x20)]);
const output = Buffer.alloc(12 + 8 + json.length + 8 + binary.length);
output.writeUInt32LE(0x46546c67, 0);
output.writeUInt32LE(2, 4);
output.writeUInt32LE(output.length, 8);
output.writeUInt32LE(json.length, 12);
output.writeUInt32LE(0x4e4f534a, 16);
json.copy(output, 20);
const outBinOffset = 20 + json.length;
output.writeUInt32LE(binary.length, outBinOffset);
output.writeUInt32LE(0x004e4942, outBinOffset + 4);
binary.copy(output, outBinOffset + 8);

mkdirSync('tests/fixtures', { recursive: true });
writeFileSync(outputPath, output);
console.log('Wrote', outputPath, output.length, 'bytes;',
  model.skins[0].joints.length, 'renamed bones and',
  model.animations.map(a => a.name).join(', '), 'clips');
