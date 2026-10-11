import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { createWalletClient, custom, getAddress, type Address, type WalletClient } from 'viem';
import { mainnet } from 'viem/chains';
import { CHAIN } from '../config.ts';
import { parseChainId, type Eip1193Provider, type WalletOption } from './wallet.ts';

export type WalletStatus = 'disconnected' | 'connecting' | 'connected';

export interface WalletState {
  status: WalletStatus;
  account: Address | null;
  chainId: number | null;
  walletName: string | null;
  provider: Eip1193Provider | null;
  walletClient: WalletClient | null;
  connect(option: WalletOption): Promise<void>;
  disconnect(): void;
  switchToEthereum(): Promise<void>;
}

const WalletContext = createContext<WalletState | null>(null);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<WalletStatus>('disconnected');
  const [account, setAccount] = useState<Address | null>(null);
  const [chainId, setChainId] = useState<number | null>(null);
  const [walletName, setWalletName] = useState<string | null>(null);
  const [provider, setProvider] = useState<Eip1193Provider | null>(null);
  const cleanupRef = useRef<() => void>(() => {});

  const disconnect = useCallback(() => {
    cleanupRef.current();
    cleanupRef.current = () => {};
    setProvider(null);
    setAccount(null);
    setChainId(null);
    setWalletName(null);
    setStatus('disconnected');
  }, []);

  const connect = useCallback(
    async (option: WalletOption) => {
      cleanupRef.current();
      setStatus('connecting');
      try {
        const accounts = (await option.provider.request({ method: 'eth_requestAccounts' })) as string[];
        const first = accounts[0];
        if (!first) throw new Error('The wallet returned no account.');
        const rawChain = await option.provider.request({ method: 'eth_chainId' });
        setAccount(getAddress(first));
        setChainId(parseChainId(rawChain));
        setProvider(option.provider);
        setWalletName(option.name);
        setStatus('connected');

        const onAccounts = (...args: unknown[]) => {
          const list = args[0] as string[] | undefined;
          const next = list?.[0];
          if (!next) {
            disconnect();
          } else {
            setAccount(getAddress(next));
          }
        };
        const onChain = (...args: unknown[]) => setChainId(parseChainId(args[0]));
        option.provider.on?.('accountsChanged', onAccounts);
        option.provider.on?.('chainChanged', onChain);
        cleanupRef.current = () => {
          option.provider.removeListener?.('accountsChanged', onAccounts);
          option.provider.removeListener?.('chainChanged', onChain);
        };
      } catch (error) {
        setStatus('disconnected');
        throw error;
      }
    },
    [disconnect],
  );

  const switchToEthereum = useCallback(async () => {
    if (!provider) return;
    try {
      await provider.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: CHAIN.hexId }] });
    } catch (error) {
      const code = (error as { code?: number }).code;
      if (code === 4902) {
        await provider.request({
          method: 'wallet_addEthereumChain',
          params: [
            {
              chainId: CHAIN.hexId,
              chainName: CHAIN.name,
              rpcUrls: CHAIN.rpcUrls,
              nativeCurrency: CHAIN.nativeCurrency,
              blockExplorerUrls: [CHAIN.explorer],
            },
          ],
        });
      } else {
        throw error;
      }
    }
    const rawChain = await provider.request({ method: 'eth_chainId' });
    setChainId(parseChainId(rawChain));
  }, [provider]);

  useEffect(() => () => cleanupRef.current(), []);

  const walletClient = useMemo(
    () => (provider && account ? createWalletClient({ account, chain: mainnet, transport: custom(provider) }) : null),
    [provider, account],
  );

  const value = useMemo<WalletState>(
    () => ({ status, account, chainId, walletName, provider, walletClient, connect, disconnect, switchToEthereum }),
    [status, account, chainId, walletName, provider, walletClient, connect, disconnect, switchToEthereum],
  );

  return <WalletContext.Provider value={value}>{children}</WalletContext.Provider>;
}

export function useWallet(): WalletState {
  const ctx = useContext(WalletContext);
  if (!ctx) throw new Error('useWallet must be used inside WalletProvider');
  return ctx;
}
