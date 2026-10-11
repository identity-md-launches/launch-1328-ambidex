// Chain facts for the AMBIDEX launch. Every address here is copied from the
// verified launch record (deployment.json) or the network record (network.json)
// that accompanied the assignment; nothing is taken from prose.

import type { Address, Hex } from 'viem';

// The site claims no origin of its own: the export is published wherever the plane pins it
// (an IPFS gateway path or an ENS name), so absolute self-links are produced only at build
// time from VITE_SITE_URL (see vite.config.ts and README, Publish), never hard-coded here.

/**
 * Absolute http(s) URL of a file in the export root, resolved against the page the visitor
 * is actually on (an IPFS gateway path, an ENS name or a plain host). Undefined when the page
 * is not served over http(s), so callers can omit the image rather than hand a wallet a dead link.
 */
export function siteAssetUrl(file: string): string | undefined {
  try {
    const href = new URL(file, document.baseURI).href;
    return /^https?:\/\//.test(href) ? href : undefined;
  } catch {
    return undefined;
  }
}

export const CHAIN = {
  id: 1,
  hexId: '0x1',
  name: 'Ethereum',
  rpcUrls: ['https://ethereum-rpc.publicnode.com', 'https://eth.drpc.org'],
  explorer: 'https://etherscan.io',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
} as const;

export const TOKEN = {
  contract: 'AmbidexToken',
  address: '0x81b56b0da7bf1b553123a55da538515aa6e06941' as Address,
  name: 'AMBIDEX',
  symbol: 'AMBI',
  decimals: 18,
  totalSupply: 1_000_000_000n * 10n ** 18n,
  deployTx: '0x4524a23a50bf0ca398fa9df1f147fb7643f565470a78da3d11eca1cf8e4d4afc' as Hex,
  deployBlock: 26171034,
  // keccak256 of the ABI JSON with object keys sorted, as recorded in the launch record.
  abiHash: '94a29d95f18b1087232bfc83e1f37348582eb2e48a1eb9aed402ff4376e5b6a6',
  sourceCommit: '49eabf75f59a697395fa3d77476c349c2bf0c885',
  repoUrl: 'https://github.com/identity-md-launches/launch-1328-ambidex',
} as const;

export const PAIR_TOKEN = {
  address: '0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7' as Address,
  symbol: 'IMD',
  name: 'Identity.md',
  decimals: 18,
} as const;

/** Uniswap v4 pool key for the AMBI/IMD pool, exactly as the launch recorded it. */
export const POOL_KEY = {
  currency0: TOKEN.address,
  currency1: PAIR_TOKEN.address,
  fee: 12500, // hundredths of a basis point: 1.25%
  tickSpacing: 60,
  hooks: '0x784ff9a3ac5d88a30bfff6f7f2a270161fbe6000' as Address,
} as const;

export const UNISWAP_V4 = {
  poolManager: '0x000000000004444c5dc75cb358380d2e3de08a90' as Address,
  universalRouter: '0x66a9893cc07d91d95644aedd05d03f95e1dba8af' as Address,
  stateView: '0x7ffe42c4a5deea5b0fec41c94c136cf115597227' as Address,
  positionManager: '0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e' as Address,
} as const;

export const SWAP_URL = `https://app.uniswap.org/swap?chain=mainnet&inputCurrency=${PAIR_TOKEN.address}&outputCurrency=${TOKEN.address}`;

export function explorerAddress(address: string): string {
  return `${CHAIN.explorer}/address/${address}`;
}

export function explorerTx(hash: string): string {
  return `${CHAIN.explorer}/tx/${hash}`;
}
