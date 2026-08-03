// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { DeploySetup } from "./DeploySetup.s.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { ElectionRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/ElectionRegistry.sol";
import { PowersFactory } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersFactory.sol";
import { PowersDeployer } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersDeployer.sol";

/// @notice Ideas Layer (PowersFactory template) — Simulation Test Org.
/// Derived from the Cultural Stewardship DAO's IdeasLayer.s.sol. Changes (see Spec.md):
///  - Both `ZKPassport_Check` mandates removed from "Propose Legal Interfacer for Convergence
///    Layer". The flow is rebuilt to 3 steps: StatementOfIntent (self-attested proposal) ->
///    StatementOfIntent veto (Primary Layer) -> execute (Stewards).
///  - JUDGMENT CALL: Spec.md names `ExternalAction_Simple` for the execute step, but that
///    mandate's `PowersTarget`/`MandateIdTarget` are FIXED at config/deploy time — incompatible
///    with this flow's requirement that a Participant choose *which* Convergence Layer to target
///    at proposal time (`address TargetConvergenceLayer` is a runtime input, not a deploy-time
///    constant, and this factory template is shared across every Convergence Layer instance).
///    `ExternalAction_Flexible` is used instead — it takes PowersTarget/MandateIdTarget as
///    runtime inputs, exactly matching the dynamic-target requirement. See Spec.md's Limitations
///    note in the deployment report for detail.
///  - "Request Participant role of Primary Layer" no longer forwards `uint256[] tokenIds`
///    (no token); it forwards `address Applicant` to match the Primary Layer's rebuilt
///    "Claim Participant Role" flow (see PrimaryLayer.s.sol).
///  - `zkPassport_PowersRegistry` constructor/config parameter removed entirely.
///  - Every votingPeriod/timelock/throttleExecution/quorum/succeedAt retimed per the Demo Timing
///    Policy. The 6-step formal Steward election is kept structurally unchanged, only retimed.
contract IdeasLayer is DeploySetup {
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;

    PowersTypes.MandateInitData[] constitution;
    PowersFactory powersFactory;

    //////////////////////////////////////////////////////////////////////
    //                        INITIALISATION                            //
    //////////////////////////////////////////////////////////////////////
    function run() public {
        console2.log("Deploying Ideas Layer factory (contract only)...");
        vm.startBroadcast();
        PowersDeployer IdeasLayerDeployer = new PowersDeployer();
        powersFactory = new PowersFactory(
            string.concat(baseURI, "ideasLayer.json"),
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(IdeasLayerDeployer),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Ideas Layer factory deployed at:", address(powersFactory));
    }

    //////////////////////////////////////////////////////////////////////
    //                          CONSTITUTE                              //
    //////////////////////////////////////////////////////////////////////
    function constitutePowers(
        address primaryLayer,
        address electionRegistry,
        address safeTreasury,
        uint16 requestParticipantpowersId,
        uint16 requestNewConvergenceLayerId
    ) public {
        _createConstitution(primaryLayer, electionRegistry, safeTreasury, requestParticipantpowersId, requestNewConvergenceLayerId);

        // NB: `packageInitData` (used by the original Cultural Stewardship DAO's equivalent
        // file) no longer exists in the current powers-monorepo checkout — PowersFactory.addMandates
        // takes the full array directly, so we just copy the storage array to memory here.
        PowersTypes.MandateInitData[] memory constitutionPacked = new PowersTypes.MandateInitData[](constitution.length);
        for (uint256 i = 0; i < constitution.length; i++) {
            constitutionPacked[i] = constitution[i];
        }
        vm.startBroadcast();
        powersFactory.addMandates(constitutionPacked);
        powersFactory.addFlows(flows);
        powersFactory.transferOwnership(primaryLayer);
        vm.stopBroadcast();
    }

    //////////////////////////////////////////////////////////////////////
    //                            GETTERS                               //
    //////////////////////////////////////////////////////////////////////
    function getAddress() public view returns (address) {
        return address(powersFactory);
    }

    function _initMandateAddresses() internal {
        m_Adopt_Mandates = _latestMandateAddress("Adopt_Mandates");
        m_BespokeAction_Advanced = registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced");
        m_BespokeAction_Simple = registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple");
        m_ElectionRegistry_CleanUpVoteMandate = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CleanUpVoteMandate");
        m_ElectionRegistry_CreateVoteMandate = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate");
        m_ElectionRegistry_Nominate = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate");
        m_ElectionRegistry_Tally = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally");
        m_ElectionRegistry_Vote = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote");
        m_ExternalAction_Flexible = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Flexible");
        m_ExternalAction_Simple = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple");
        m_PresetActions_OnOwnPowers = registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers");
        m_Safe_RecoverTokens = registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_RecoverTokens");
        m_StatementOfIntent = registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent");
    }

    //////////////////////////////////////////////////////////////////////
    //                        CONSTITUTION                              //
    //////////////////////////////////////////////////////////////////////
    function _createConstitution(
        address primaryLayer,
        address electionRegistry,
        address safeTreasury,
        uint16 requestParticipantpowersId,
        uint16 requestNewConvergenceLayerId
    ) internal {
        blocksPerHour = helperConfig.getBlocksPerHour(block.chainid);
        mandateCount = 5; // resetting mandate count (matches original factory-template offset).
        if (m_StatementOfIntent == address(0)) _initMandateAddresses();

        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        calldatas = new bytes[](13);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Setup Initiator", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Participants", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Stewards", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Assessors", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 6, "Primary Layer", "");
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 0, testAccount1);
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount2);
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, testAccount1);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, testAccount1);
        calldatas[11] = abi.encodeWithSelector(IPowers.assignRole.selector, 6, primaryLayer);
        calldatas[12] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: m_PresetActions_OnOwnPowers,
                config: abi.encode(calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // SECOND SETUP //
        calldatas = new bytes[](6);
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, cedars);
        calldatas[1] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, hannah);
        calldatas[2] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, cedars);
        calldatas[3] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, hannah);
        calldatas[4] = abi.encodeWithSelector(IPowers.assignRole.selector, 0, cedars);
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Second Setup: Assign Stewards and Assessors roles to cedars and hannah, revokes itself after execution",
                targetMandate: m_PresetActions_OnOwnPowers,
                config: abi.encode(calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // ASSIGN PARTICIPANT //
        uint16[] memory mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Assign Participant: This flow allows users to apply for and claim a Participant role based on forum participation.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](2);
        inputParams[0] = "address Applicant";
        inputParams[1] = "string Reason";

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        conditions.throttleExecution = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Apply for Participant role: Anyone can apply for a Participant role to the Ideas Layer by submitting an application.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Assessors: assess and assign Participant
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assess and Assign Participant: Assessors can assess applications and assign a Participant role to applicants.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(1),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REQUEST CREATION NEW CONVERGENCE Layer //
        mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            nameDescription: "Request new Convergence Layer: This flow includes the initiation by Participants, veto by Assessors, and execution by Stewards to request the creation of a new Convergence Layer.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](2);
        inputParams[0] = "string Name";
        inputParams[1] = "address Initiator";

        // Participants: Initialise request for new convergence layer.
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request new Convergence Layer: Participants can initiate the request for creating a new Convergence Layer under the Primary Layer",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Assessors: Veto request for new convergence layer
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto request for new Convergence Layer: Assessors can veto the request for creating a new Convergence Layer under the Primary Layer.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Stewards: request at Primary Layer the creation of a new convergence layer.
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Send request: Stewards can send the request to create a new Convergence Layer to the Primary Layer",
                targetMandate: m_ExternalAction_Simple,
                config: abi.encode(
                    primaryLayer,
                    requestNewConvergenceLayerId,
                    "Requesting creation of new Convergence Layer from Ideas Layer",
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REVOKE PARTICIPANT //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Revoke Participant: This flow allows Assessors to revoke Participant, Participants have a veto and can block the revocation.",
            mandateIds: mandateIds
        }));

        // Participants: veto Revoke Participant
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Revoke Participant: Participants can veto revoking Participant Role.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Assessors: Revoke Participant
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.needFulfilled = mandateCount - 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Participant: Assessors can revoke Participant role from an account.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(0),
                    IPowers.revokeRole.selector,
                    abi.encode(1),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REQUEST TO BECOME PARTICIPANT AT PRIMARY LAYER //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Request Participant role at Primary Layer: This flow allows Participants to apply for Participant role in the Primary Layer and Assessors to approve and forward the request (no token check - see Spec.md).",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "address Applicant";

        // Participants: apply for Participant role of Primary Layer.
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Apply for Participant role of Primary Layer: Participants can apply for Participant role of the Primary Layer.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Assessors: ok and send request to Primary Layer.
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Participant role of Primary Layer: Assessors can ok requests for Participant role of the Primary Layer and send them to the Primary Layer for assessment.",
                targetMandate: m_ExternalAction_Simple,
                config: abi.encode(
                    primaryLayer,
                    requestParticipantpowersId,
                    "Requesting Participant of Primary Layer",
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // PROPOSE LEGAL INTERFACER FOR CONVERGENCE LAYER //
        // Rebuilt to 3 steps per Spec.md — both ZKPassport_Check mandates removed. Eligibility
        // claims are now self-attested booleans carried in the proposal, not cryptographically
        // verified. See the contract-level NatSpec above for why ExternalAction_Flexible (not
        // ExternalAction_Simple as literally named in Spec.md) is used for step 3.
        mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            nameDescription: "Propose Legal Interfacer for Convergence Layer: Participants self-attest a candidate's eligibility (age 18+, GBR-eligible). The Primary Layer can veto within the timelock window and Stewards have a final vote to execute the assignment.",
            mandateIds: mandateIds
        }));

        // All three mandates in this flow share the same calldata shape, so needFulfilled /
        // needNotFulfilled resolve correctly across the chain.
        string[] memory legalInterfacerParams = new string[](5);
        legalInterfacerParams[0] = "address TargetConvergenceLayer";
        legalInterfacerParams[1] = "uint16 AssignMandateId";
        legalInterfacerParams[2] = "address Candidate";
        legalInterfacerParams[3] = "bool AttestsAge18Plus";
        legalInterfacerParams[4] = "bool AttestsGBREligible";

        // Participants: propose a Legal Interfacer candidate (self-attested, unverified).
        mandateCount++;
        conditions.allowedRole = 1; // = Participants
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Legal Interfacer: Participants propose a candidate for Legal Interfacer at a target Convergence Layer, self-attesting eligibility.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(legalInterfacerParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 proposeLegalInterfacerId = mandateCount;

        // Primary Layer: veto the proposal within the timelock window.
        mandateCount++;
        conditions.allowedRole = 6; // = Primary Layer
        conditions.needFulfilled = proposeLegalInterfacerId;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Legal Interfacer Proposal: The Primary Layer can veto a proposed Legal Interfacer nominee within the voting window.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(legalInterfacerParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 vetoLegalInterfacerId = mandateCount;

        // Stewards: execute the assignment at the target Convergence Layer.
        {
            string[] memory forwardedParams = new string[](3);
            forwardedParams[0] = "address Candidate";
            forwardedParams[1] = "bool AttestsAge18Plus";
            forwardedParams[2] = "bool AttestsGBREligible";

            mandateCount++;
            conditions.allowedRole = 2; // = Stewards
            conditions.needFulfilled = proposeLegalInterfacerId;
            conditions.needNotFulfilled = vetoLegalInterfacerId;
            conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
            conditions.succeedAt = 51;
            conditions.quorum = 20;
            constitution.push(
                PowersTypes.MandateInitData({
                    nameDescription: "Execute Legal Interfacer Assignment: Stewards have a final vote. If successful, calls the target Convergence Layer (TargetConvergenceLayer/AssignMandateId) to assign the Legal Interfacer role to Candidate.",
                    targetMandate: m_ExternalAction_Flexible,
                    config: abi.encode(forwardedParams),
                    conditions: conditions
                })
            );
        }
        delete conditions;

        // ASSIGN ASSESSORS //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Assign Assessor Role: This flow allows Participants to veto and Stewards to assign the Assessor role.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "address Account";

        // Participants: veto assigning Assessor role.
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Assign Assessor Role: Participants can veto assigning the Assessor role to an account.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Stewards: assign Assessor role.
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Assessor Role: Stewards can assign the Assessor role to an account.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(3),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REVOKE ASSESSORS //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Revoke Assessor Role: This flow allows Participants to veto and Stewards to revoke the Assessor role.",
            mandateIds: mandateIds
        }));

        // Participants: veto revoking Assessor role.
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Revoke Assessor Role: Participants can veto revoking the Assessor role from an account.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Stewards: revoke Assessor role.
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.needFulfilled = mandateCount - 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Assessor Role: Stewards can revoke the Assessor role from an account.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(0),
                    IPowers.revokeRole.selector,
                    abi.encode(3),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ELECT STEWARDS // (kept structurally unchanged — 6-step formal election)
        mandateIds = new uint16[](6);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;

        flows.push(PowersTypes.Flow({
            nameDescription: "Elect Stewards: This flow includes the creation, voting, tallying, and cleanup of an election for the Steward role.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "string Title";

        // Participants: create election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.throttleExecution = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create a Steward election: an election for the Steward role can be initiated by any Participant. The election will be open for 2 minutes.",
                targetMandate: m_BespokeAction_Simple,
                config: abi.encode(
                    electionRegistry,
                    ElectionRegistry.createElection.selector,
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants: Open Vote for Steward election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for Steward election: After initiating an election, Participants can open the vote for a Steward election. This will create a dedicated vote mandate.",
                targetMandate: m_ElectionRegistry_CreateVoteMandate,
                config: abi.encode(
                    electionRegistry,
                    m_ElectionRegistry_Vote,
                    1,
                    1
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally Steward elections: After the vote closes, tally the results and assign the Steward role to the winners.",
                targetMandate: m_ElectionRegistry_Tally,
                config: abi.encode(
                    electionRegistry,
                    2,
                    3
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants: clean up Steward election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up Steward election: After tallying the results, clean up related mandates.",
                targetMandate: m_ElectionRegistry_CleanUpVoteMandate,
                config: abi.encode(uint16(mandateCount - 2)),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants: Nominate for Executive election
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any Participant can nominate for an election.",
                targetMandate: m_ElectionRegistry_Nominate,
                config: abi.encode(electionRegistry, true),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants revoke nomination for Executive election.
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any Participant can revoke their nomination for an election.",
                targetMandate: m_ElectionRegistry_Nominate,
                config: abi.encode(electionRegistry, false),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        REFORM MANDATES                           //
        //////////////////////////////////////////////////////////////////////

        // ADOPT MANDATES //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Adopt Mandates: This flow allows for the adoption of new mandates, initiated by Stewards and subject to veto by Participants.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](2);
        inputParams[0] = "address[] mandates";
        inputParams[1] = "uint256[] roleIds";

        // Participants: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Participants can veto proposals to adopt new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Stewards: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Stewards can adopt new mandates into the organization",
                targetMandate: m_Adopt_Mandates,
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        // MISCELLANEOUS (NOT IN A FLOW) //
        // UPDATE URI //
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Stewards: Update URI
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: Set allowed token for Convergence Layer",
                targetMandate: m_BespokeAction_Simple,
                config: abi.encode(
                    address(0),
                    Powers.setUri.selector,
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // TRANSFER TOKENS INTO TREASURY //
        mandateCount++;
        conditions.allowedRole = 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the Ideas Layer can be recovered by sending them to the treasury",
                targetMandate: m_Safe_RecoverTokens,
                config: abi.encode(
                    safeTreasury,
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

    }
}
