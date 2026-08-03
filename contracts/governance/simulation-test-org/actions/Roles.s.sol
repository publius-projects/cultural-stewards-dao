// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { ActionHelpers } from "./ActionHelpers.s.sol";

/// @notice Modular role-claiming interactions for the Simulation Test Org, adapted from the
/// Cultural Stewardship DAO's governance/actions/Roles.s.sol. Changes (see Spec.md):
///  - `getStewardRole_ConvergenceLayer` no longer passes a ZKP proof — Steward nomination is now
///    fully open (Nominate mandate, no eligibility gate).
///  - `getLegalInterfacerRole_ConvergenceLayer` rebuilt around the 3-step self-attested proposal
///    flow (StatementOfIntent -> Primary Layer veto -> Stewards execute via ExternalAction_Flexible)
///    instead of the removed ZKPassport_Check steps.
///  - Election-flow mandate description strings updated to match this org's retimed
///    nameDescriptions (Demo Timing Policy — 2 minute voting windows, not the original's 5).
contract Roles is ActionHelpers {
    uint16[] mandateSlots;
    uint256[] actionIds;

    uint256 roleCount;
    uint256 againstVote;
    uint256 forVote;
    uint256 abstainVote;

    // NB: All 'negative' actions (revoking roles, removing delegates, etc.) are not included yet. Can be added later.

    ///////////////////////////////////////////////////////////////
    //                  PRIMARY LAYER ROLES                      //
    ///////////////////////////////////////////////////////////////
    /// @notice Claim Primary Layer Participant role: step 1 ("Request Participant Step 1") can
    /// only be called by an Ideas Layer's own Powers contract address (allowedRole = role 4,
    /// "Ideas Layers" — held by contract addresses, not EOAs), so it must be triggered through
    /// the Ideas Layer's own "Request Participant role of Primary Layer" mandate (see
    /// IdeasLayer.s.sol), not directly with a private key here. This function only covers step 2:
    /// once an Ideas Layer has forwarded a request, Stewards vote to assign the role directly.
    function getParticipantRole_PrimaryLayer(
        address primaryLayer,
        address applicant,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Request Participant Step 2: Stewards vote to assign the Participant role to the candidate forwarded by an Ideas Layer.", Powers(payable(primaryLayer))));

        bytes memory callData = abi.encode(applicant);

        // Stewards vote to assign the role (requires voting: simple majority, 20% quorum).
        vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
        actionIds.push(IPowers(primaryLayer).propose(mandateSlots[0], callData, nonce, "Proposing to assign Participant role"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            primaryLayer,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
        IPowers(primaryLayer).request(mandateSlots[0], callData, nonce, "Assigning Participant role");
        vm.stopBroadcast();
    }

    function getStewardsRole_PrimaryLayer(address primaryLayer, address ideasLayer, address convergenceLayer, uint256 nonce) public {

    }


    ///////////////////////////////////////////////////////////////
    //                  DIGITAL LAYER ROLES                      //
    ///////////////////////////////////////////////////////////////
    // Because depends on interaction with github repo, for now not tested. Will be tested later.


    ///////////////////////////////////////////////////////////////
    //                   IDEAS LAYER ROLES                       //
    ///////////////////////////////////////////////////////////////
    function getParticipantRole_IdeasLayer(address powers, uint256[] memory privateKeys, uint256 nonce) public {
        // step 0: reset state variables.
        delete mandateSlots;
        delete actionIds;

        // step 1: identify mandates in the Assign Participant flow.
        mandateSlots.push(findMandateIdInOrg("Apply for Participant role: Anyone can apply for a Participant role to the Ideas Layer by submitting an application.", Powers(payable(powers))));
        mandateSlots.push(findMandateIdInOrg("Assess and Assign Participant: Assessors can assess applications and assign a Participant role to applicants.", Powers(payable(powers))));

        address testAccount1 = vm.addr(privateKeys[1]);

        // step 2: check if user has the permissions to run these mandates.
        Powers(payable(powers)).canCallMandate(msg.sender, mandateSlots[0]); // should return true (public mandate).
        Powers(payable(powers)).canCallMandate(testAccount1, mandateSlots[1]); // should return true (msg.sender must be Assessor).

        bytes memory callData = abi.encode(msg.sender, "");

        // step 3a: apply for Participant role (public, no voting required).
        vm.startBroadcast();
        IPowers(powers).request(mandateSlots[0], callData, nonce, "Applying for Participant role");
        vm.stopBroadcast();

        // step 3b: assess and assign Participant role (Assessors only, needFulfilled from step 3a).
        vm.startBroadcast(privateKeys[0]);
        IPowers(powers).request(mandateSlots[1], callData, nonce, "Assigning Participant role");
        vm.stopBroadcast();
    }

    function getAssessorsRole_IdeasLayer(address powers, uint256[] memory privateKeys, uint256 nonce) public {
        // step 0: reset state variables.
        delete mandateSlots;
        delete actionIds;

        // step 1: identify mandate in the Assign Assessor flow (skipping Participants veto).
        mandateSlots.push(findMandateIdInOrg("Assign Assessor Role: Stewards can assign the Assessor role to an account.", Powers(payable(powers))));

        bytes memory callData = abi.encode(msg.sender);

        // step 2: propose Assessor role assignment (requires voting: simple majority, 20% quorum).
        vm.startBroadcast(privateKeys[0]);
        actionIds.push(IPowers(powers).propose(mandateSlots[0], callData, nonce, "Proposing to assign Assessor role"));
        vm.stopBroadcast();

        // step 3: vote on proposal.
        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            powers,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100 // pass chance in percentage.
        );

        console2.log("Votes cast for assigning Assessor role: ", forVote);
        console2.log("Votes cast against assigning Assessor role: ", againstVote);
        console2.log("Total voters: ", roleCount);

        // step 4: execute Assessor role assignment (after voting period ends with no fulfilled veto).
        vm.startBroadcast(privateKeys[0]);
        IPowers(powers).request(mandateSlots[0], callData, nonce, "Assigning Assessor role");
        vm.stopBroadcast();
    }


    ///////////////////////////////////////////////////////////////
    //              IDEAS LAYER: ELECT STEWARDS                  //
    // Note: the election flow is time-gated. Run the three      //
    // phases in order, waiting between each:                    //
    //   1. createStewardElection_IdeasLayer  (create + nominate)//
    //   ⏳ wait for nomination period to end                    //
    //   2. voteInStewardElection_IdeasLayer  (open + cast votes)//
    //   ⏳ wait for voting period to end                        //
    //   3. tallyStewardElection_IdeasLayer   (tally + cleanup)  //
    ///////////////////////////////////////////////////////////////
    function createStewardElection_IdeasLayer(
        address ideasLayer,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public returns (uint256 electionId) {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Create a Steward election: an election for the Steward role can be initiated by any Participant. The election will be open for 2 minutes.", Powers(payable(ideasLayer))));
        mandateSlots.push(findMandateIdInOrg("Nominate for election: any Participant can nominate for an election.", Powers(payable(ideasLayer))));

        electionId = createElectionAndNominate(
            ideasLayer,
            mandateSlots[0],
            mandateSlots[1],
            "Steward Election 1",
            privateKeys,
            nonce
        );

        console2.log("Steward election created. Election ID: ", electionId);
    }

    function voteInStewardElection_IdeasLayer(
        address ideasLayer,
        address electionRegistry,
        bool[][] memory voteSelections,
        uint256 electionId,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Open voting for Steward election: After initiating an election, Participants can open the vote for a Steward election. This will create a dedicated vote mandate.", Powers(payable(ideasLayer))));

        openVotingAndCastVotes(
            ideasLayer,
            electionRegistry,
            mandateSlots[0],
            electionId,
            "Steward Election 1",
            privateKeys,
            voteSelections,
            nonce
        );
    }

    function tallyStewardElection_IdeasLayer(
        address ideasLayer,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Tally Steward elections: After the vote closes, tally the results and assign the Steward role to the winners.", Powers(payable(ideasLayer))));
        mandateSlots.push(findMandateIdInOrg("Clean up Steward election: After tallying the results, clean up related mandates.", Powers(payable(ideasLayer))));

        tallyElection(
            ideasLayer,
            mandateSlots[0],
            mandateSlots[1],
            privateKeys,
            "Steward Election 1",
            nonce
        );

        console2.log("Steward election tallied and cleaned up successfully.");
    }


    ///////////////////////////////////////////////////////////////
    //                CONVERGENCE LAYER ROLES                    //
    ///////////////////////////////////////////////////////////////
    function getAttendeeRole_ConvergenceLayer(address convergenceLayer, uint256[] memory privateKeys, uint256 nonce) public {
        // step 0: reset state variables.
        delete mandateSlots;
        delete actionIds;

        // step 1: identify mandates in the Claim Attendee Role flow.
        mandateSlots.push(findMandateIdInOrg("Apply for Attendee role: Anyone can apply for the Attendee role of this Convergence Layer by submitting an application.", Powers(payable(convergenceLayer))));
        mandateSlots.push(findMandateIdInOrg("Assess and Assign Attendee: Stewards can assess applications and assign the Attendee role to applicants.", Powers(payable(convergenceLayer))));

        bytes memory callData = abi.encode(msg.sender);

        // step 2a: apply for Attendee role (public, throttled, no voting required).
        vm.startBroadcast();
        IPowers(convergenceLayer).request(mandateSlots[0], callData, nonce, "Applying for Attendee role");
        vm.stopBroadcast();

        // step 2b: Stewards vote to assign the Attendee role (simple majority, 20% quorum).
        vm.startBroadcast(getPrivateKeyRoleHolder(convergenceLayer, 2, 0, privateKeys));
        actionIds.push(IPowers(convergenceLayer).propose(mandateSlots[1], callData, nonce, "Proposing to assign Attendee role"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            convergenceLayer,
            mandateSlots[1],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        vm.startBroadcast(getPrivateKeyRoleHolder(convergenceLayer, 2, 0, privateKeys));
        IPowers(convergenceLayer).request(mandateSlots[1], callData, nonce, "Assigning Attendee role");
        vm.stopBroadcast();
    }

    /// @notice Nominate + PeerSelect flow for Convergence Layer Stewards. Unlike the original,
    /// there is no ZKP age-check step — nomination is fully open (see Spec.md Limitations).
    function getStewardRole_ConvergenceLayer(address convergenceLayer, uint256[] memory privateKeys, uint256 nonce) public {
        // step 0: reset state variables.
        delete mandateSlots;
        delete actionIds;

        // step 1: identify mandates in the 'Select Stewards' flow at the Convergence Layer.
        mandateSlots.push(findMandateIdInOrg("Nominate for selection: any member can nominate to be selected for Steward role.", Powers(payable(convergenceLayer))));
        mandateSlots.push(findMandateIdInOrg("Select Stewards: Legal Interfacers can select Stewards from the pool of nominees.", Powers(payable(convergenceLayer))));

        // step 2: check permissions (Nominate is public; PeerSelect requires Legal Interfacer role).
        Powers(payable(convergenceLayer)).canCallMandate(msg.sender, mandateSlots[0]); // should return true (public mandate).
        Powers(payable(convergenceLayer)).canCallMandate(msg.sender, mandateSlots[1]); // msg.sender must be a Legal Interfacer (role 3).

        // step 3a: nominate msg.sender for Steward selection (public, no eligibility gate).
        vm.startBroadcast();
        IPowers(convergenceLayer).request(mandateSlots[0], abi.encode(), nonce, "Nominating for Steward selection");
        vm.stopBroadcast();

        // step 3b: Legal Interfacer proposes Steward selection via PeerSelect (requires voting: 66% majority, 30% quorum).
        bytes memory selectCallData = abi.encode(msg.sender);
        vm.startBroadcast(getPrivateKeyRoleHolder(convergenceLayer, 3, 0, privateKeys));
        actionIds.push(IPowers(convergenceLayer).propose(mandateSlots[1], selectCallData, nonce, "Proposing Steward selection via PeerSelect"));
        vm.stopBroadcast();

        console2.log("PeerSelect proposed. Action ID: ", actionIds[0]);

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            convergenceLayer,
            mandateSlots[1],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        // step 3c: execute PeerSelect after voting period ends.
        vm.startBroadcast(getPrivateKeyRoleHolder(convergenceLayer, 3, 0, privateKeys));
        IPowers(convergenceLayer).request(mandateSlots[1], selectCallData, nonce, "Executing Steward selection via PeerSelect");
        vm.stopBroadcast();
    }

    /// @notice Propose Legal Interfacer for a Convergence Layer via the Ideas Layer's 3-step
    /// self-attested flow: propose -> Primary Layer veto window -> Stewards execute.
    function getLegalInterfacerRole_ConvergenceLayer(
        address ideasLayer,
        address convergenceLayer,
        uint16 assignLegalInterfacerMandateId,
        address candidate,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        // step 0: reset state variables.
        delete mandateSlots;
        delete actionIds;

        // step 1: identify mandates in the 'Propose Legal Interfacer for Convergence Layer' flow.
        mandateSlots.push(findMandateIdInOrg("Propose Legal Interfacer: Participants propose a candidate for Legal Interfacer at a target Convergence Layer, self-attesting eligibility.", Powers(payable(ideasLayer))));
        mandateSlots.push(findMandateIdInOrg("Veto Legal Interfacer Proposal: The Primary Layer can veto a proposed Legal Interfacer nominee within the voting window.", Powers(payable(ideasLayer))));
        mandateSlots.push(findMandateIdInOrg("Execute Legal Interfacer Assignment: Stewards have a final vote. If successful, calls the target Convergence Layer (TargetConvergenceLayer/AssignMandateId) to assign the Legal Interfacer role to Candidate.", Powers(payable(ideasLayer))));

        bytes memory callData = abi.encode(convergenceLayer, assignLegalInterfacerMandateId, candidate, true, true);

        // step 2: check permissions (propose requires Participant role; execute requires Steward role).
        Powers(payable(ideasLayer)).canCallMandate(msg.sender, mandateSlots[0]); // msg.sender must hold the Participants role (role 1).

        // step 3a: Participant proposes candidate (self-attested, no voting on this step).
        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 1, 0, privateKeys));
        IPowers(ideasLayer).request(mandateSlots[0], callData, nonce, "Proposing Legal Interfacer candidate");
        vm.stopBroadcast();

        // step 3b: Primary Layer veto window (66% majority, 30% quorum) — skipped here for the
        // happy path; the veto mandate simply is not called, letting the timelock lapse.

        // step 3c: Stewards vote and execute the assignment at the target Convergence Layer.
        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 2, 0, privateKeys));
        actionIds.push(IPowers(ideasLayer).propose(mandateSlots[2], callData, nonce, "Proposing to execute Legal Interfacer assignment"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            ideasLayer,
            mandateSlots[2],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 2, 0, privateKeys));
        IPowers(ideasLayer).request(mandateSlots[2], callData, nonce, "Executing Legal Interfacer assignment");
        vm.stopBroadcast();
    }

}
