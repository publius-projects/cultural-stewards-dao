# Simulation Test Org — Governance Specification

> **Status:** Draft
> **Network:** Sepolia (testnet)
> **Design date:** 2026-08-03
> **Derived from:** The Cultural Stewardship DAO (`governance/PrimaryLayer.s.sol`, `DigitalLayer.s.sol`, `IdeasLayer.s.sol`, `ConvergenceLayer.s.sol`), with all identity-verification and token/tokenomics mandates removed or replaced.

---

## Purpose

Simulation Test Org is a simplified, token-free, ZKPassport-free version of the Cultural Stewardship DAO's federated four-layer structure. It exists to test whether the same governance shape — a central treasury-holding Primary Layer coordinating a Digital Layer, many Ideas Layers, and many Convergence (physical-event) Layers — still functions cleanly once every on-chain identity check and every token-based incentive mechanism is stripped out and replaced with plain governance votes. It manages the same kinds of decisions as the original (who joins, who leads, how the shared Safe treasury is spent, how new layers spin up and wind down, how the constitution itself evolves) without minting, gating on, or transacting in any token.

---

## Demo Timing Policy

This org is built to be demoed live in a single ~1.5 hour session, so every timed governance parameter across all four layers is compressed to a fixed, short scale instead of the original's day/week-scale figures (and even the original's existing minute-scale figures, e.g. its 5–10 minute timelocks and 7-minute throttles, are compressed further). This is a blanket policy applied uniformly — every mandate that had a `votingPeriod`, `timelock`, or `throttleExecution` in the original design gets one of the values below instead, with no exceptions:

| Parameter | Value | Applies to |
|---|---|---|
| `votingPeriod` | 2 minutes | Every voted mandate (proposals, vetoes, election windows) |
| `timelock` | 1 minute | Every mandate with a post-vote execution delay |
| `throttleExecution` | 1 minute | Election-creation and other throttled mandates |
| `maxExecutionDelay` | 2 minutes | Any quorum-gated mandate reading mutable state (stale-state rule, matches `votingPeriod`) |

**Quorum and succeed-at thresholds are also lowered**, not just timing — with a demo audience of a handful of synthetic test wallets, the original's higher thresholds (some as high as 77–80%) would be hard to clear even with unanimous participation once you account for role holders who aren't part of the demo script. Two tiers are used throughout, replacing all of the original's bespoke per-flow percentages:

| Tier | Quorum | Succeed-at | Used for |
|---|---|---|---|
| Standard vote | 20% | 51% | Ordinary proposals, applications, allowance requests |
| Veto / high-trust action | 30% | 66% | Vetoes, mandate reform, role revocation |

