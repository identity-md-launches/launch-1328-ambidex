// Recomputes the canonical ABI hash of src/abi/AmbidexToken.ts and compares it with
// the hash recorded for the deployed contract (TOKEN.abiHash in src/config.ts).
// Canonical form: JSON with object keys sorted recursively, keccak256 of the UTF-8 bytes.
//
//   node scripts/verify-abi.mjs
//
// Optionally pass a Foundry artifact to also check that the committed ABI equals a fresh build:
//
//   node scripts/verify-abi.mjs ../out/AmbidexToken.sol/AmbidexToken.json

import { readFileSync } from 'node:fs';
import { keccak256, toBytes } from 'viem';
import { ambidexTokenAbi } from '../src/abi/AmbidexToken.ts';
import { TOKEN } from '../src/config.ts';

export function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    const out = {};
    for (const key of Object.keys(value).sort()) out[key] = sortKeys(value[key]);
    return out;
  }
  return value;
}

export function canonicalAbiHash(abi) {
  return keccak256(toBytes(JSON.stringify(sortKeys(abi)))).slice(2);
}

const computed = canonicalAbiHash(ambidexTokenAbi);
let ok = computed === TOKEN.abiHash;
console.log(`committed ABI hash  ${computed}`);
console.log(`launch record hash  ${TOKEN.abiHash}`);
console.log(ok ? 'ABI matches the launch record.' : 'ABI DOES NOT MATCH the launch record.');

const artifactPath = process.argv[2];
if (artifactPath) {
  const artifact = JSON.parse(readFileSync(artifactPath, 'utf8'));
  const fresh = canonicalAbiHash(artifact.abi);
  const same = fresh === computed;
  console.log(`foundry artifact    ${fresh} ${same ? '(same as committed ABI)' : '(DIFFERS from committed ABI)'}`);
  ok = ok && same;
}

process.exit(ok ? 0 : 1);
