# Simulation Test Org — Operator Guide

## Overview

Simulation Test Org is a simplified, token-free, ZKPassport-free derivative of the Cultural
Stewardship DAO's federated four-layer governance structure, built to be demoed live in a single
~1.5 hour session. It has the same shape as the original: a **Primary Layer** holding a shared
Gnosis Safe treasury, a **Digital Layer** managing a shared codebase, many **Ideas Layers**
incubating initiatives, and many **Convergence Layers** managing physical events. Every on-chain
identity check (ZKPassport) and every token/NFT mechanism (activity token, art NFT) has been
removed and replaced with plain governance votes — see `Spec.md` for the full design rationale,
what changed, and the accepted limitations.

Two Ideas Layers, **"Yin"** and **"Yang"**, are pre-seeded after deployment so a live demo can
start with a real choice from the first action. Every Convergence Layer auto-assigns a designated
demo Steward account as its initial Legal Interfacer at creation, so funds can be requested
immediately after a Convergence Layer is created — no extra clicks.

All governance timing in this org is compressed for live demo purposes (2-minute votes, 1-minute
timelocks — see `Spec.md`'s "Demo Timing Policy"). **This is a testnet-only, demo-only
configuration, not a production security posture.**

## Prerequisites

Environment variables (see `.env.example`):

- `SEPOLIA_RPC_URL`, `ARB_SEPOLIA_RPC_URL`, `OPT_SEPOLIA_RPC_URL` — RPC endpoints (Alchemy/Infura)
- `ETHERSCAN_API_KEY` — for contract verification
- `DEPLOYER_ACCOUNT` / `DEPLOYER_ADDRESS` — a Foundry encrypted keystore for the deployer wallet.
  Run `make setup-wallet` for step-by-step instructions.
- `TEST_ACCOUNT_KEY_1` / `_2` / `_3` — three **throwaway** private keys used by the deploy scripts
  to seed initial test/demo role holders (Participants, Stewards, Assessors). Generate fresh keys
  for this purpose (`cast wallet new`) — never reuse a real wallet's key here.

## Mandate versions and the registry

This org resolves every mandate from the live `MandateRegistry`, whose address comes from
`Configurations.getMandateRegistry(block.chainid)` — `0x89b77a5eD85F6D442Cf703De8A03F286266de510` on
both Ethereum Sepolia and Arbitrum Sepolia. Mandates are pinned to **0.1.9**, the only version that
registry holds.

`Adopt_Mandates` is the one exception: it is pinned to **0.2.0**, which is what lets the reform flows
adopt fully configured mandates with real voting conditions (0.1.9 forced every adoption to an empty
config and zeroed conditions). It is pinned rather than resolved as "latest" on purpose — see
`Spec.md`'s "Refactor Notes" for why.

**Before deploying to a network for the first time**, make sure `Adopt_Mandates` 0.2.0 is registered
there. Run this as the registry owner:

```bash
cd ../../lib/powers-monorepo/solidity
forge script script/DeployMandates.s.sol:DeployMandates \
  --rpc-url $SEPOLIA_RPC_URL --account $DEPLOYER_ACCOUNT --sender $DEPLOYER_ADDRESS --broadcast -vv
```

The script is idempotent — it skips every mandate already registered and registers only what is
missing. Run it without `--broadcast` first to see exactly what it would touch. If this step is
skipped, deployment fails fast with `MandateNotFound(0, 2, 0, "Adopt_Mandates")`.

## Deployment

1. Copy the environment template and fill in your values:
   ```bash
   cp .env.example .env.local
   # edit .env.local
   ```
2. Create a deployer keystore:
   ```bash
   make setup-wallet
   ```
3. Deploy (choose a network):
   ```bash
   make deploy-arb-sepolia    # or: make deploy-sepolia / make deploy-anvil
   ```
   This deploys the Primary Layer (with its Safe treasury and `PowersPaymaster`), the Digital
   Layer, the Ideas Layer factory, and the Convergence Layer factory, and constitutes all four.
   It does **not** yet seed "Yin"/"Yang" — that is a separate step (below), because each phase of
   layer creation is gated by a real 2-minute voting window that cannot be skipped on a live
   network.
4. Seed the demo Ideas Layers:
   ```bash
   make initialise-runner   # prints the exact forge script command to run
   ```
   Run the printed command, wait ~2 minutes, run it again, wait, run it again — the runner is
   stateless and logs exactly what phase it executed and what it's waiting for. After three
   invocations "Yin" and "Yang" both exist and hold role 4 at the Primary Layer.

## Actions script (`actions/Roles.s.sol`, `actions/Management.s.sol`)

These are one-off interaction scripts for triggering specific governance flows (claim a role, vote
on a proposal, adopt a mandate). Use them for manual testing or to script a specific demo beat.
Example:

```bash
forge script governance/simulation-test-org/actions/Roles.s.sol:Roles \
  --sig "getParticipantRole_IdeasLayer(address,uint256[],uint256)" \
  <ideasLayerAddress> '[<key1>,<key2>]' 1 \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## Runner script (`actions/InitialiseRunner.s.sol`)

Stateless and idempotent: each call inspects on-chain state and advances every phase whose
voting/timelock window has already closed, then stops at the first phase still waiting. Safe to
run repeatedly (cron, or by hand) until it logs "seeding complete" / "demo setup complete".

```bash
forge script governance/simulation-test-org/actions/InitialiseRunner.s.sol:InitialiseRunner \
  --sig "run(address,address,uint256,string[],uint256[])" \
  <primaryLayer> <digitalLayer> 1 '["Yin","Yang"]' '[<key1>,<key2>]' \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Once Yin/Yang exist, `runConvergenceLayerDemo(address,string,uint256,uint256[])` drives the demo
Convergence Layer creation (e.g. "Basel Art Exhibition") from Yin, in the same stateless,
call-it-repeatedly style.

## Metadata URI

Each layer's metadata URI is already set (pointing at the same Pinata-hosted JSON bundle used by
the original Cultural Stewardship DAO — `baseURI` in `DeploySetup.s.sol`). If you want distinct
metadata for this org, update `baseURI` before deploying, or use the "Update URI" governance flow
on each layer afterward.

