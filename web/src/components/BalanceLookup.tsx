import { useId, useRef, useState, type FormEvent } from 'react';
import { getAddress, isAddress } from 'viem';
import { TOKEN, explorerAddress } from '../config';
import { readBalance } from '../lib/chain';
import { formatTokenAmount, shortenAddress } from '../lib/format';

type LookupState =
  | { kind: 'idle' }
  | { kind: 'loading'; address: string }
  | { kind: 'ready'; address: string; balance: bigint; share: number }
  | { kind: 'failed'; message: string };

export function BalanceLookup() {
  const id = useId();
  const [value, setValue] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [state, setState] = useState<LookupState>({ kind: 'idle' });
  const inputRef = useRef<HTMLInputElement>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const trimmed = value.trim();
    if (!isAddress(trimmed)) {
      setError('Enter a full Ethereum address: 0x followed by 40 hex characters.');
      inputRef.current?.focus();
      return;
    }
    setError(null);
    const address = getAddress(trimmed);
    setState({ kind: 'loading', address });
    try {
      const balance = await readBalance(address);
      const share = Number((balance * 1_000_000n) / TOKEN.totalSupply) / 10_000;
      setState({ kind: 'ready', address, balance, share });
    } catch {
      setState({ kind: 'failed', message: 'Unable to reach Ethereum right now. Check your connection and try again.' });
    }
  }

  return (
    <section id="lookup" className="card" aria-labelledby={`${id}-title`}>
      <h3 id={`${id}-title`} className="card__title">
        Look up a balance
      </h3>
      <p className="card__lede">Any Ethereum address, no wallet needed.</p>
      <form className="lookup-form" onSubmit={submit} noValidate>
        <div className="field">
          <label htmlFor={`${id}-address`}>Ethereum address</label>
          <input
            ref={inputRef}
            id={`${id}-address`}
            name="address"
            type="text"
            autoComplete="off"
            spellCheck={false}
            placeholder="0x1234…abcd"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? `${id}-error` : undefined}
          />
          {error ? (
            <p id={`${id}-error`} className="field__error">
              {error}
            </p>
          ) : null}
        </div>
        <button type="submit" className="button button--secondary" disabled={state.kind === 'loading'}>
          {state.kind === 'loading' ? 'Checking…' : 'Check balance'}
        </button>
      </form>
      <p className={state.kind === 'failed' ? 'field__error' : 'lookup-result'} role="status">
        {state.kind === 'ready' ? (
          <>
            <a href={explorerAddress(state.address)} target="_blank" rel="noopener noreferrer">
              {shortenAddress(state.address)}
            </a>{' '}
            holds <strong className="num">{formatTokenAmount(state.balance, TOKEN.decimals, 4)} AMBI</strong>
            {state.share > 0 ? <> ({state.share.toLocaleString('en-US', { maximumFractionDigits: 4 })}% of supply)</> : null}.
          </>
        ) : null}
        {state.kind === 'failed' ? state.message : null}
      </p>
    </section>
  );
}
