# AMBIDEX (AMBI)

A plain, fixed-supply ERC-20 token for the IdentityMD custom-token launch on Ethereum, and the
static website for it at https://ambidex.trade/.

- [Website](#website): source in `web/`, static export in `dist/`.
- [Token contract](#token-contract): source in `src/`, tests in `test/`.

## Website

A single-page site (Vite, React, TypeScript, `viem`) that reads the live token and pool state from public
Ethereum RPC and offers the token's actions through the visitor's own browser wallet:

- Live supply, pool price in IMD, market cap and pool fee, read from `AmbidexToken` and the Uniswap v4
  `StateView` for the AMBI/IMD pool. Refreshes every minute or on demand.
- Balance lookup for any address, no wallet needed.
- Wallet panel (EIP-6963 / EIP-1193, no wallet SDK): connect, switch to Ethereum mainnet, add AMBI to the
  wallet (`wallet_watchAsset`), send AMBI (`transfer`), with inline validation and transaction status.
- A link into the Uniswap app with IMD and AMBI preselected, plus the full pool key and addresses.

Every address the site uses is in `web/src/config.ts` and comes from the launch and network records.
The ABI in `web/src/abi/AmbidexToken.ts` is the Foundry build output of the deployed source commit; its
canonical hash (keccak256 of the ABI JSON with sorted keys) is checked against the launch record by
`npm run check:abi`.

### Install

Node 24 and npm 11 were used. From the repository root:

```
cd web
npm ci
```

### Preview

Serve the committed export locally (any static file server works; the export uses relative URLs):

```
cd web
npm run preview          # serves ../dist at http://localhost:4173/
```

For development with hot reload: `npm run dev`.

### Rebuild

```
cd web
npm run check            # typecheck, unit tests, ABI hash check
npm run build            # tsc --noEmit, then vite build → ../dist
```

`dist/` is committed; rebuild and commit it after any change in `web/`. If the contract source changes
(it must not for the live token), regenerate the ABI with `forge build` and copy
`out/AmbidexToken.sol/AmbidexToken.json`'s `abi` into `web/src/abi/AmbidexToken.ts`, then run
`node scripts/verify-abi.mjs ../out/AmbidexToken.sol/AmbidexToken.json`.

### Publish

The site is a static export with relative asset URLs, so it works from any static host, an IPFS gateway
subpath or an ENS name. Publish the contents of `dist/` as the site root. The IdentityMD plane pins the
committed `dist/` after the job completes; no publishing command is run from this repository. The
`og:image`, `og:url` and `canonical` tags point at `https://ambidex.trade/`, so point that domain at the
published export for shared links to unfurl correctly.

### Checks run on 2026-10-11

| Check | Command | Result |
| --- | --- | --- |
| Typecheck | `npm run typecheck` | exit 0, no errors |
| Unit tests | `npm test` | 5 tests, 5 pass |
| ABI hash vs. launch record | `npm run check:abi` | match (`94a29d95…`) |
| Production build | `npm run build` | `dist/index.html` 1.95 kB, CSS 13.1 kB, JS 542 kB (167 kB gzip) |
| Browser verification | `node test/scratch/verify.mjs` (Playwright, Chromium) | exit 0: no console errors, no failed requests, no overflow at 320–1536, lookup / copy / nav / wallet flows pass |

The browser script served `dist/` under a `/preview/` subpath, exercised the wallet flow with a mock
EIP-6963 provider and saved screenshots to `artifacts/screenshots/`. Full coverage, findings and the
checks that were not performed (real wallet extension, real transfer, screen reader, native zoom,
Safari/Firefox) are in `artifacts/validation.md`. Design tokens, typography, components and responsive
behavior are documented in `DESIGN.md`.

### Website layout

```
web/index.html               page shell, meta tags (title, description, favicon, og:image)
web/src/main.tsx             entry
web/src/App.tsx              page composition: header, hero + wallet panel, stats, lookup, trade, contract, footer
web/src/config.ts            chain, token, pool and Uniswap addresses from the launch/network records
web/src/abi/AmbidexToken.ts  ABI from the Foundry build of the deployed commit
web/src/lib/chain.ts         public client, token and pool reads, pool id and price math
web/src/lib/wallet.ts        EIP-6963 discovery, EIP-1193 types, error wording
web/src/lib/WalletContext.tsx connect / disconnect / switch-chain state
web/src/components/          WalletPanel, BalanceLookup, Stats, Trade, Contract, AddressRow, CopyButton, Icons
web/src/styles.css           tokens and all styles
web/public/                  favicon.svg, favicon.png, token.png, og.png
web/scripts/verify-abi.mjs   ABI hash check
web/test/                    node --test unit tests
dist/                        committed production export (relative asset URLs)
artifacts/validation.md      validation and design-review record
artifacts/screenshots/       browser evidence from the final export
DESIGN.md                    implemented design system
```

## Token contract


| Property | Value |
| --- | --- |
| Solidity contract | `AmbidexToken` (`src/AmbidexToken.sol`) |
| Token name | `AMBIDEX` |
| Token symbol | `AMBI` |
| Decimals | 18 |
| Total supply | 1,000,000,000 AMBI = `1000000000000000000000000000` minor units |
| Minting | Once, in the constructor, the whole supply to `msg.sender` (the deployer) |
| Constructor arguments | None |
| Owner / admin roles | None |
| Compiler | solc 0.8.26, optimizer on (200 runs), `bytecode_hash = "none"`, no CBOR metadata |

## What the token does

`AmbidexToken` inherits OpenZeppelin v5.4.0 `ERC20` and adds nothing but constants and a single
constructor mint. Every transfer moves exactly the amount requested. There is no fee, burn-on-transfer,
reflection, vesting, pause, blacklist, freeze, seize, forced burn, upgrade path or minting function.
The supply can never grow. It can only shrink if holders choose to send tokens to an address nobody
controls, which is their own business.

Because there is no privileged role, nobody (not the deployer, not the launch factory, not IdentityMD)
can move or freeze a holder's balance. The only way a third party moves someone else's tokens is the
standard ERC-20 allowance mechanism, up to what the holder approved.

## Layout

```
foundry.toml                 Foundry configuration (solc 0.8.26, bytecode_hash = "none")
remappings.txt               forge-std and @openzeppelin/contracts remappings
src/AmbidexToken.sol         the token
script/DeployAmbidexToken.s.sol  reviewable deploy helper (not used by the launch factory)
test/AmbidexToken.t.sol      unit, fuzz and bytecode tests
lib/forge-std                forge-std v1.9.7, vendored as ordinary files
lib/openzeppelin-contracts   OpenZeppelin Contracts v5.4.0, vendored as ordinary files
```

Dependencies are committed as plain files, not git submodules, so the project builds with no network.

## Build and test

```
forge build
forge test
forge fmt --check
```

Tests read no environment variables and do not depend on which address runs them, so they pass in
any order and in parallel with an empty environment.

### What the tests cover

- Metadata: `name()`, `symbol()`, `decimals()` and the public constants.
- Supply: exactly 1,000,000,000 × 10^18 minted once to the deployer; a `Transfer` from the zero address
  is the only mint event; a CREATE2 deployment from a factory-like contract leaves the whole supply
  with that contract (the same shape the launch floor checks).
- Transfers: exact amounts arrive (including a factory → distributor → claimant chain), whole-balance,
  zero-amount and self transfers, and a fuzz test that balances are conserved and supply is unchanged.
- Failures: insufficient balance, transfers to the zero address, `transferFrom` beyond or without an
  allowance, `approve` to the zero spender, and the correct ERC-6093 custom errors for each.
- Allowances: decrement on use, infinite allowance left untouched.
- No privileged powers: the common mint / pause / blacklist / freeze / burnFrom / seize selectors do
  not exist, the deployer cannot pull a holder's tokens, and holders can still transfer afterwards.
- Bytecode: no `DELEGATECALL`, `CALLCODE` or `SELFDESTRUCT`; runtime under the EIP-170 limit; two
  deployments produce byte-identical runtime (reproducible build).
- Deploy script: its `deploy()` function is called directly from a test.

Passing tests are not a security audit. The token is a thin wrapper over a widely audited library, but
anything that will hold other people's value should still get an independent adversarial review before
release.

## Deployment parameters

The IdentityMD launch deploys `AmbidexToken` from its built bytecode through the ProjectFactory.

- **Constructor arguments:** none. The manifest's `constructorArgs` is an empty list.
- **Deployer / initial holder:** whichever address creates the contract. On the launch that is the
  factory, which then pays the supply out: 10% to the launch's MerkleDistributor, 88% to seed the
  single-sided pool, and the remaining 2% to the requester's `remainderTo` address, per the launch
  economics the manifest step copies from the job.
- **Chain:** Ethereum (chain id 1).
- **Pair:** IMD at `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`, 18 decimals. Pool fee 12500 (1.25%),
  tick spacing 60, as set by the launch policy.
- **Manifest supply (`token.totalSupply`):** `1000000000000000000000000000`.
- **Manifest decimals:** `18`.
- **Manifest contract name (`token.contract`):** `AmbidexToken` (12 characters).

`launch.json` is written by the manifest step after this work is accepted. It is deliberately not part
of this repository.

### Manual deployment outside the launch

`script/DeployAmbidexToken.s.sol` is a minimal, reviewable helper for forks, staging or a manual
deployment. It reads nothing from the environment. The broadcasting account becomes the deployer and
receives the whole supply:

```
forge script script/DeployAmbidexToken.s.sol --rpc-url <RPC> --broadcast
```

This repository does not hold keys and does not authorize any transaction.

## Assumptions

- The requester wants exactly what the brief says: a fixed supply of one billion tokens with 18 decimals,
  all minted once to the deployer, and nothing else. No tax, burn, vesting or governance was requested,
  so none was added.
- Because the token has no transfer rules, it needs no exemptions for the factory, the PoolManager or
  the distributor, and so takes none of the `$factory`, `$poolManager` or `$launchNumber` constructor
  arguments. The launch flows (distributor transfer, claims, pool seed, swaps both ways) move exactly
  the amounts they state.
- OpenZeppelin v5's `ERC20` is treated as correct. It is vendored unmodified at v5.4.0.
- `decimals()` is overridden to return the `DECIMALS` constant (18), which matches OpenZeppelin's
  default; the override exists so the value is explicit and testable.

## After launch

Nothing to configure. The token has no owner, no setters and no stored addresses. There are no
post-deployment steps for the requester beyond ordinary custody of the tokens they receive.

## Operational responsibilities

- **Requester:** custody of the `remainderTo` wallet and of any tokens it receives. Since nothing can
  mint, pause or recover tokens, a lost key or a mistaken transfer is unrecoverable by design.
- **Launch deployer (IdentityMD):** deploy the attested bytecode, run the protected launch checks,
  distribute the supply per the economics, and verify the source on the block explorer
  (`forge verify-contract` with solc 0.8.26, optimizer 200 runs, `bytecode_hash = "none"`,
  `cbor_metadata = false`). Explorer verification is an open item for the deployer; it is not done
  from this repository.
- **Everyone:** there is no admin to call in an emergency. Holders are responsible for their own
  approvals; approve exact amounts rather than unlimited allowances where possible.

## Security notes

Checked against the eth-security checklist supplied with the task:

- Access control: there are no privileged functions, so nothing to restrict.
- Reentrancy: the token makes no external calls.
- Decimals, oracles, swaps, proxies, signatures, delegatecall: not applicable; the token contains none
  of these.
- Input validation: inherited from OpenZeppelin (zero-address sender/receiver/spender revert with
  ERC-6093 errors).
- Events: `Transfer` and `Approval` on every state change.
- Automated analysis: `forge build`, `forge test` (including a 256-run fuzz test) and `forge fmt --check`
  were run. Slither and Mythril were not available in this environment and did not run.
