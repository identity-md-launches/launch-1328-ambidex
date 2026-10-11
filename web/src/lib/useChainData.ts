import { useCallback, useEffect, useState } from 'react';
import { readPoolState, readTokenSummary, type PoolState, type TokenSummary } from './chain.ts';

export type LoadState<T> =
  | { status: 'loading'; data: T | null }
  | { status: 'ready'; data: T }
  | { status: 'error'; data: T | null; message: string };

export interface ChainData {
  token: LoadState<TokenSummary>;
  pool: LoadState<PoolState>;
  refresh(): void;
  updatedAt: Date | null;
}

const REFRESH_MS = 60_000;

export function useChainData(): ChainData {
  const [token, setToken] = useState<LoadState<TokenSummary>>({ status: 'loading', data: null });
  const [pool, setPool] = useState<LoadState<PoolState>>({ status: 'loading', data: null });
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);
  const [tick, setTick] = useState(0);

  const refresh = useCallback(() => setTick((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;
    readTokenSummary()
      .then((data) => {
        if (!cancelled) setToken({ status: 'ready', data });
      })
      .catch(() => {
        if (!cancelled)
          setToken((prev) => ({
            status: 'error',
            data: prev.data,
            message: 'Unable to reach Ethereum right now. Check your connection and refresh.',
          }));
      });
    readPoolState()
      .then((data) => {
        if (!cancelled) {
          setPool({ status: 'ready', data });
          setUpdatedAt(new Date());
        }
      })
      .catch(() => {
        if (!cancelled)
          setPool((prev) => ({
            status: 'error',
            data: prev.data,
            message: 'Unable to read the pool right now. Check your connection and refresh.',
          }));
      });
    const timer = window.setTimeout(refresh, REFRESH_MS);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [tick, refresh]);

  return { token, pool, refresh, updatedAt };
}
