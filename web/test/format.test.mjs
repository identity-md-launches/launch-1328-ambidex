import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatCompact, formatRatio, formatTokenAmount, percentFromPips, shortenAddress } from '../src/lib/format.ts';

test('formatTokenAmount groups digits and trims zero fractions', () => {
  assert.equal(formatTokenAmount(1_000_000_000n * 10n ** 18n, 18), '1,000,000,000');
  assert.equal(formatTokenAmount(1234n * 10n ** 18n + 5n * 10n ** 17n, 18, 4), '1,234.5');
  assert.equal(formatTokenAmount(20_000_000n * 10n ** 18n + 342n, 18, 4), '20,000,000');
  assert.equal(formatTokenAmount(0n, 18), '0');
});

test('formatRatio adapts precision to magnitude', () => {
  assert.equal(formatRatio(387511.9), '387,512');
  assert.equal(formatRatio(2.5), '2.5');
  assert.equal(formatRatio(0.000002580565881103), '0.000002581');
  assert.equal(formatRatio(0), '0');
});

test('formatCompact and percentFromPips', () => {
  assert.equal(formatCompact(1_000_000_000), '1B');
  assert.equal(percentFromPips(12500), '1.25%');
  assert.equal(percentFromPips(3000), '0.3%');
});

test('shortenAddress keeps both ends', () => {
  assert.equal(shortenAddress('0x81b56b0da7bf1b553123a55da538515aa6e06941'), '0x81b5…6941');
});
