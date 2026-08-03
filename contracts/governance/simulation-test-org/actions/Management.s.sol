// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { ActionHelpers } from "./ActionHelpers.s.sol";

/// @notice Modular reform/management interactions for the Simulation Test Org, adapted unchanged
/// (structurally) from the Cultural Stewardship DAO's governance/actions/Management.s.sol — the
/// 9-step Adopt Mandate reform flow and its mandate nameDescription strings are kept as-is per
/// Spec.md's explicit choice to preserve this flow's shape. Only comments/thresholds referenced
/// in logs reflect this org's retimed 20%/51% and 30%/66% tiers.
contract Management is ActionHelpers {
    uint16[] mandateSlots;
    uint256[] actionIds;

    uint256 roleCount;
    uint256 againstVote;
    uint256 forVote;
    uint256 abstainVote;

    function updateUri(address powers, string memory newUri, uint256 privateKey, uint256 nonce) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Update URI: Set allowed token for Cultural Stewards", Powers(payable(powers))));

        vm.startBroadcast(privateKey);
        IPowers(powers).request(mandateSlots[0], abi.encode(newUri), nonce, string.concat("Assigning role ID for convergence layer"));
        vm.stopBroadcast();
    }

    function adoptMandatesPrimaryLayerInitiate(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256 privateKey,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Initiate mandate adoption: Any Steward can propose adopting new mandates into the organization.", Powers(payable(powers))));

        vm.startBroadcast(privateKey);
        IPowers(powers).request(mandateSlots[0], abi.encode(mandates, roleIds), nonce, "Initiating mandate adoption");
        vm.stopBroadcast();
    }

    function adoptMandatesPrimaryLayerExecute(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Reform Checkpoint 1: Primary Steward confirm Participants did not veto.", Powers(payable(powers))));
        mandateSlots.push(findMandateIdInOrg("Reform Checkpoint 2: Primary Steward confirm Digital Layer did not veto.", Powers(payable(powers))));
        mandateSlots.push(findMandateIdInOrg("Reform Checkpoint 3: Primary Steward confirm Ideas Layer did not veto.", Powers(payable(powers))));
        mandateSlots.push(findMandateIdInOrg("Adopt new Mandates: Primary Steward can adopt new mandates into the organization.", Powers(payable(powers))));

        bytes memory encodedCalldata = abi.encode(mandates, roleIds);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        IPowers(powers).request(mandateSlots[0], encodedCalldata, nonce, "Reform Checkpoint 1");
        vm.stopBroadcast();

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        IPowers(powers).request(mandateSlots[1], encodedCalldata, nonce, "Reform Checkpoint 2");
        vm.stopBroadcast();

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        IPowers(powers).request(mandateSlots[2], encodedCalldata, nonce, "Reform Checkpoint 3");
        vm.stopBroadcast();

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        actionIds.push(IPowers(powers).propose(mandateSlots[3], encodedCalldata, nonce, "Adopting new mandates"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            powers,
            mandateSlots[3],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for adopting mandates: ", forVote);
        console2.log("Votes cast against adopting mandates: ", againstVote);
        console2.log("Votes cast abstaining on adopting mandates: ", abstainVote);
        console2.log("Total voters: ", roleCount);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        IPowers(powers).request(mandateSlots[3], encodedCalldata, nonce, "Adopting new mandates");
        vm.stopBroadcast();
    }

    function adoptMandatesIdeasLayerVeto(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Veto Adopting Mandates: Participants can veto proposals to adopt new mandates", Powers(payable(powers))));

        bytes memory encodedCalldata = abi.encode(mandates, roleIds);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 1, 0, privateKeys));
        actionIds.push(IPowers(powers).propose(mandateSlots[0], encodedCalldata, nonce, "Vetoing mandate adoption"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            powers,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for vetoing mandate adoption: ", forVote);
        console2.log("Votes cast against vetoing mandate adoption: ", againstVote);
        console2.log("Votes cast abstaining on vetoing mandate adoption: ", abstainVote);
        console2.log("Total voters: ", roleCount);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 1, 0, privateKeys));
        IPowers(powers).request(mandateSlots[0], encodedCalldata, nonce, "Vetoing mandate adoption");
        vm.stopBroadcast();
    }

    function adoptMandatesIdeasLayerExecute(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Adopt new Mandates: Stewards can adopt new mandates into the organization", Powers(payable(powers))));

        bytes memory encodedCalldata = abi.encode(mandates, roleIds);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        actionIds.push(IPowers(powers).propose(mandateSlots[0], encodedCalldata, nonce, "Adopting new mandates"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            powers,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for adopting mandates: ", forVote);
        console2.log("Votes cast against adopting mandates: ", againstVote);
        console2.log("Votes cast abstaining on adopting mandates: ", abstainVote);
        console2.log("Total voters: ", roleCount);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        IPowers(powers).request(mandateSlots[0], encodedCalldata, nonce, "Adopting new mandates");
        vm.stopBroadcast();
    }

    function adoptMandatesConvergenceLayerInitiate(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Initiate Adopting Mandates: Members can initiate adopting new mandates", Powers(payable(powers))));

        bytes memory encodedCalldata = abi.encode(mandates, roleIds);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 1, 0, privateKeys));
        actionIds.push(IPowers(powers).propose(mandateSlots[0], encodedCalldata, nonce, "Initiating mandate adoption"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            powers,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for initiating mandate adoption: ", forVote);
        console2.log("Votes cast against initiating mandate adoption: ", againstVote);
        console2.log("Votes cast abstaining on initiating mandate adoption: ", abstainVote);
        console2.log("Total voters: ", roleCount);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 1, 0, privateKeys));
        IPowers(powers).request(mandateSlots[0], encodedCalldata, nonce, "Initiating mandate adoption");
        vm.stopBroadcast();
    }

    function adoptMandatesConvergenceLayerVeto(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256 privateKey,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Veto Adopting Mandates: primaryLayer can veto proposals to adopt new mandates", Powers(payable(powers))));

        vm.startBroadcast(privateKey);
        IPowers(powers).request(mandateSlots[0], abi.encode(mandates, roleIds), nonce, "Vetoing mandate adoption");
        vm.stopBroadcast();
    }

    function adoptMandatesConvergenceLayerExecute(
        address powers,
        address[] memory mandates,
        uint256[] memory roleIds,
        uint256[] memory privateKeys,
        uint256 nonce
    ) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Adopt new Mandates: Stewards can adopt new mandates into the organization", Powers(payable(powers))));

        bytes memory encodedCalldata = abi.encode(mandates, roleIds);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        actionIds.push(IPowers(powers).propose(mandateSlots[0], encodedCalldata, nonce, "Adopting new mandates"));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            powers,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for adopting mandates: ", forVote);
        console2.log("Votes cast against adopting mandates: ", againstVote);
        console2.log("Votes cast abstaining on adopting mandates: ", abstainVote);
        console2.log("Total voters: ", roleCount);

        vm.startBroadcast(getPrivateKeyRoleHolder(powers, 2, 0, privateKeys));
        IPowers(powers).request(mandateSlots[0], encodedCalldata, nonce, "Adopting new mandates");
        vm.stopBroadcast();
    }
}
