import { CHAIN, TOKEN, explorerTx } from '../config';
import { AddressRow } from './AddressRow';
import { ExternalIcon } from './Icons';

const PROPERTIES: Array<[string, string]> = [
  ['Standard', 'ERC-20 on OpenZeppelin Contracts v5.4.0'],
  ['Supply', '1,000,000,000 AMBI, minted once in the constructor'],
  ['Minting', 'None after deployment. The supply can never grow.'],
  ['Owner or admin', 'None. No pause, blacklist, freeze, seize or upgrade.'],
  ['Transfer rules', 'None. Every transfer moves exactly the amount requested.'],
  ['Decimals', '18'],
];

export function Contract() {
  return (
    <section id="contract" className="section" aria-labelledby="contract-heading">
      <div className="section__intro">
        <h2 id="contract-heading" className="section-title">
          Contract
        </h2>
        <p className="section-lede">
          AmbidexToken is a thin, fixed-supply wrapper over OpenZeppelin’s ERC-20. Nobody can mint, pause or move a
          holder’s tokens. The source is public and the deployed ABI matches the launch record.
        </p>
        <div className="button-row">
          <a className="button button--secondary" href={`${TOKEN.repoUrl}/tree/${TOKEN.sourceCommit}`} target="_blank" rel="noopener noreferrer">
            <span>Read the source on GitHub</span>
            <ExternalIcon />
          </a>
          <a className="button button--secondary" href={explorerTx(TOKEN.deployTx)} target="_blank" rel="noopener noreferrer">
            <span>Deployment transaction</span>
            <ExternalIcon />
          </a>
        </div>
      </div>
      <div className="stack">
        <div className="card">
          <h3 className="card__title">Addresses on {CHAIN.name}</h3>
          <div className="address-list">
            <AddressRow label="AMBI token" address={TOKEN.address} note={`Deployed in block ${TOKEN.deployBlock.toLocaleString('en-US')}`} />
          </div>
        </div>
        <div className="card">
          <h3 className="card__title">Properties</h3>
          <dl className="kv">
            {PROPERTIES.map(([label, value]) => (
              <div className="kv__row" key={label}>
                <dt>{label}</dt>
                <dd>{value}</dd>
              </div>
            ))}
            <div className="kv__row kv__row--wide">
              <dt>ABI hash</dt>
              <dd className="kv__code">
                <code>{TOKEN.abiHash}</code>
              </dd>
            </div>
            <div className="kv__row kv__row--wide">
              <dt>Source commit</dt>
              <dd className="kv__code">
                <code>{TOKEN.sourceCommit}</code>
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </section>
  );
}
