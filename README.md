# AMBIDEX (AMBI)

A plain, fixed-supply ERC-20 token for the IdentityMD custom-token launch on Ethereum.

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
