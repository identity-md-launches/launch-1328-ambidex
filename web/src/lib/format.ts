import { formatUnits } from 'viem';

const groupFormatter = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });

/** Formats a token amount in minor units as a whole-number string with group separators plus up to `fractionDigits` decimals. */
export function formatTokenAmount(amount: bigint, decimals: number, fractionDigits = 2): string {
  const raw = formatUnits(amount, decimals);
  const [whole = '0', fraction = ''] = raw.split('.');
  const wholeText = groupFormatter.format(BigInt(whole));
  const trimmed = fraction.slice(0, fractionDigits).replace(/0+$/, '');
  return trimmed ? `${wholeText}.${trimmed}` : wholeText;
}

/** Formats a small decimal ratio (such as a price) with enough significant digits to be meaningful. */
export function formatRatio(value: number): string {
  if (!Number.isFinite(value) || value === 0) return '0';
  if (value >= 1000) return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(value);
  if (value >= 1) return new Intl.NumberFormat('en-US', { maximumFractionDigits: 4 }).format(value);
  return new Intl.NumberFormat('en-US', { maximumSignificantDigits: 4 }).format(value);
}

/** Compact form for very large numbers: 1,000,000,000 → "1B". */
export function formatCompact(value: number): string {
  return new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 2 }).format(value);
}

export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function percentFromPips(feePips: number): string {
  // Uniswap v4 fees are in hundredths of a basis point (1e6 = 100%).
  return `${(feePips / 10_000).toLocaleString('en-US', { maximumFractionDigits: 4 })}%`;
}
