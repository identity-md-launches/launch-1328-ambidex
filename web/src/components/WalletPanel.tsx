import { useEffect, useId, useRef, useState, type FormEvent } from 'react';
import { isAddress, parseUnits, type Address, type Hex } from 'viem';
import { AMBIDEX_ABI, publicClient, readBalance } from '../lib/chain';
import { describeError, useWalletOptions } from '../lib/wallet';
import { useWallet } from '../lib/WalletContext';
import { CHAIN, SWAP_URL, TOKEN, explorerTx, siteAssetUrl } from '../config';
import { formatTokenAmount, shortenAddress } from '../lib/format';
import { AlertIcon, ExternalIcon, WalletIcon } from './Icons';

type SendPhase =
  | { kind: 'idle' }
  | { kind: 'confirming' }
  | { kind: 'pending'; hash: Hex }
  | { kind: 'done'; hash: Hex; amount: bigint; to: Address }
  | { kind: 'failed'; message: string };

export function WalletPanel() {
  const wallet = useWallet();
  const options = useWalletOptions();
  const [connectError, setConnectError] = useState<string | null>(null);
  const [connectingId, setConnectingId] = useState<string | null>(null);

  async function connect(id: string) {
    const option = options.find((o) => o.id === id);
    if (!option) return;
    setConnectError(null);
    setConnectingId(id);
    try {
      await wallet.connect(option);
    } catch (error) {
      setConnectError(describeError(error, 'Unable to connect. Open your wallet and try again.'));
    } finally {
      setConnectingId(null);
    }
  }

  if (wallet.status === 'connected' && wallet.account) {
    return <ConnectedPanel account={wallet.account} />;
  }

  return (
    <section className="card card--action" aria-labelledby="wallet-heading">
      <h2 id="wallet-heading" className="card__title">
        Your AMBI
      </h2>
      <p className="card__lede">Connect a wallet to see your balance, add AMBI to the wallet or send it.</p>

      {options.length === 0 ? (
        <div className="notice" role="status">
          <AlertIcon />
          <p>
            No browser wallet detected. Install one such as MetaMask or Rabby, or{' '}
            <a href="#lookup">look up any balance</a> without connecting.
          </p>
        </div>
      ) : options.length === 1 && options[0] ? (
        <button
          type="button"
          className="button button--primary button--block"
          onClick={() => connect(options[0]!.id)}
          disabled={connectingId !== null}
        >
          <WalletIcon />
          <span>{connectingId ? 'Waiting for wallet…' : 'Connect wallet'}</span>
        </button>
      ) : (
        <div className="stack stack--tight">
          <p className="field__hint">Choose a wallet to connect.</p>
          {options.map((option) => (
            <button
              key={option.id}
              type="button"
              className="button button--secondary button--block"
              onClick={() => connect(option.id)}
              disabled={connectingId !== null}
            >
              {option.icon ? <img src={option.icon} alt="" width={20} height={20} /> : <WalletIcon />}
              <span>{connectingId === option.id ? 'Waiting for wallet…' : `Connect ${option.name}`}</span>
            </button>
          ))}
        </div>
      )}

      {connectError ? (
        <p className="field__error" role="alert">
          {connectError}
        </p>
      ) : null}

      <a className="button button--secondary button--block" href={SWAP_URL} target="_blank" rel="noopener noreferrer">
        <span>Swap AMBI on Uniswap</span>
        <ExternalIcon />
      </a>
    </section>
  );
}