## Account Abstraction / Paymaster

A `PowersPaymaster` (ERC-4337) is deployed alongside the Primary Layer, sponsoring gas for members
interacting with the Primary Layer and Digital Layer (and, once created, every Ideas/Convergence
Layer instance — the deploy/initialisation flow registers each new layer as a sponsored target
automatically). This lets demo participants transact without holding testnet ETH themselves.
Check the paymaster's balance:

```bash
cast call <PAYMASTER_ADDRESS> "getDeposit()(uint256)" --rpc-url $SEPOLIA_RPC_URL
```

**TODO before your demo:** the deployer wallet funds the paymaster automatically during
`PrimaryLayer.run()` — confirm it holds enough ETH for gas *and* whatever deposit amount you want
sponsored (the deploy script does not pre-fund a large deposit by default; top it up manually via
`cast send <PAYMASTER_ADDRESS> "deposit()" --value <amount> ...` if needed before the live session).

## Testing

```bash
make test
```

Only `SEPOLIA_RPC_URL` is required — the test suite (`Test.t.sol`) uses synthetic, hardcoded
private key constants internally (never real keys). It forks Sepolia, deploys the full org, seeds
"Yin"/"Yang", and covers:

- Marc-style membership join to Yin (apply -> Assessor approval), plus a negative test showing the
  application is blocked without approval.
- Full "Basel Art Exhibition" Convergence Layer creation from Yin.
- The auto-assigned Legal Interfacer (the hardcoded demo Steward account, `hannah` in
  `DeploySetup.s.sol`) immediately requesting an allowance from the Primary Layer treasury — no
  extra nomination step required.
- The reform flow end to end: Stewards adopting a new, fully configured mandate through
  `Adopt_Mandates` 0.2.0 (asserting the adopted mandate keeps both its config and its conditions),
  plus a negative test showing a Participant veto blocks the adoption.

The suite registers `Adopt_Mandates` 0.2.0 on its fork if the live registry does not yet have it, so
it passes whether or not the registration transaction described above has been broadcast.

### A gotcha worth knowing when writing tests

`Powers` measures `succeedAt` against the **number of role holders**, not the number of votes cast
(`amountMembers * succeedAt <= forVotes * DENOMINATOR`). A mandate at `succeedAt = 66` whose role has
two holders needs *both* to vote FOR. Role 3 (Legal Interfacer) at every Convergence Layer has two
holders — `testAccount1` from the base setup and `hannah` from the demo auto-assignment — so any 66%
flow on that role currently requires unanimity. Worth checking before a live demo depends on `hannah`
acting alone.

## Troubleshooting

