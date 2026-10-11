import { test } from 'node:test';
import assert from 'node:assert/strict';
import { POOL_ID, sqrtPriceToWad, wadToNumber } from '../src/lib/chain.ts';
import { POOL_KEY, TOKEN, PAIR_TOKEN } from '../src/config.ts';
import { ambidexTokenAbi } from '../src/abi/AmbidexToken.ts';
import { canonicalAbiHash } from '../scripts/verify-abi.mjs';

test('pool key is ordered currency0 < currency1 as Uniswap v4 requires', () => {
  assert.ok(BigInt(POOL_KEY.currency0) < BigInt(POOL_KEY.currency1));
  assert.equal(POOL_KEY.currency0, TOKEN.address);
  assert.equal(POOL_KEY.currency1, PAIR_TOKEN.address);
});

test('pool id is the keccak of the encoded pool key', () => {
  // Independently derived with the same encoding against the live StateView (see test/scratch notes).
  assert.equal(POOL_ID, '0xc531d723d326360eb864c2f2ec194a014b94e169be5ffc84540787378a4f751f');
});

test('sqrtPriceX96 converts to a currency1-per-currency0 price', () => {
  const Q96 = 2n ** 96n;
  assert.equal(sqrtPriceToWad(Q96), 10n ** 18n); // price 1.0
  assert.equal(sqrtPriceToWad(Q96 * 2n), 4n * 10n ** 18n); // sqrt 2 → price 4
  const live = 127273228019710601363790866n; // observed on 2026-10-11
  const wad = sqrtPriceToWad(live);
  assert.ok(Math.abs(wadToNumber(wad) - 0.00000258056588) < 1e-14);
});

test('committed ABI has the public surface of AmbidexToken and matches the launch record hash', () => {
  const names = ambidexTokenAbi.filter((e) => e.type === 'function').map((e) => e.name).sort();
  assert.deepEqual(names, [
    'DECIMALS',
    'NAME',
    'SYMBOL',
    'TOTAL_SUPPLY',
    'allowance',
    'approve',
    'balanceOf',
    'decimals',
    'name',
    'symbol',
    'totalSupply',
    'transfer',
    'transferFrom',
  ]);
  assert.equal(canonicalAbiHash(ambidexTokenAbi), TOKEN.abiHash);
});