function ConnectedPanel({ account }: { account: Address }) {
  const wallet = useWallet();
  const [balance, setBalance] = useState<bigint | null>(null);
  const [balanceError, setBalanceError] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [addState, setAddState] = useState<'idle' | 'busy' | 'added' | 'failed'>('idle');
  const [addMessage, setAddMessage] = useState<string | null>(null);
  const [switchError, setSwitchError] = useState<string | null>(null);
  const onEthereum = wallet.chainId === CHAIN.id;

  useEffect(() => {
    let cancelled = false;
    setBalanceError(null);
    readBalance(account)
      .then((value) => {
        if (!cancelled) setBalance(value);
      })
      .catch(() => {
        if (!cancelled) setBalanceError('Unable to load the balance. Check your connection and refresh.');
      });
    return () => {
      cancelled = true;
    };
  }, [account, refreshKey]);

  async function addToken() {
    if (!wallet.provider) return;
    setAddState('busy');
    setAddMessage(null);
    // The icon lives next to index.html; resolve it against the page's own URL so it is
    // reachable from whatever host serves the export. Omitted when that is not http(s).
    const image = siteAssetUrl('token.png');
    try {
      const ok = await wallet.provider.request({
        method: 'wallet_watchAsset',
        params: {
          type: 'ERC20',
          options: {
            address: TOKEN.address,
            symbol: TOKEN.symbol,
            decimals: TOKEN.decimals,
            ...(image ? { image } : {}),
          },
        },
      });
      setAddState(ok ? 'added' : 'idle');
      setAddMessage(ok ? 'AMBI now shows in your wallet’s token list.' : 'Not added. You can try again whenever you like.');
    } catch (error) {
      setAddState('failed');
      setAddMessage(describeError(error, 'Unable to add the token. Add it manually with the contract address below.'));
    }
  }

  async function switchChain() {
    setSwitchError(null);
    try {
      await wallet.switchToEthereum();
    } catch (error) {
      setSwitchError(describeError(error, 'Unable to switch. Choose Ethereum in your wallet, then come back.'));
    }
  }

  return (
    <section className="card card--action" aria-labelledby="wallet-heading">
      <div className="card__header">
        <h2 id="wallet-heading" className="card__title">
          Your AMBI
        </h2>
        <button type="button" className="button button--ghost button--small" onClick={wallet.disconnect}>
          Disconnect
        </button>
      </div>
      <dl className="account">
        <div className="account__row">
          <dt>Wallet</dt>
          <dd>
            <span title={account}>{shortenAddress(account)}</span>
            {wallet.walletName ? <span className="account__wallet"> · {wallet.walletName}</span> : null}
          </dd>
        </div>
        <div className="account__row">
          <dt>Balance</dt>
          <dd className="account__balance num" aria-live="polite">
            {balance === null && !balanceError ? 'Loading…' : null}
            {balance !== null ? `${formatTokenAmount(balance, TOKEN.decimals, 4)} ${TOKEN.symbol}` : null}
          </dd>
        </div>
      </dl>
      {balanceError ? (
        <p className="field__error" role="alert">
          {balanceError}{' '}
          <button type="button" className="link-button" onClick={() => setRefreshKey((n) => n + 1)}>
            Refresh balance
          </button>
        </p>
      ) : null}

      {!onEthereum ? (
        <div className="notice notice--warning" role="status">
          <AlertIcon />
          <div className="stack stack--tight">
            <p>This wallet is on another network. AMBI lives on Ethereum mainnet.</p>
            <button type="button" className="button button--primary" onClick={switchChain}>
              Switch to Ethereum
            </button>
            {switchError ? <p className="field__error">{switchError}</p> : null}
          </div>
        </div>
      ) : (
        <>
          <div className="button-row">
            <button
              type="button"
              className="button button--secondary"
              onClick={addToken}
              disabled={addState === 'busy'}
            >
              {addState === 'busy' ? 'Waiting for wallet…' : 'Add AMBI to wallet'}
            </button>
            <a className="button button--secondary" href={SWAP_URL} target="_blank" rel="noopener noreferrer">
              <span>Swap on Uniswap</span>
              <ExternalIcon />
            </a>
          </div>
          <p className={addState === 'failed' ? 'field__error' : 'field__hint'} role="status">
            {addMessage}
          </p>
          <SendForm account={account} balance={balance} onSent={() => setRefreshKey((n) => n + 1)} />
        </>
      )}
    </section>
  );
}

