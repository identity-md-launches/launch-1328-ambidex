import {
  createPublicClient,
  encodeAbiParameters,
  fallback,
  http,
  keccak256,
  parseAbi,
  type Address,
  type Hex,
} from 'viem';
import { mainnet } from 'viem/chains';
import { ambidexTokenAbi } from '../abi/AmbidexToken.ts';
import { CHAIN, POOL_KEY, TOKEN, UNISWAP_V4 } from '../config.ts';

export const AMBIDEX_ABI = ambidexTokenAbi;

export const publicClient = createPublicClient({
  chain: mainnet,
  transport: fallback(CHAIN.rpcUrls.map((url) => http(url, { timeout: 15_000 }))),
  batch: { multicall: true },
});

const stateViewAbi = parseAbi([
  'function getSlot0(bytes32 poolId) view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)',
  'function getLiquidity(bytes32 poolId) view returns (uint128 liquidity)',
]);

/** keccak256(abi.encode(PoolKey)) — the id Uniswap v4 uses for the AMBI/IMD pool. */
export const POOL_ID: Hex = keccak256(
  encodeAbiParameters(
    [{ type: 'address' }, { type: 'address' }, { type: 'uint24' }, { type: 'int24' }, { type: 'address' }],
    [POOL_KEY.currency0, POOL_KEY.currency1, POOL_KEY.fee, POOL_KEY.tickSpacing, POOL_KEY.hooks],
  ),
);

export interface TokenSummary {
  name: string;
  symbol: string;
  decimals: number;
  totalSupply: bigint;
}

export async function readTokenSummary(): Promise<TokenSummary> {
  const [name, symbol, decimals, totalSupply] = await Promise.all([
    publicClient.readContract({ address: TOKEN.address, abi: AMBIDEX_ABI, functionName: 'name' }) as Promise<string>,
    publicClient.readContract({ address: TOKEN.address, abi: AMBIDEX_ABI, functionName: 'symbol' }) as Promise<string>,
    publicClient.readContract({ address: TOKEN.address, abi: AMBIDEX_ABI, functionName: 'decimals' }) as Promise<number>,
    publicClient.readContract({
      address: TOKEN.address,
      abi: AMBIDEX_ABI,
      functionName: 'totalSupply',
    }) as Promise<bigint>,
  ]);
  return { name, symbol, decimals, totalSupply };
}

export async function readBalance(account: Address): Promise<bigint> {
  return (await publicClient.readContract({
    address: TOKEN.address,
    abi: AMBIDEX_ABI,
    functionName: 'balanceOf',
    args: [account],
  })) as bigint;
}

export interface PoolState {
  sqrtPriceX96: bigint;
  tick: number;
  lpFee: number;
  liquidity: bigint;
  /** IMD per AMBI scaled by 1e18 (an 18-decimal fixed-point number). */
  imdPerAmbiWad: bigint;
  /** IMD per AMBI as a JS number, for display. */
  imdPerAmbi: number;
  /** AMBI per IMD as a JS number, for display. */
  ambiPerImd: number;
}

const Q96 = 2n ** 96n;
const WAD = 10n ** 18n;

/** Converts a Uniswap sqrtPriceX96 into currency1-per-currency0, scaled by 1e18. Both tokens have 18 decimals. */
export function sqrtPriceToWad(sqrtPriceX96: bigint): bigint {
  return (sqrtPriceX96 * sqrtPriceX96 * WAD) / (Q96 * Q96);
}

export function wadToNumber(wad: bigint): number {
  return Number(wad) / 1e18;
}

export async function readPoolState(): Promise<PoolState> {
  const [slot0, liquidity] = await Promise.all([
    publicClient.readContract({
      address: UNISWAP_V4.stateView,
      abi: stateViewAbi,
      functionName: 'getSlot0',
      args: [POOL_ID],
    }),
    publicClient.readContract({
      address: UNISWAP_V4.stateView,
      abi: stateViewAbi,
      functionName: 'getLiquidity',
      args: [POOL_ID],
    }),
  ]);
  const [sqrtPriceX96, tick, , lpFee] = slot0;
  const imdPerAmbiWad = sqrtPriceToWad(sqrtPriceX96);
  const imdPerAmbi = wadToNumber(imdPerAmbiWad);
  return {
    sqrtPriceX96,
    tick,
    lpFee,
    liquidity,
    imdPerAmbiWad,
    imdPerAmbi,
    ambiPerImd: imdPerAmbi > 0 ? 1 / imdPerAmbi : 0,
  };
}