**Consequence for the longest flow** (Primary Layer's 9-step Adopt Mandate reform, or a 6-step formal election): at 2 minutes voting + 1 minute timelock per gated step, even the longest chained flow completes in well under 15 minutes — comfortably repeatable multiple times within the demo session. This is a testnet-only, demo-only configuration; it is **not** a production security posture (see Limitations).

---

## What changed from the original, and why

Three explicit removals were requested: ZKPassport identity checks, all tokens/NFTs, and general simplification where it didn't conflict with keeping the two governance-heavy flows (multi-party reform veto, formal timed elections) intact — those two were explicitly kept as-is per your choice.

| Removed | Was used for | Replacement |
|---|---|---|
| `ZKPassport_Check` (age ≥18) — Ideas Layer | Gating who could be nominated as a Convergence Layer's Legal Interfacer | Dropped. Nomination is now open to any Participant; eligibility is a self-attested boolean carried in the proposal, not cryptographically checked. |
| `ZKPassport_Check` (issuing country = GBR) — Ideas Layer | Same flow, second gate | Same self-attestation field, second boolean (`AttestsGBREligible`). Not verified — just recorded on-chain as part of the proposal. |
| `ZKPassport_Check` (age ≥18) — Convergence Layer | Gating who could nominate themselves as a Steward | Dropped with no direct replacement — the `Nominate` mandate's fixed input schema (`bool shouldNominate`) has no room to carry an attestation payload, so nomination is now simply open. Flagged under Limitations. |
| `Soulbound1155` "activity token" (POAP) | Gating the Primary Layer's Participant role and the Convergence Layer's Attendee role; minted by Convergence Layers via a Primary Layer mandate | Both roles now use a governance-approved application: applicant submits a `StatementOfIntent`, a trusted role votes to approve and assigns the role directly. No token is minted, held, or checked anywhere. |
| `Governed721` "real-world-asset" NFT | The Convergence Layer's "Sell NFT artwork" flow (on-chain art sale with royalty splits) | Removed outright — no replacement. This capability (tokenised sale of physical artworks) is out of scope for this org; flagged under Limitations. |
| Primary Layer's `GovernedToken_MintEncodedToken` mandate | Minted the activity token on request from any Convergence Layer | Removed outright — nothing to mint. |
| Convergence Layer's "Mint POAP" forwarding mandate | Called the above | Removed outright — its target no longer exists. |
| Convergence Layer's stale `PauseMandates` target string `"Vote on 'Merit' NFT proposals"` | Referenced a mandate that was never actually adopted in the original file (a pre-existing bug/drift, unrelated to tokens) | Pause-target list rebuilt to reference mandates that genuinely exist in this org. |
| `zkPassport_PowersRegistry` wiring in the deploy script | Passed a hardcoded ZKPassport registry address into Ideas Layer and Convergence Layer constitution | Removed — no ZKPassport dependency anywhere. |

**Deliberately kept unchanged**, per your explicit choice:
- The Primary Layer's 9-mandate "Adopt Mandate" reform flow (4-way parallel veto from Participants, Digital, Ideas, and Convergence layers, chained through 3 sequential checkpoints, then execution). Still 9 steps — this is inherent to checking 4 independent veto conditions with the protocol's single `needFulfilled`/`needNotFulfilled` fields per mandate, not something a token/ZKP removal touches.
- The formal, timed `ElectionRegistry`-based election cycle (create → nominate → open vote → tally → cleanup) used for Primary Stewards, Digital "Repository admins," and Ideas Stewards. Still 6 steps per layer.
- The Digital Layer is untouched entirely — it never used tokens or ZKPassport.
- The Safe treasury, allowance-module spending model, and `PowersPaymaster` (gasless transactions) are unaffected — none of these are part of the DAO's own token/tokenomics system; they're infrastructure for moving real ETH/ERC-20 funds and sponsoring gas, which is out of scope for "remove tokens."
- `Nominate` + `PeerSelect` (used for Convergence Layer Steward selection) are kept — they are a peer-voting mechanism, not a token or an identity check.

---

## Architecture (unchanged shape)

Four Powers instances/factories, federated:

1. **Primary Layer** — single `Powers` instance. Holds the shared Safe treasury, creates/deactivates Ideas and Convergence Layers, elects Stewards, approves Participant applications, arbitrates mandate reform.
2. **Digital Layer** — single `Powers` instance. Manages the shared codebase/repo, funded by an allowance from the Primary Layer treasury.
3. **Ideas Layer** — `PowersFactory` template; many instances possible. Incubates new initiatives, proposes new Convergence Layers, proposes Legal Interfacers for them.
4. **Convergence Layer** — `PowersFactory` template; many instances possible. Manages a physical event/space: Attendee membership, Steward leadership, Legal Interfacer compliance role, receipt payments.

---

## Demo Setup — Pre-Seeded State

Built for a specific live-demo walkthrough (join an Ideas Layer → create a Convergence Layer → request funds, all within one ~1.5 hour session). Two pieces of state are pre-seeded before the session starts, rather than created live, so the walkthrough isn't blocked on setup steps that aren't the point of the demo:

1. **Two Ideas Layers exist from deployment**, named **"Yin"** and **"Yang"**, so a joining member has a real choice ("option A or B") from the first live action, instead of the group having to create both layers on the spot. Seeded by the deploy/initialisation script, not a live demo step.

2. **Every Convergence Layer auto-assigns an initial Legal Interfacer at creation**, via its own `PresetActions`/`PresetActions_OnOwnPowers` setup mandate (the same mandate that labels its roles and revokes the setup role). The initial holder is a designated demo Steward account — the same hardcoded operator accounts already used for initial Primary Layer Stewards in `DeploySetup.s.sol` — not the account that proposed the layer's creation. This is a deliberate technical simplification: `PresetActions`'s calldata is fixed at template-build time (the same Convergence Layer template is reused for every instance the factory spawns), so it cannot reference "whoever happens to propose this particular layer" dynamically — doing that would require chaining a `BespokeAction_OnReturnValue` off the Primary Layer's creation call, which reintroduces exactly the kind of multi-step complexity this pre-seeding is meant to avoid. The **existing** "Assign Legal Interfacer" mandate (Ideas Layer nominates → Primary Layer veto window → Steward executes) is unchanged and still there for *replacing* the Legal Interfacer later — this pre-seeding only covers who holds the role at the moment of creation, so step 13 ("Request funds") works immediately after step 12 with no extra clicks.

---

## Roles

### Primary Layer

| Role ID | Name | How to join | Notes |
|---|---|---|---|
| 0 | Setup Initiator | Assigned at deployment, revokes itself | |
| max | Public | Automatic | |
| 1 | Participants | Governance-approved application (see below) | Was token-gated; now vote-gated |
| 2 | Stewards | Elected every N months via formal election | Unchanged |
| 3 | Convergence Layers | Assigned at creation of a Convergence Layer | Unchanged |
| 4 | Ideas Layers | Assigned at creation of an Ideas Layer | Unchanged |
| 5 | Digital Layers | Assigned at creation (singleton) | Unchanged |

### Digital Layer

| Role ID | Name | How to join | Notes |
|---|---|---|---|
| 0 | Admin | Assigned at deployment, revokes itself | |
| max | Read | Automatic | |
| 1 | Write | Elected/assigned per existing flow (unchanged — no tokens involved) | |
| 2 | Maintain | Elected every N months | |
| 6 | Primary Layer | Assigned at creation | |
| 7 | Convergence Layer | Assigned by Primary Layer | |

### Ideas Layer

| Role ID | Name | How to join | Notes |
|---|---|---|---|
| 0 | Setup Initiator | Assigned at deployment, revokes itself | |
| max | Public | Automatic | |
| 1 | Participants | Apply → Assessors approve (unchanged, already vote-based) | |
| 2 | Stewards | Elected every N months via formal election | Unchanged |
| 3 | Assessors | Assigned/revoked by Stewards | Unchanged |
| 6 | Primary Layer | Assigned at creation | |

### Convergence Layer

| Role ID | Name | How to join | Notes |
|---|---|---|---|
| 0 | Ideas Layer (parent) | Assigned at creation | |
| max | Public | Automatic | |
| 1 | Attendee | **Governance-approved application (new)** — was token-gated | |
| 2 | Steward | Peer-selected from open nominees (ZKP age check dropped) | |
| 3 | Legal Interfacer | **Auto-assigned to a designated demo Steward account at creation** (see Demo Setup above); replaceable later via nomination with self-attestation + Steward execution | |
| 6 | Primary Layer | Assigned at creation | |

---

## Governance Flows

Only flows that changed are detailed step-by-step below. All other flows (layer creation/revocation, allowance requests, receipts, URI updates, treasury recovery, elections, Digital Layer's entire mandate set, the Adopt Mandate reform flow) are carried over from the original Cultural Stewardship DAO unchanged, with token/ZKP wiring removed where it appeared only as an unused parameter (e.g. the `zkPassport_PowersRegistry` constructor argument).

### Flow: Claim Participant Role (Primary Layer)

**Purpose:** Let someone who is already active in an Ideas Layer become a voting Participant at the Primary Layer, without proving token ownership.

| Step | Mandate type | Who can call | Voting? | Conditions |
|---|---|---|---|---|
| 1 | StatementOfIntent | Ideas Layer (role 4) | No | Forwards a request on behalf of a candidate |
| 2 | BespokeAction_Advanced | Stewards (role 2) | Yes — simple majority | `needFulfilled` = step 1; assigns role 1 directly |

**Rationale:** Mirrors the pattern the Ideas Layer already uses for its own Participant applications (apply → trusted role approves and assigns) — no new mandate pattern introduced, just reused consistently.

### Flow: Claim Attendee Role (Convergence Layer)

**Purpose:** Let a member of the public become a voting Attendee of a specific physical-event layer, without proving POAP ownership.

| Step | Mandate type | Who can call | Voting? | Conditions |
|---|---|---|---|---|
| 1 | StatementOfIntent | Public | No | Throttled application |
| 2 | BespokeAction_Advanced | Steward (role 2) | Yes — simple majority | `needFulfilled` = step 1; assigns role 1 directly |

**Rationale:** Identical shape to the Primary Layer flow above and to the Ideas Layer's existing Participant flow — one consistent "apply, trusted role approves" pattern used everywhere membership isn't automatic.

### Flow: Propose Legal Interfacer for Convergence Layer (Ideas Layer)

**Purpose:** Nominate someone to hold the compliance-facing Legal Interfacer role at a specific Convergence Layer, without cryptographic identity verification.

| Step | Mandate type | Who can call | Voting? | Conditions |
|---|---|---|---|---|
| 1 | StatementOfIntent | Participants (role 1) | No | Input includes `address Candidate`, `bool AttestsAge18Plus`, `bool AttestsGBREligible` — self-attested, not verified |
| 2 | StatementOfIntent (veto) | Primary Layer (role 6) | Yes | `needFulfilled` = step 1 |
| 3 | ExternalAction_Simple | Stewards (role 2) | Yes | `needFulfilled` = step 1, `needNotFulfilled` = step 2; calls the target Convergence Layer's "Assign Legal Interfacer" mandate directly with the candidate's address |

**Rationale:** Same three-role shape as the original (propose → Primary Layer veto → Stewards execute), just without the two ZKPassport steps at the front. The candidate's eligibility claims travel with the proposal as plain booleans instead of a verified proof — see Limitations.

### Flow: Select Stewards (Convergence Layer)

**Purpose:** Elect Stewards to lead a Convergence Layer via peer selection.

| Step | Mandate type | Who can call | Voting? | Conditions |
|---|---|---|---|---|
| 1 | Nominate | Public | No | Open nomination — no age check |
| 2 | BespokeAction_Advanced (revoke nomination) | Legal Interfacer (role 3) | No | — |
| 3 | PeerSelect | Legal Interfacer (role 3) | Yes | Selects up to 3 Stewards from the nominee pool |

**Rationale:** Same as original minus the ZKPassport age-check step. See Limitations for why this couldn't carry a self-attestation replacement.

---

## Checks and Balances

Unchanged from the original — none of these depended on tokens or ZKPassport:

| Mechanism | How it works | Who holds it |
|---|---|---|
| Multi-party reform veto | Primary Layer mandate adoption requires passing 4 independent vetoes (Participants, Digital, Ideas, Convergence layers) before Stewards can execute | Participants, Digital Layer, Ideas Layer, Convergence Layer |
| Timelocks on layer creation/revocation | Delay between proposal and execution on layer creation, revocation, and role/allowance changes | Automatic |
| Formal timed elections | Fixed start/end block voting windows for Steward-type roles | Role holders of each layer |
| Legal Interfacer veto | Primary Layer can block a proposed Legal Interfacer before assignment | Primary Layer (role 6) |
| Member veto on revocation | Revoking a Participant/Attendee/Writer requires passing a veto window first | Participants / Attendees / Writers |

**Security considerations:**
- The self-attestation fields on Legal Interfacer proposals (`AttestsAge18Plus`, `AttestsGBREligible`) are **not verified on-chain in any way** — they are booleans anyone can set to `true` regardless of truth. This is a real reduction in assurance versus the ZKPassport-verified original, accepted as part of this simplification.
- Convergence Layer Steward nomination now has no eligibility gate at all (dropped, not replaced) — anyone can nominate themselves regardless of age.
- Governance-approved applications (Participant/Attendee) replace a possession-based check (token ownership) with a discretionary vote — this shifts trust from "cryptographic proof" to "the approving role's judgment," which is a different, not strictly weaker, kind of assurance, but is worth naming explicitly.

---

## External Dependencies

| System | Purpose | Required? |
|---|---|---|
| Gnosis Safe | Central treasury for the Primary Layer, with an Allowance Module for Digital/Convergence Layer spending | Yes |
| `ElectionRegistry` helper contract | Runs the formal timed election cycle for Steward-type roles | Yes |
| `Nominees` helper contract | Candidate pool for Convergence Layer Steward `PeerSelect` | Yes |
| `PowersPaymaster` (ERC-4337) | Gasless transactions, unchanged from original | Yes (carried over) |
| ~~`Soulbound1155` activity token~~ | ~~POAP/Participant gating~~ | **Removed** |
| ~~`Governed721` art NFT~~ | ~~Art sale flow~~ | **Removed** |
| ~~ZKPassport registry~~ | ~~Age/country verification~~ | **Removed** |

---

## Costs & Paid Mandates

No paid mandates — deployment incurs gas only. Every mandate used in this design (`StatementOfIntent`, `BespokeAction_Advanced`, `BespokeAction_Simple`, `BespokeAction_OnReturnValue`, `ExternalAction_Simple`, `ExternalAction_OnReturnValue`, `ElectionRegistry_*`, `Nominate`, `PeerSelect`, `Adopt_Mandates`, `PauseMandates`, `Safe_ExecTransaction*`, `SafeAllowance_*`, `Safe_RecoverTokens`, `PresetActions*`) was checked against the current `priceInCredits()` discovery and is free.

---

## Design Rationale

The original Cultural Stewardship DAO used two mechanisms to establish trust without relying purely on discretionary votes: cryptographic identity proofs (ZKPassport) for compliance-sensitive roles, and possession-based tokens (POAPs, activity tokens) for membership and attendance tracking. Both are legitimate design patterns, but they add real complexity — external oracle dependencies, extra mandate steps, token contracts to deploy and own — for organisations that don't need that level of assurance (e.g. a test/simulation deployment, or a community that would rather trust its elected Stewards' judgment than a cryptographic proof).

Removing them required deciding, case by case, what should stand in their place. Where the original mechanism gated a *role* (Participant, Attendee), the closest fit already existed elsewhere in the same DAO: the Ideas Layer's own Participant-application pattern (apply, trusted role approves). Reusing that pattern everywhere keeps the design internally consistent rather than inventing a new mechanism per layer. Where the original mechanism gated a *proposal* (Legal Interfacer eligibility), a self-attestation field preserves the shape of "a claim is made and recorded" without the cryptographic backing — a deliberately weaker but simpler substitute, flagged clearly under Limitations so it's not mistaken for real verification.

Where you chose to keep the heavier existing mechanisms (the 9-step reform veto chain, the 6-step formal election cycle), no changes were made — this confirms the "simplify institutional structure" instruction was scoped to token/identity removal specifically, not a wholesale reduction of governance formality.

---

## Limitations

- **No real identity verification anywhere in this org.** The self-attestation fields on Legal Interfacer proposals are unverified booleans. Anyone can claim eligibility falsely; the only safeguard is the Primary Layer's veto and the Stewards' discretion at execution.
- **Convergence Layer Steward nomination has no eligibility gate at all** (age or otherwise) — the `Nominate` mandate's fixed `bool shouldNominate` input schema cannot carry an attestation payload, so this instance of ZKPassport removal has no direct replacement, unlike the Legal Interfacer flow.
- **No on-chain art/artwork sale mechanism.** The original `Governed721`-based "Sell NFT artwork" flow is gone entirely with no substitute — if a Convergence Layer needs to sell a physical or digital artwork, that has to happen off-chain.
- **No attendance/participation record.** Removing POAPs means there is no on-chain trace of who attended what, which was previously a side effect of the token-gating mechanism. Membership approval is now a point-in-time governance decision with no persistent proof-of-attendance artifact.
- **Governance-approved applications introduce discretion where token-gating was objective.** A Steward or Assessor now decides, case by case, whether to approve a Participant/Attendee application — this is slower and more subjective than an automatic token check, though it also allows judgment calls a pure token check couldn't make.
- **Timing and thresholds are tuned for a live demo, not production security.** 2-minute voting windows, 1-minute timelocks, and 20–30% quorum are trivial to game or rush in a real deployment with real stakes — an attacker (or an inattentive minority) could pass a proposal before most role holders even notice it exists. Before this org (or anything derived from it) is used for anything beyond demonstration, every `votingPeriod`/`timelock`/`quorum`/`succeedAt` value needs to be reset to production-appropriate scale (see Appendix A.4 of the design-org skill for size-based heuristics).

---

## Implementation Notes

> This section is for the developer implementing the deploy scripts.

This org mirrors the original Cultural Stewardship DAO's **multi-file deploy pattern** (not the single-`Deploy.s.sol` template), since the federated four-layer shape with two `PowersFactory` templates doesn't fit in one file. Generated files:

- `governance/simulation-test-org/DeploySetup.s.sol` — shared abstract base (registry address, deployer accounts, mandate-address cache, mandate version)
- `governance/simulation-test-org/Helpers.s.sol` — deploys shared helper contracts (`ElectionRegistry`, `Nominees`; **no** `Soulbound1155`/`Governed721`)
- `governance/simulation-test-org/PrimaryLayer.s.sol`
- `governance/simulation-test-org/DigitalLayer.s.sol` (carried over unchanged from the original, imports updated)
- `governance/simulation-test-org/IdeasLayer.s.sol`
- `governance/simulation-test-org/ConvergenceLayer.s.sol`
- `governance/simulation-test-org/Deploy.s.sol` — top-level orchestrator (no `zkPassport_PowersRegistry` wiring, no token ownership transfers); after constituting the Primary Layer, calls the Ideas Layer factory twice via the same "Create Ideas Layer" chain used live during a demo, naming the two seeded instances **"Yin"** and **"Yang"**, so both exist before the session starts
- `governance/simulation-test-org/actions/` — `ActionHelpers.s.sol`, `Roles.s.sol`, `Management.s.sol`, `Initialise.s.sol`, `InitialiseRunner.s.sol` (adapted from `governance/actions/`, with token/ZKP-specific action functions removed); `Initialise.s.sol`/`InitialiseRunner.s.sol` drive the "Yin"/"Yang" seeding above so it's scriptable and repeatable ahead of each demo run
- Convergence Layer template's setup `PresetActions` calldata includes an extra `assignRole(3, <designated demo Steward address>)` call alongside the existing role-labelling calls, so Legal Interfacer is populated at creation with no live nomination step
- `governance/simulation-test-org/Test.t.sol`
- `governance/simulation-test-org/README.md`
- `governance/simulation-test-org/Makefile`
- `governance/simulation-test-org/.env.example`

**Mandate version:** MAJOR=0, MINOR=1, PATCH=9 (except `Adopt_Mandates`, resolved via `getLatestVersion`), matching `DeploySetup.s.sol`'s existing `0.1.7` cache-versioning convention where it differs.
**Mandate `nameDescription` strings must match exactly across all files** that reference them (deploy scripts, actions, runners).