function SendForm({ account, balance, onSent }: { account: Address; balance: bigint | null; onSent(): void }) {
  const wallet = useWallet();
  const id = useId();
  const [to, setTo] = useState('');
  const [amount, setAmount] = useState('');
  const [toError, setToError] = useState<string | null>(null);
  const [amountError, setAmountError] = useState<string | null>(null);
  const [phase, setPhase] = useState<SendPhase>({ kind: 'idle' });
  const toRef = useRef<HTMLInputElement>(null);
  const amountRef = useRef<HTMLInputElement>(null);

  function parseAmount(text: string): bigint | null {
    const trimmed = text.trim().replace(/,/g, '');
    if (!/^\d*\.?\d*$/.test(trimmed) || trimmed === '' || trimmed === '.') return null;
    const [, fraction = ''] = trimmed.split('.');
    if (fraction.length > TOKEN.decimals) return null;
    try {
      return parseUnits(trimmed, TOKEN.decimals);
    } catch {
      return null;
    }
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!wallet.walletClient) return;
    let nextToError: string | null = null;
    let nextAmountError: string | null = null;
    const recipient = to.trim();
    if (!isAddress(recipient)) nextToError = 'Enter a full Ethereum address: 0x followed by 40 hex characters.';
    else if (recipient.toLowerCase() === account.toLowerCase()) nextToError = 'Enter an address other than your own.';
    const value = parseAmount(amount);
    if (value === null || value <= 0n) nextAmountError = 'Enter an amount above 0, with at most 18 decimals.';
    else if (balance !== null && value > balance)
      nextAmountError = `Enter at most ${formatTokenAmount(balance, TOKEN.decimals, 4)} AMBI, your current balance.`;
    setToError(nextToError);
    setAmountError(nextAmountError);
    if (nextToError) {
      toRef.current?.focus();
      return;
    }
    if (nextAmountError || value === null) {
      amountRef.current?.focus();
      return;
    }

    setPhase({ kind: 'confirming' });
    try {
      const hash = await wallet.walletClient.writeContract({
        account,
        chain: wallet.walletClient.chain,
        address: TOKEN.address,
        abi: AMBIDEX_ABI,
        functionName: 'transfer',
        args: [recipient as Address, value],
      });
      setPhase({ kind: 'pending', hash });
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === 'success') {
        setPhase({ kind: 'done', hash, amount: value, to: recipient as Address });
        setTo('');
        setAmount('');
        onSent();
      } else {
        setPhase({ kind: 'failed', message: 'The transaction was mined but reverted. Nothing was sent.' });
      }
    } catch (error) {
      setPhase({ kind: 'failed', message: describeError(error, 'Unable to send. Check the wallet and try again.') });
    }
  }

  const busy = phase.kind === 'confirming' || phase.kind === 'pending';

  return (
    <form className="send-form" onSubmit={submit} noValidate aria-labelledby={`${id}-title`}>
      <h3 id={`${id}-title`} className="send-form__title">
        Send AMBI
      </h3>
      <div className="field">
        <label htmlFor={`${id}-to`}>Recipient address</label>
        <input
          ref={toRef}
          id={`${id}-to`}
          name="recipient"
          type="text"
          inputMode="text"
          autoComplete="off"
          spellCheck={false}
          placeholder="0x1234…abcd"
          value={to}
          onChange={(e) => setTo(e.target.value)}
          aria-invalid={toError ? true : undefined}
          aria-describedby={toError ? `${id}-to-error` : undefined}
        />
        {toError ? (
          <p id={`${id}-to-error`} className="field__error">
            {toError}
          </p>
        ) : null}
      </div>
      <div className="field">
        <label htmlFor={`${id}-amount`}>Amount in AMBI</label>
        <input
          ref={amountRef}
          id={`${id}-amount`}
          name="amount"
          type="text"
          inputMode="decimal"
          autoComplete="off"
          placeholder="100"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          aria-invalid={amountError ? true : undefined}
          aria-describedby={amountError ? `${id}-amount-error` : `${id}-amount-hint`}
        />
        {amountError ? (
          <p id={`${id}-amount-error`} className="field__error">
            {amountError}
          </p>
        ) : (
          <p id={`${id}-amount-hint`} className="field__hint">
            Whole tokens, up to 18 decimals. Transfers move exactly this amount; there is no fee.
          </p>
        )}
      </div>
      <button type="submit" className="button button--primary" disabled={busy}>
        {phase.kind === 'confirming' ? 'Confirm in wallet…' : phase.kind === 'pending' ? 'Sending…' : 'Send AMBI'}
      </button>
      <p className={phase.kind === 'failed' ? 'field__error' : 'field__hint'} role="status">
        {phase.kind === 'pending' ? (
          <>
            Transaction submitted. Waiting for confirmation.{' '}
            <a href={explorerTx(phase.hash)} target="_blank" rel="noopener noreferrer">
              View on Etherscan
            </a>
          </>
        ) : null}
        {phase.kind === 'done' ? (
          <>
            Sent {formatTokenAmount(phase.amount, TOKEN.decimals, 4)} AMBI to {shortenAddress(phase.to)}.{' '}
            <a href={explorerTx(phase.hash)} target="_blank" rel="noopener noreferrer">
              View on Etherscan
            </a>
          </>
        ) : null}
        {phase.kind === 'failed' ? phase.message : null}
      </p>
    </form>
  );
}
