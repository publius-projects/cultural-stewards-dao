// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Initialise } from "./Initialise.s.sol";

/// @title InitialiseRunner
/// @notice Stateful checkpoint runner for the Simulation Test Org initialisation flow. Adapted
/// from the Cultural Stewardship DAO's governance/actions/InitialiseRunner.s.sol. Drives the
/// Spec.md "Demo Setup" seeding of the two Ideas Layers named "Yin" and "Yang", plus (optionally)
/// a demo Convergence Layer.
///
/// Call run() repeatedly. Each invocation reads on-chain state to determine which
/// phases are already complete, executes every phase whose preconditions are now
/// met, and stops at the first phase still waiting on a voting window or timelock.
/// The runner logs what it executed and what it is waiting for.
///
/// Usage in Foundry tests:
///   runner.run(...); vm.roll(n); runner.run(...); // repeat until "complete" is logged
///
/// Usage on a live chain:
///   forge script InitialiseRunner --sig "run(...)" ...  // repeat after each window closes
///   (Demo Timing Policy: 2-minute voting windows, 1-minute timelocks — a full pass through
///   every phase takes only a few minutes of real waiting between invocations.)
contract InitialiseRunner is Initialise {

    ///////////////////////////////////////////////////////////////////////////
    //                        MANDATE ID STRUCTS
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Pre-resolved mandate IDs for the Primary Layer initialisation flow.
    struct PrimaryLayerMandateIds {
        uint16 initialSetup;
        uint16 initiateIdeasLayer;
        uint16 createIdeasLayer;
        uint16 assignRoleToIdeasLayer;
        uint16 registerIdeasLayerToPaymaster;
        uint16 assignRoleToConvergenceLayer;
        uint16 assignDelegateStatus;
        uint16 registerConvergenceLayerToPaymaster;
    }

    /// @dev Pre-resolved mandate IDs for an Ideas Layer initialisation flow.
    struct IdeasLayerMandateIds {
        uint16 requestNewConvergenceLayer;
        uint16 sendRequest;
    }

    ///////////////////////////////////////////////////////////////////////////
    //                            MAIN RUNNER
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Advance the initialisation flow as far as current on-chain state allows.
    /// @param primaryLayer   Address of the deployed Primary Layer.
    /// @param digitalLayer   Address of the deployed Digital Layer.
    /// @param nonce          Nonce used to derive deterministic action IDs.
    /// @param ideasLayerNames Names of the Ideas Layers to deploy — pass ["Yin", "Yang"] to match
    ///                        Spec.md's "Demo Setup — Pre-Seeded State".
    /// @param privateKeys    Keys with permission to execute each governance step.
    function run(
        address primaryLayer,
        address digitalLayer,
        uint256 nonce,
        string[] memory ideasLayerNames,
        uint256[] memory privateKeys
    ) public {
        uint256 ideasCount = ideasLayerNames.length;

        // Resolve all Primary Layer mandate IDs in one cache scan.
        PrimaryLayerMandateIds memory p = _resolvePrimaryLayerMandateIds(primaryLayer);

        // ── Phase 0: Initial setup mandates (no voting, execute immediately) ─────
        if (!_isSetupComplete(primaryLayer)) {
            console2.log("Runner [0]: running Primary Layer setup mandate.");
            runSetupMandate(primaryLayer, nonce, privateKeys);
        }
        if (!_isSetupComplete(digitalLayer)) {
            console2.log("Runner [0]: running Digital Layer setup mandate.");
            runSetupMandate(digitalLayer, nonce, privateKeys);
        }

        // ── Phase 1: Propose Ideas Layer initiation (one proposal per layer) ─────
        if (!_haveActionsBeenSubmitted(primaryLayer, p.initiateIdeasLayer, ideasCount)) {
            console2.log("Runner [1]: proposing Ideas Layer initiation (Yin/Yang).");
            deployIdeasLayer1(primaryLayer, nonce, ideasLayerNames, privateKeys);
            console2.log("Runner: pausing. initiation voting window must close before phase 2.");
            return;
        }

        // ── Phase 2: Execute initiation proposals + propose creation ─────────────
        if (!_haveActionsBeenSubmitted(primaryLayer, p.createIdeasLayer, ideasCount)) {
            if (!_isPastDeadline(primaryLayer, p.initiateIdeasLayer, ideasCount)) {
                console2.log("Runner: pausing... initiation voting window still open.");
                _logBlocksRemaining(primaryLayer, p.initiateIdeasLayer, ideasCount);
                return;
            }
            console2.log("Runner [2]: executing initiation + proposing Ideas Layer creation.");
            deployIdeasLayer2(primaryLayer, nonce, ideasLayerNames, privateKeys);
            console2.log("Runner: pausing... creation voting window must close before phase 3.");
            return;
        }

        // ── Phase 3: Execute creation proposals (Ideas Layers are deployed) ───────
        if (!_areIdeasLayersDeployed(primaryLayer, ideasCount)) {
            if (!_isPastDeadline(primaryLayer, p.createIdeasLayer, ideasCount)) {
                console2.log("Runner: pausing... creation voting window still open.");
                _logBlocksRemaining(primaryLayer, p.createIdeasLayer, ideasCount);
                return;
            }
            console2.log("Runner [3]: deploying Ideas Layers (Yin, Yang).");
            deployIdeasLayer3(primaryLayer, nonce, ideasLayerNames, privateKeys);
        }

        console2.log("Runner: Yin/Yang Ideas Layer seeding complete!");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                  OPTIONAL: DEMO CONVERGENCE LAYER
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Advance the demo Convergence Layer creation flow (e.g. "Basel Art Exhibition"),
    /// spawned from the first seeded Ideas Layer (index 0, expected to be "Yin"). Call this
    /// separately, after run() above has completed and Yin holds role 4 at the Primary Layer.
    function runConvergenceLayerDemo(
        address primaryLayer,
        string memory layerName,
        uint256 nonce,
        uint256[] memory privateKeys
    ) public {
        PrimaryLayerMandateIds memory p = _resolvePrimaryLayerMandateIds(primaryLayer);
        address ideasLayer0 = Powers(payable(primaryLayer)).getRoleHolderAtIndex(4, 0);
        IdeasLayerMandateIds memory il = _resolveIdeasLayerMandateIds(ideasLayer0);

        // ── Phase 4: Propose Convergence Layer request at Ideas Layer 0 ──────────
        if (!_haveActionsBeenSubmitted(ideasLayer0, il.requestNewConvergenceLayer, 1)) {
            console2.log("Runner [4]: proposing Convergence Layer request.");
            deployConvergenceLayer1(ideasLayer0, layerName, nonce, privateKeys);
            console2.log("Runner: pausing... convergence request voting window must close before phase 5.");
            return;
        }

        // ── Phase 5: Execute request + propose send-request to Primary Layer ──────
        if (!_haveActionsBeenSubmitted(ideasLayer0, il.sendRequest, 1)) {
            if (!_isPastDeadline(ideasLayer0, il.requestNewConvergenceLayer, 1)) {
                console2.log("Runner: pausing... convergence request voting window still open.");
                _logBlocksRemaining(ideasLayer0, il.requestNewConvergenceLayer, 1);
                return;
            }
            console2.log("Runner [5]: executing convergence request + proposing send-request.");
            deployConvergenceLayer2(ideasLayer0, layerName, nonce, privateKeys);
            console2.log("Runner: pausing... send-request voting window must close before phase 6.");
            return;
        }

        // ── Phase 6: Execute send-request (triggers Convergence Layer creation) ───
        if (!_isConvergenceLayerDeployed(primaryLayer)) {
            if (!_isPastDeadline(ideasLayer0, il.sendRequest, 1)) {
                console2.log("Runner: pausing... send-request voting window still open.");
                _logBlocksRemaining(ideasLayer0, il.sendRequest, 1);
                return;
            }
            console2.log("Runner [6]: sending request... Convergence Layer being created.");
            deployConvergenceLayer3(ideasLayer0, layerName, nonce, privateKeys);
        }

        // ── Phase 7: Propose role-assignment + delegate + paymaster ───────────────
        if (!_haveActionsBeenSubmitted(primaryLayer, p.assignRoleToConvergenceLayer, 1)) {
            console2.log("Runner [7]: proposing Convergence Layer role assignments.");
            deployConvergenceLayer4(primaryLayer, layerName, nonce, privateKeys);
            console2.log("Runner: pausing... assignment voting/timelock must pass before phase 8.");
            return;
        }

        // ── Phase 8: Execute assignments + unpack reform packages ─────────────────
        address convergenceLayer = Powers(payable(primaryLayer)).getRoleHolderAtIndex(3, 0);
        if (!_isSetupComplete(convergenceLayer)) {
            if (!_isPastDeadline(primaryLayer, p.assignRoleToConvergenceLayer, 1)) {
                console2.log("Runner: pausing... assignment voting/timelock still active.");
                _logBlocksRemaining(primaryLayer, p.assignRoleToConvergenceLayer, 1);
                return;
            }
            console2.log("Runner [8]: finalising Convergence Layer.");
            deployConvergenceLayer5(primaryLayer, layerName, nonce, privateKeys);
        }

        console2.log("Runner: Convergence Layer demo setup complete!");
    }

    ///////////////////////////////////////////////////////////////////////////
    //                      MANDATE ID RESOLUTION
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Loads the Primary Layer mandate cache once and returns all IDs needed
    ///      for the full initialisation flow. Subsequent lookups hit the in-memory
    ///      cache and do not repeat the RPC scan.
    function _resolvePrimaryLayerMandateIds(
        address primaryLayer
    ) internal returns (PrimaryLayerMandateIds memory ids) {
        Powers org = Powers(payable(primaryLayer));
        _loadMandateCache(org);

        ids.initialSetup                        = findMandateIdInOrg("Initial Setup: Assign role labels and revokes itself after execution", org);
        ids.initiateIdeasLayer                  = findMandateIdInOrg("Initiate Ideas Layer: Initiate creation of Ideas Layer", org);
        ids.createIdeasLayer                    = findMandateIdInOrg("Create Ideas Layer: Execute Ideas Layer creation", org);
        ids.assignRoleToIdeasLayer              = findMandateIdInOrg("Assign role Id to layer: Assign role id 4 (Ideas Layer) to the new layer", org);
        ids.registerIdeasLayerToPaymaster       = findMandateIdInOrg("Register Ideas Layer to Paymaster: Register the new Ideas Layer to the paymaster as a sponsored target", org);
        ids.assignRoleToConvergenceLayer        = findMandateIdInOrg("Assign role Id: Assign role Id 3 to Convergence Layer", org);
        ids.assignDelegateStatus                = findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to the Convergence Layer", org);
        ids.registerConvergenceLayerToPaymaster = findMandateIdInOrg("Register Convergence Layer to Paymaster: Register the new Convergence Layer to the paymaster as a sponsored target, this means gas cost for interacting with the new Convergence Layer can be sponsored by the paymaster", org);
    }

    /// @dev Loads the Ideas Layer mandate cache once and returns IDs needed for
    ///      the convergence layer sub-flow.
    function _resolveIdeasLayerMandateIds(
        address ideasLayer
    ) internal returns (IdeasLayerMandateIds memory ids) {
        Powers org = Powers(payable(ideasLayer));
        _loadMandateCache(org);

        ids.requestNewConvergenceLayer = findMandateIdInOrg("Request new Convergence Layer: Participants can initiate the request for creating a new Convergence Layer under the Primary Layer", org);
        ids.sendRequest                = findMandateIdInOrg("Send request: Stewards can send the request to create a new Convergence Layer to the Primary Layer", org);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          STATE PREDICATES
    ///////////////////////////////////////////////////////////////////////////

    /// @dev True once the initial-setup mandate has run and role 1 has been labelled.
    function _isSetupComplete(address org) internal view returns (bool) {
        return bytes(Powers(payable(org)).getRoleLabel(1)).length > 0;
    }

    /// @dev True once at least `count` actions have been recorded for `mandateId`.
    function _haveActionsBeenSubmitted(
        address org,
        uint16 mandateId,
        uint256 count
    ) internal view returns (bool) {
        return IPowers(org).getQuantityMandateActions(mandateId) >= count;
    }

    /// @dev True once `count` Ideas Layers hold role 4 at the primary layer.
    function _areIdeasLayersDeployed(address primaryLayer, uint256 count) internal view returns (bool) {
        return IPowers(primaryLayer).getAmountRoleHolders(4) >= count;
    }

    /// @dev True once a Convergence Layer holds role 3 at the primary layer.
    function _isConvergenceLayerDeployed(address primaryLayer) internal view returns (bool) {
        return IPowers(primaryLayer).getAmountRoleHolders(3) > 0;
    }

    /// @dev True when the oldest of the most recent `batchSize` proposals on `mandateId`
    ///      has passed its full deadline... both voting period and timelock elapsed.
    function _isPastDeadline(
        address org,
        uint16 mandateId,
        uint256 batchSize
    ) internal view returns (bool) {
        uint256 total = IPowers(org).getQuantityMandateActions(mandateId);
        if (total < batchSize) return false;

        uint256 actionId = IPowers(org).getMandateActionAtIndex(mandateId, total - batchSize);
        (, uint48 proposedAt, , , , ,) = IPowers(org).getActionData(actionId);
        if (proposedAt == 0) return false; // direct request, no time constraint

        (, , uint256 voteEnd, , , ,) = IPowers(org).getActionVoteData(actionId);
        PowersTypes.Conditions memory cond = IPowers(org).getConditions(mandateId);

        bool votingPeriodElapsed = block.number > voteEnd;
        bool timelockElapsed     = cond.timelock == 0 || block.number >= uint256(proposedAt) + uint256(cond.timelock);

        return votingPeriodElapsed && timelockElapsed;
    }

    /// @dev Logs how many blocks remain until the oldest proposal in the batch
    ///      reaches its deadline. Helper for operator visibility.
    function _logBlocksRemaining(address org, uint16 mandateId, uint256 batchSize) internal view {
        uint256 total = IPowers(org).getQuantityMandateActions(mandateId);
        if (total < batchSize) return;

        uint256 actionId = IPowers(org).getMandateActionAtIndex(mandateId, total - batchSize);
        (, uint48 proposedAt, , , , ,) = IPowers(org).getActionData(actionId);
        if (proposedAt == 0) return;

        (, , uint256 voteEnd, , , ,) = IPowers(org).getActionVoteData(actionId);
        PowersTypes.Conditions memory cond = IPowers(org).getConditions(mandateId);

        uint256 votingDeadline  = voteEnd;
        uint256 timelockDeadline = uint256(proposedAt) + uint256(cond.timelock);
        uint256 deadline = votingDeadline > timelockDeadline ? votingDeadline : timelockDeadline;

        if (block.number < deadline) {
            console2.log("Runner: blocks remaining until deadline:", deadline - block.number);
        }
    }
}