**`MandateNotFound(0, 2, 0, "Adopt_Mandates")` at deploy** — `Adopt_Mandates` 0.2.0 is not registered
on the target network. Run `DeployMandates.s.sol` as the registry owner (see "Mandate versions and the
registry" above).

**`MandateNotFound(0, 1, 9, "<name>")` at deploy** — the target network's registry does not hold the
0.1.9 mandate set at all. Check that `Configurations.getMandateRegistry` returns a non-zero address
for that chain and that a registry is actually deployed there; `Configurations` currently maps only
Ethereum Sepolia and Arbitrum Sepolia.

**"contract size limit" error at deploy** — if deploy fails with
`Error: ... is above the contract size limit (31409 > 24576)`, confirm `optimizer_runs = 600`,
`evm_version = "cancun"`, and `solc_version = "0.8.30"` are set under `[profile.default]` in the
repo root's `foundry.toml`, then run `forge clean && forge build --sizes` before deploying again.

**Files under `governance/simulation-test-org/` aren't picked up by `forge build`/`forge test`** —
this repo's `foundry.toml` only compiles `src/`, `test/`, `script/` and whatever they transitively
import; a file sitting only under `governance/` is invisible to Foundry until something under
`test/`/`script/` imports it. `test/integration/SimulationTestOrg.t.sol` is a one-line bridge file
that does exactly this for `Test.t.sol` (mirroring the same pattern the original Cultural
Stewardship DAO's `test/integration/CulturalStewardship.t.sol` uses for the top-level
`governance/Deploy.s.sol`). If you add new script files that should be reachable by `forge test`,
either import them from `Test.t.sol` (directly or transitively) or add your own bridge file.

## Live Demo Walkthrough

Maps the 17-step demo script to actual commands. Steps marked **(off-chain)** are social/narrative
— nothing to run.

| # | Demo beat | What happens |
|---|---|---|
| 1 | Explain the org | **(off-chain)** — walk through `Spec.md`'s Purpose/Architecture sections. |
| 2 | Open the forum | **(off-chain)** — whatever forum/chat tool the group already uses. |
| 3 | Marc logs in via account abstraction | **(off-chain UX, on-chain infra)** — Marc's wallet transacts through the `PowersPaymaster`; no gas needed on his end. Nothing to script — this is frontend wallet UX, sponsored automatically once the layer is a registered paymaster target. |
| 4 | Marc applies to Yin or Yang | `forge script .../Roles.s.sol:Roles --sig "getParticipantRole_IdeasLayer(...)"` — or, for the split apply/approve beats, call the "Apply for Participant role" mandate directly via the frontend/`cast send`. |
| 5 | Assessor approves | Same `Roles.getParticipantRole_IdeasLayer` call handles both steps; to show them as separate beats, call the "Apply..." mandate then the "Assess and Assign Participant" mandate separately. |
| 6 | Chat | **(off-chain)** — forum/chat conversation. |
| 7 | Add Ouroboros (or another member) | Repeat step 4/5 for the new member's address. |
| 8 | Decide on a Convergence Layer for the Basel exhibition | **(off-chain)** — narrative/community decision-making, fundraising conversation, feedback. |
| 9 | Create it | `InitialiseRunner.runConvergenceLayerDemo(primaryLayer, "Basel Art Exhibition", nonce, privateKeys)` — call repeatedly across its ~4 voting/timelock phases (see the Runner script section above). |
| 10 | Show the auto-assigned Legal Interfacer | `cast call <convergenceLayer> "hasRoleSince(address,uint256)(uint48)" <hannah-address> 3 --rpc-url $SEPOLIA_RPC_URL` — non-zero confirms the Legal Interfacer is already in place. |
| 11 | Request funds | Legal Interfacer calls the "Request allowance" mandate (`propose` -> vote -> `request`, or directly via frontend) — works immediately, no prior nomination step. |
| 12 | Show org overview | **(off-chain)** — the frontend's org dashboard (`/overview/[chainId]/[powers]/home`, per the monorepo's frontend routes). |
| 13–17 | Further discussion, feedback, next steps | **(off-chain)** — narrative wrap-up. |

Steps 1–3, 6, 8, 12–17 are entirely social/off-chain by design — the point of this org is that the
*governance mechanics* (steps 4–5, 7, 9–11) are the only parts that need to touch the chain, and
each one maps to a single mandate call or a short, repeatable runner invocation.
