import { PAIR_TOKEN, POOL_KEY, SWAP_URL, TOKEN, UNISWAP_V4 } from '../config';
import { POOL_ID } from '../lib/chain';
import { percentFromPips } from '../lib/format';
import { AddressRow } from './AddressRow';
import { CopyButton } from './CopyButton';
import { ExternalIcon } from './Icons';

export function Trade() {
  return (
    <section id="trade" className="section" aria-labelledby="trade-heading">
      <div className="section__intro">
        <h2 id="trade-heading" className="section-title">
          Trade
        </h2>
        <p className="section-lede">
          AMBI trades against {PAIR_TOKEN.symbol} in one Uniswap v4 pool on Ethereum. The pool took 88% of the supply
          at launch and charges a {percentFromPips(POOL_KEY.fee)} fee on every swap.
        </p>
        <a className="button button--primary" href={SWAP_URL} target="_blank" rel="noopener noreferrer">
          <span>Swap AMBI on Uniswap</span>
          <ExternalIcon />
        </a>
        <p className="field__hint">
          Opens the Uniswap app with {PAIR_TOKEN.symbol} and AMBI preselected. If the app does not find a route, paste
          the pool details below into your preferred v4 interface.
        </p>
      </div>
      <div className="card">
        <h3 className="card__title">Pool key</h3>
        <dl className="kv">
          <div className="kv__row">
            <dt>Pair</dt>
            <dd>
              {TOKEN.symbol} / {PAIR_TOKEN.symbol} ({PAIR_TOKEN.name})
            </dd>
          </div>
          <div className="kv__row">
            <dt>Fee</dt>
            <dd className="num">
              {percentFromPips(POOL_KEY.fee)} ({POOL_KEY.fee} pips)
            </dd>
          </div>
          <div className="kv__row">
            <dt>Tick spacing</dt>
            <dd className="num">{POOL_KEY.tickSpacing}</dd>
          </div>
          <div className="kv__row kv__row--wide">
            <dt>Pool id</dt>
            <dd className="kv__code">
              <code>{POOL_ID}</code>
              <CopyButton value={POOL_ID} label="pool id" />
            </dd>
          </div>
        </dl>
        <div className="address-list">
          <AddressRow label="Launch hook" address={POOL_KEY.hooks} note="Pool initialization guard set at launch" />
          <AddressRow label={`${PAIR_TOKEN.symbol} token`} address={PAIR_TOKEN.address} note={PAIR_TOKEN.name} />
          <AddressRow label="Uniswap v4 PoolManager" address={UNISWAP_V4.poolManager} />
          <AddressRow label="Uniswap v4 StateView" address={UNISWAP_V4.stateView} note="Source of the price shown above" />
        </div>
      </div>
    </section>
  );
}
