// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { PowersFactory } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersFactory.sol";
import { DeployHelpers } from "@lib/powers-monorepo/solidity/governance/DeployHelpers.s.sol";
import { Configurations } from "@lib/powers-monorepo/solidity/script/Configurations.s.sol";

import { ElectionRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/ElectionRegistry.sol";
import { MandateRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/MandateRegistry.sol";

/// @title DeploySetup — Simulation Test Org
/// @notice Shared abstract base for the Simulation Test Org deploy scripts. This is a simplified,
/// token-free, ZKPassport-free derivative of the Cultural Stewardship DAO's DeploySetup.s.sol.
/// See governance/simulation-test-org/Spec.md for the full design rationale.
abstract contract DeploySetup is DeployHelpers {
    Configurations helperConfig = new Configurations();
    // Same registry as the original Cultural Stewardship DAO deployment — this is the live,
    // deployed MandateRegistry on the target testnets, not something this org redeploys.
    MandateRegistry registry = MandateRegistry(0x97b66F08Eb857e27A24492D338d3DC484DF63896);

    // Designated demo operator accounts (same accounts used by the original DAO's DeploySetup).
    // `hannah` is the account this org's Convergence Layer template auto-assigns as the initial
    // Legal Interfacer at creation — see ConvergenceLayer.s.sol's setup PresetActions calldata.
    address cedars = 0x95e51Ce331e9F81917d729C5b1F9127ca1138a01; // privy AA.
    address hannah = 0xc9ce1DC547C42F66464f5a7f0E3cd60EBf1C5Bd2;
    string baseURI = "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeifteuvxskmzqraitv3ho2gd7k5gbdjdt7uptxwqnojwituu5llcfy/";

    uint256 constitutionLength;
    address[] targets;
    uint256[] values;
    bytes4[] functionSelectors;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;
    uint16 mandateCount;
    address treasury;
    address paymaster;

    uint256 internal blocksPerHour; // to be set in setUp() of inheriting contracts.

    // Cached mandate addresses — populated per-layer via _initMandateAddresses().
    // NB: Soulbound1155/Governed721/GovernedToken_* and ZKPassport_Check caches are intentionally
    // omitted — this org uses neither tokens nor ZKPassport identity checks (see Spec.md).
    address internal m_Adopt_Mandates;
    address internal m_BespokeAction_Advanced;
    address internal m_BespokeAction_OnReturnValue;
    address internal m_BespokeAction_Simple;
    address internal m_ElectionRegistry_CleanUpVoteMandate;
    address internal m_ElectionRegistry_CreateVoteMandate;
    address internal m_ElectionRegistry_Nominate;
    address internal m_ElectionRegistry_Tally;
    address internal m_ElectionRegistry_Vote;
    address internal m_ExternalAction_Flexible;
    address internal m_ExternalAction_Simple;
    address internal m_Nominate;
    address internal m_PauseMandates;
    address internal m_PeerSelect;
    address internal m_PresetActions;
    address internal m_PresetActions_OnOwnPowers;
    address internal m_SafeAllowance_Action;
    address internal m_SafeAllowance_Transfer;
    address internal m_Safe_ExecTransaction;
    address internal m_Safe_ExecTransaction_OnReturnValue;
    address internal m_Safe_RecoverTokens;
    address internal m_StatementOfIntent;

    // The mandate version to be used.
    // NB: kept at 0.1.7 to match the version actually registered and proven against the live
    // MandateRegistry above (the same registry the original Cultural Stewardship DAO deploys
    // against) — see the judgment-call note in this org's deployment report.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 7;

    uint16 constant PACKAGE_SIZE = 7;

    /// @notice Resolves a mandate at its latest registered version rather than the (MAJOR, MINOR,
    /// PATCH) pin above. Adopt_Mandates has moved to 0.2.0 — a pinned lookup for it reverts with
    /// MandateNotFound (or silently resolves a stale version), so every layer must use this for
    /// Adopt_Mandates specifically.
    function _latestMandateAddress(string memory name) internal view returns (address) {
        (uint16 major, uint16 minor, uint16 patch) = registry.getLatestVersion(name);
        return registry.getMandateAddress(major, minor, patch, name);
    }
}
