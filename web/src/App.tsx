import { BalanceLookup } from './components/BalanceLookup';
import { Contract } from './components/Contract';
import { Logo } from './components/Icons';
import { Stats } from './components/Stats';
import { Trade } from './components/Trade';
import { WalletPanel } from './components/WalletPanel';
import { CHAIN, PAIR_TOKEN, TOKEN } from './config';
import { useChainData } from './lib/useChainData';

export function App() {
  const data = useChainData();

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        <div className="container site-header__inner">
          <a className="brand" href="#top" aria-label="AMBIDEX home">
            <Logo />
            <span className="brand__name">AMBIDEX</span>
          </a>
          <nav aria-label="Sections">
            <ul className="nav">
              <li>
                <a href="#stats">Live</a>
              </li>
              <li>
                <a href="#trade">Trade</a>
              </li>
              <li>
                <a href="#contract">Contract</a>
              </li>
            </ul>
          </nav>
        </div>
      </header>

      <main id="main" className="container">
        <section id="top" className="hero" aria-labelledby="hero-heading">
          <div className="hero__copy">
            <h1 id="hero-heading" className="hero__title">
              One billion AMBI, fixed forever.
            </h1>
            <p className="hero__lede">
              AMBIDEX ({TOKEN.symbol}) is a fixed-supply ERC-20 on {CHAIN.name} with no owner and no mint, trading
              against {PAIR_TOKEN.symbol} on Uniswap v4.
            </p>
          </div>
          <WalletPanel />
        </section>

        <div id="stats" className="anchor-target">
          <Stats data={data} />
        </div>

        <BalanceLookup />

        <Trade />

        <Contract />
      </main>

      <footer className="site-footer">
        <div className="container site-footer__inner">
          <p>
            AMBIDEX is a token contract with no owner. This site reads public chain data and sends transactions only
            through your own wallet. Nothing here is financial advice.
          </p>
          <p>
            <a href={TOKEN.repoUrl} target="_blank" rel="noopener noreferrer">
              Source repository
            </a>
            {' · '}
            <a href={`${CHAIN.explorer}/token/${TOKEN.address}`} target="_blank" rel="noopener noreferrer">
              AMBI on Etherscan
            </a>
          </p>
        </div>
      </footer>
    </>
  );
}
