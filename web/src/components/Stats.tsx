import { PAIR_TOKEN, TOKEN } from '../config';
import type { ChainData } from '../lib/useChainData';
import { formatCompact, formatRatio, formatTokenAmount, percentFromPips } from '../lib/format';

export function Stats({ data }: { data: ChainData }) {
  const token = data.token.data;
  const pool = data.pool.data;
  const marketCapImd = pool && token ? pool.imdPerAmbi * Number(token.totalSupply / 10n ** 18n) : null;

  return (
    <section className="stats" aria-labelledby="stats-heading">
      <div className="stats__header">
        <h2 id="stats-heading" className="section-title">
          Live on Ethereum
        </h2>
        <p className="stats__updated" role="status">
          {data.updatedAt
            ? `Updated ${data.updatedAt.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}`
            : data.pool.status === 'loading'
              ? 'Reading the chain…'
              : ''}
          {data.pool.status !== 'loading' ? (
            <>
              {' · '}
              <button type="button" className="link-button" onClick={data.refresh}>
                Refresh
              </button>
            </>
          ) : null}
        </p>
      </div>
      <dl className="stat-grid">
        <Stat
          label="Total supply"
          value={token ? `${formatCompact(Number(token.totalSupply / 10n ** 18n))} ${token.symbol}` : null}
          detail={token ? `${formatTokenAmount(token.totalSupply, token.decimals, 0)} fixed, nothing can mint` : undefined}
          state={data.token}
        />
        <Stat
          label={`Price in ${PAIR_TOKEN.symbol}`}
          value={pool ? `${formatRatio(pool.imdPerAmbi)} ${PAIR_TOKEN.symbol}` : null}
          detail={pool ? `per 1 ${TOKEN.symbol} · ${formatRatio(pool.ambiPerImd)} ${TOKEN.symbol} per ${PAIR_TOKEN.symbol}` : undefined}
          state={data.pool}
        />
        <Stat
          label="Market cap"
          value={marketCapImd !== null ? `${formatRatio(marketCapImd)} ${PAIR_TOKEN.symbol}` : null}
          detail="Pool price × total supply"
          state={data.pool}
        />
        <Stat
          label="Pool fee"
          value={pool ? percentFromPips(pool.lpFee) : null}
          detail="Uniswap v4, tick spacing 60"
          state={data.pool}
        />
      </dl>
      {data.token.status === 'error' ? (
        <p className="field__error" role="alert">
          {data.token.message}
        </p>
      ) : data.pool.status === 'error' ? (
        <p className="field__error" role="alert">
          {data.pool.message}
        </p>
      ) : null}
    </section>
  );
}

function Stat({
  label,
  value,
  detail,
  state,
}: {
  label: string;
  value: string | null;
  detail?: string;
  state: { status: 'loading' | 'ready' | 'error' };
}) {
  return (
    <div className="stat">
      <dt className="stat__label">{label}</dt>
      <dd className="stat__value num">
        {value ?? (state.status === 'loading' ? <span className="stat__placeholder">Loading…</span> : <span className="stat__placeholder">Unavailable</span>)}
      </dd>
      {detail ? <dd className="stat__detail">{detail}</dd> : null}
    </div>
  );
}
