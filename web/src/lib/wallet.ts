// Minimal wallet plumbing over EIP-1193 and EIP-6963. No wallet SDKs: the visitor's
// own browser wallet announces itself, and every transaction is sent through it.

import { useEffect, useState } from 'react';

export interface Eip1193Provider {
  request(args: { method: string; params?: unknown[] | Record<string, unknown> }): Promise<unknown>;
  on?(event: string, listener: (...args: unknown[]) => void): void;
  removeListener?(event: string, listener: (...args: unknown[]) => void): void;
}

export interface WalletOption {
  id: string;
  name: string;
  icon?: string;
  provider: Eip1193Provider;
}

interface AnnounceEvent extends Event {
  detail: { info: { uuid: string; name: string; icon: string; rdns: string }; provider: Eip1193Provider };
}

declare global {
  interface Window {
    ethereum?: Eip1193Provider & { isMetaMask?: boolean };
  }
}

const options = new Map<string, WalletOption>();
const listeners = new Set<() => void>();
let discoveryStarted = false;

function notify() {
  for (const listener of listeners) listener();
}

function startDiscovery() {
  if (discoveryStarted || typeof window === 'undefined') return;
  discoveryStarted = true;
  window.addEventListener('eip6963:announceProvider', (event) => {
    const { detail } = event as AnnounceEvent;
    if (!detail?.provider || !detail.info) return;
    const id = detail.info.rdns || detail.info.uuid;
    if (options.has(id)) return;
    options.set(id, { id, name: detail.info.name, icon: detail.info.icon, provider: detail.provider });
    options.delete('injected');
    notify();
  });
  window.dispatchEvent(new Event('eip6963:requestProvider'));
  // Legacy fallback: a wallet that only sets window.ethereum.
  setTimeout(() => {
    if (options.size === 0 && window.ethereum) {
      options.set('injected', { id: 'injected', name: 'Browser wallet', provider: window.ethereum });
      notify();
    }
  }, 300);
}

/** Wallets detected in this browser, updated as they announce themselves. */
export function useWalletOptions(): WalletOption[] {
  const [list, setList] = useState<WalletOption[]>(() => Array.from(options.values()));
  useEffect(() => {
    startDiscovery();
    const update = () => setList(Array.from(options.values()));
    listeners.add(update);
    update();
    return () => {
      listeners.delete(update);
    };
  }, []);
  return list;
}

export function parseChainId(value: unknown): number | null {
  if (typeof value === 'string') return Number.parseInt(value, 16);
  if (typeof value === 'number') return value;
  return null;
}

export interface RpcError {
  code?: number;
  message?: string;
  shortMessage?: string;
  details?: string;
}

export function isUserRejection(error: unknown): boolean {
  const e = error as RpcError | undefined;
  if (!e) return false;
  if (e.code === 4001) return true;
  const text = `${e.shortMessage ?? ''} ${e.message ?? ''}`.toLowerCase();
  return text.includes('user rejected') || text.includes('user denied');
}

export function describeError(error: unknown, fallback: string): string {
  if (isUserRejection(error)) return 'Request cancelled in the wallet. Nothing was sent.';
  const e = error as RpcError | undefined;
  const text = e?.shortMessage ?? e?.message;
  if (!text) return fallback;
  const firstLine = text.split('\n')[0] ?? text;
  return firstLine.length > 160 ? `${firstLine.slice(0, 157)}…` : firstLine;
}
