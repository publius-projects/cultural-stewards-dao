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
    // The live, deployed MandateRegistry on the target network — not something this org
    // redeploys. Resolved from Configurations rather than hardcoded so there is a single source
    // of truth: it returns 0x89b77a5eD85F6D442Cf703De8A03F286266de510 on both Ethereum Sepolia
    // and Arbitrum Sepolia, and reverts on a chain where no registry is deployed (clearer than
    // silently pointing at an address that holds no code).
    MandateRegistry registry = MandateRegistry(helperConfig.getMandateRegistry(block.chainid));

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
    // NB: 0.1.9 is the only version registered in the MandateRegistry above. Versions 0.1.7 and
    // earlier are not present there at all — a pinned lookup for them reverts with
    // MandateNotFound. Verified against the live registry on 2026-08-04.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    uint16 constant PACKAGE_SIZE = 7;

    // Adopt_Mandates versions independently of the repo-wide pin above: it sits at 0.2.0 while
    // every other mandate this org uses is at 0.1.9.
    uint16 constant ADOPT_MANDATES_MAJOR = 0;
    uint16 constant ADOPT_MANDATES_MINOR = 2;
    uint16 constant ADOPT_MANDATES_PATCH = 0;

    /// @notice The single runtime input parameter that Adopt_Mandates v0.2.0 declares.
    /// @dev This is `PowersTypes.MandateInitData[]` written out as a tuple signature:
    ///      (nameDescription, targetMandate, config, conditions), where conditions is
    ///      (allowedRole, votingPeriod, timelock, throttleExecution, needFulfilled,
    ///      needNotFulfilled, quorum, succeedAt, maxExecutionDelay). Every StatementOfIntent in a
    ///      reform flow — the proposal, each veto, and each checkpoint — must declare exactly
    ///      this one parameter, because `needFulfilled` matches on the action id, which is
    ///      derived from the calldata. A propose step with a different parameter shape produces a
    ///      different action id and can never satisfy the execute step.
    string constant ADOPT_MANDATES_PARAM =
        "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

    /// @notice Resolves Adopt_Mandates at its own pinned version (0.2.0).
    /// @dev Deliberately pinned rather than resolved via `registry.getLatestVersion`. The runtime
    ///      calldata shape changed between 0.1.9 and 0.2.0 — 0.1.9 took
    ///      `(address[] mandates, uint256[] roleIds)` and forced every adoption to an empty
    ///      config and zeroed conditions. Resolving "latest" would let a future registration
    ///      silently swap the contract underneath reform flows whose StatementOfIntent steps
    ///      still declare the old parameter shape, which breaks them at execution rather than at
    ///      deploy. Pinning fails loudly with MandateNotFound instead.
    function _adoptMandatesAddress() internal view returns (address) {
        return registry.getMandateAddress(
            ADOPT_MANDATES_MAJOR, ADOPT_MANDATES_MINOR, ADOPT_MANDATES_PATCH, "Adopt_Mandates"
        );
    }

    /// @notice The input-parameter array every reform-flow StatementOfIntent must be configured
    /// with, so proposal, veto and checkpoint steps all agree with the executing Adopt_Mandates.
    function _adoptMandatesParams() internal pure returns (string[] memory params) {
        params = new string[](1);
        params[0] = ADOPT_MANDATES_PARAM;
    }
}
