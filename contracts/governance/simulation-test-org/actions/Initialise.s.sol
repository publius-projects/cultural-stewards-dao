// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { ActionHelpers } from "./ActionHelpers.s.sol";

/// @notice Post-deployment initialisation steps for the Simulation Test Org, adapted from the
/// Cultural Stewardship DAO's governance/actions/Initialise.s.sol. No token/ZKP content existed
/// in this file to begin with, so the layer-creation logic is unchanged; it is used here to seed
/// the two demo Ideas Layers named "Yin" and "Yang" (see Spec.md's "Demo Setup" section) and to
/// spawn a demo Convergence Layer for the live-demo walkthrough (Basel art exhibition).
contract Initialise is ActionHelpers {
    uint16[] mandateSlots;
    uint256[] actionIds;

    uint256 roleCount;
    uint256 againstVote;
    uint256 forVote;
    uint256 abstainVote;

    address deployedConvergenceLayer;

    function runSetupMandate(address powers, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Initial Setup: Assign role labels and revokes itself after execution", Powers(payable(powers))));

        // Initial Setup mandate is PUBLIC (allowedRole = type(uint256).max), so any key suffices.
        vm.startBroadcast(privateKeys[0]);
        IPowers(powers).request(mandateSlots[0], abi.encode(), nonce, "Executing initial setup mandate");
        vm.stopBroadcast();
    }

    function unpackReformPackages(address powers, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        _loadMandateCache(Powers(payable(powers)));
        uint16 counter = _mandateCounterCache[address(powers)];
        for (uint16 i = 1; i < counter; i++) {
            uint16 id = _mandateCache[address(powers)][keccak256(abi.encodePacked("Reform Package ", vm.toString(i)))];
            if (id != 0) mandateSlots.push(id);
        }

        console2.log("Unpacking reform packages for layer: ", Powers(payable(powers)).name());
        console2.log("Found ", mandateSlots.length, " reform packages to unpack.");
        console2.log("total number of mandates in the layer: ", counter);

        for (uint i = 0; i < mandateSlots.length; i++) {
            vm.startBroadcast();
            Powers(payable(powers)).request(mandateSlots[i], abi.encode(), nonce + i, "Unpacking reform package for Ideas Layer");
            vm.stopBroadcast();
        }
    }

    /// @notice Step 1 of seeding "Yin"/"Yang": Participants initiate creation.
    function deployIdeasLayer1(address primaryLayer, uint256 nonce, string[] memory names, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Initiate Ideas Layer: Initiate creation of Ideas Layer", Powers(payable(primaryLayer))));

        vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 1, 0, privateKeys));
        for (uint i = 0; i < names.length; i++) {
            actionIds.push(IPowers(primaryLayer).propose(mandateSlots[0], abi.encode(names[i]), nonce + i, string.concat("Initiating create ideas layer: ", names[i])));
        }
        vm.stopBroadcast();

        for (uint i = 0; i < actionIds.length; i++) {
            (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
                primaryLayer,
                mandateSlots[0],
                actionIds[i],
                privateKeys,
                nonce + i,
                100
            );
            console2.log("Votes cast for initiating ideas layer proposal: ", names[i], ": ", forVote);
        }
    }

    /// @notice Step 2 of seeding "Yin"/"Yang": execute initiation + propose creation.
    function deployIdeasLayer2(address primaryLayer, uint256 nonce, string[] memory names, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Initiate Ideas Layer: Initiate creation of Ideas Layer", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Create Ideas Layer: Execute Ideas Layer creation", Powers(payable(primaryLayer))));

        for (uint i = 0; i < names.length; i++) {
            vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 1, 0, privateKeys));
            IPowers(payable(primaryLayer)).request(mandateSlots[0], abi.encode(names[i]), nonce + i, string.concat("Executing initialising ideas layer"));
            vm.stopBroadcast();

            vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
            actionIds.push(IPowers(primaryLayer).propose(mandateSlots[1], abi.encode(names[i]), nonce + i, string.concat("Proposing the creation of an ideas layer")));
            vm.stopBroadcast();

            (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
                primaryLayer,
                mandateSlots[1],
                actionIds[i],
                privateKeys,
                nonce + i,
                100
            );
            console2.log("Votes cast for creating ideas layer proposal: ", names[i], ": ", forVote);
        }
    }

    /// @notice Step 3 of seeding "Yin"/"Yang": execute creation, assign role, register paymaster.
    function deployIdeasLayer3(address primaryLayer, uint256 nonce, string[] memory names, uint256[] memory privateKeys) public returns (address[] memory deployedIdeasLayer) {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Create Ideas Layer: Execute Ideas Layer creation", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Assign role Id to layer: Assign role id 4 (Ideas Layer) to the new layer", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Register Ideas Layer to Paymaster: Register the new Ideas Layer to the paymaster as a sponsored target", Powers(payable(primaryLayer))));

        for (uint i = 0; i < names.length; i++) {
            vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
            IPowers(primaryLayer).request(mandateSlots[0], abi.encode(names[i]), nonce + i, string.concat("Executing create ideas layer"));
            vm.stopBroadcast();

            vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
            IPowers(primaryLayer).request(mandateSlots[1], abi.encode(names[i]), nonce + i, string.concat("Assigning role ID for ideas layer"));
            IPowers(primaryLayer).request(mandateSlots[2], abi.encode(names[i]), nonce + i, string.concat("Registering ideas layer to paymaster"));
            vm.stopBroadcast();
        }

        deployedIdeasLayer = new address[](names.length);
        for (uint i = 0; i < names.length; i++) {
            deployedIdeasLayer[i] = Powers(payable(primaryLayer)).getRoleHolderAtIndex(4, i);
            console2.log("Deployed Ideas Layer: ", names[i], ": ", deployedIdeasLayer[i]);
            unpackReformPackages(deployedIdeasLayer[i], nonce, privateKeys);
        }

        console2.log("Deployed ", names.length, " Ideas Layers Successfully!");
        return deployedIdeasLayer;
    }

    function updateUriIdeasLayer1(address[] memory ideasLayers, string memory uri, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        for (uint i = 0; i < ideasLayers.length; i++) {
            uint16 updateUriMandateId = findMandateIdInOrg("Update URI: Set allowed token for Convergence Layer", Powers(payable(ideasLayers[i])));

            vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayers[i], 2, 0, privateKeys));
            uint256 actionId = IPowers(ideasLayers[i]).propose(updateUriMandateId, abi.encode(uri), nonce + i, "Proposing URI update for Ideas Layer");
            vm.stopBroadcast();

            (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
                ideasLayers[i],
                updateUriMandateId,
                actionId,
                privateKeys,
                nonce + i,
                100
            );
            console2.log("Ideas Layer ", ideasLayers[i], " votes for URI update: ", forVote);
        }
    }

    function updateUriIdeasLayer2(address[] memory ideasLayers, string memory uri, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        for (uint i = 0; i < ideasLayers.length; i++) {
            uint16 updateUriMandateId = findMandateIdInOrg("Update URI: Set allowed token for Convergence Layer", Powers(payable(ideasLayers[i])));

            vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayers[i], 2, 0, privateKeys));
            IPowers(ideasLayers[i]).request(updateUriMandateId, abi.encode(uri), nonce + i, "Executing URI update for Ideas Layer");
            vm.stopBroadcast();

            console2.log("URI updated to ", uri, " for Ideas Layer: ", ideasLayers[i]);
        }
    }

    /// @notice Step 1 of demo Convergence Layer creation (e.g. "Basel Art Exhibition").
    function deployConvergenceLayer1(address ideasLayer, string memory layerName, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Request new Convergence Layer: Participants can initiate the request for creating a new Convergence Layer under the Primary Layer", Powers(payable(ideasLayer))));

        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 1, 0, privateKeys));
        actionIds.push(IPowers(ideasLayer).propose(mandateSlots[0], abi.encode(layerName, msg.sender), nonce, string.concat("Initiating request new convergence layer")));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            ideasLayer,
            mandateSlots[0],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for requesting convergence layer: ", forVote);
        console2.log("Votes cast against: ", againstVote);
        console2.log("Total voters: ", roleCount);
    }

    function deployConvergenceLayer2(address ideasLayer, string memory layerName, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Request new Convergence Layer: Participants can initiate the request for creating a new Convergence Layer under the Primary Layer", Powers(payable(ideasLayer))));
        mandateSlots.push(findMandateIdInOrg("Send request: Stewards can send the request to create a new Convergence Layer to the Primary Layer", Powers(payable(ideasLayer))));

        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 1, 0, privateKeys));
        IPowers(ideasLayer).request(mandateSlots[0], abi.encode(layerName, msg.sender), nonce, string.concat("Executing request new convergence layer"));
        vm.stopBroadcast();

        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 2, 0, privateKeys));
        actionIds.push(IPowers(ideasLayer).propose(mandateSlots[1], abi.encode(layerName, msg.sender), nonce, string.concat("Sending request for new convergence layer to primary layer")));
        vm.stopBroadcast();

        (roleCount, againstVote, forVote, abstainVote) = voteOnProposal(
            ideasLayer,
            mandateSlots[1],
            actionIds[0],
            privateKeys,
            nonce,
            100
        );

        console2.log("Votes cast for sending convergence layer request: ", forVote);
        console2.log("Votes cast against: ", againstVote);
        console2.log("Total voters: ", roleCount);
    }

    function deployConvergenceLayer3(address ideasLayer, string memory layerName, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Send request: Stewards can send the request to create a new Convergence Layer to the Primary Layer", Powers(payable(ideasLayer))));

        vm.startBroadcast(getPrivateKeyRoleHolder(ideasLayer, 2, 0, privateKeys));
        IPowers(ideasLayer).request(mandateSlots[0], abi.encode(layerName, msg.sender), nonce, string.concat("Executing send request for new convergence layer"));
        vm.stopBroadcast();
    }

    function deployConvergenceLayer4(address primaryLayer, string memory layerName, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Assign role Id: Assign role Id 3 to Convergence Layer", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to the Convergence Layer", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Register Convergence Layer to Paymaster: Register the new Convergence Layer to the paymaster as a sponsored target, this means gas cost for interacting with the new Convergence Layer can be sponsored by the paymaster", Powers(payable(primaryLayer))));

        vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
        IPowers(primaryLayer).propose(mandateSlots[0], abi.encode(layerName, msg.sender), nonce, string.concat("Assigning role ID for convergence layer"));
        IPowers(primaryLayer).propose(mandateSlots[1], abi.encode(layerName, msg.sender), nonce, string.concat("Assigning delegate status for convergence layer"));
        IPowers(primaryLayer).propose(mandateSlots[2], abi.encode(layerName, msg.sender), nonce, string.concat("Registering convergence layer to paymaster"));
        vm.stopBroadcast();
    }

    function deployConvergenceLayer5(address primaryLayer, string memory layerName, uint256 nonce, uint256[] memory privateKeys) public {
        delete mandateSlots;
        delete actionIds;

        mandateSlots.push(findMandateIdInOrg("Assign role Id: Assign role Id 3 to Convergence Layer", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to the Convergence Layer", Powers(payable(primaryLayer))));
        mandateSlots.push(findMandateIdInOrg("Register Convergence Layer to Paymaster: Register the new Convergence Layer to the paymaster as a sponsored target, this means gas cost for interacting with the new Convergence Layer can be sponsored by the paymaster", Powers(payable(primaryLayer))));

        vm.startBroadcast(getPrivateKeyRoleHolder(primaryLayer, 2, 0, privateKeys));
        IPowers(primaryLayer).request(mandateSlots[0], abi.encode(layerName, msg.sender), nonce, string.concat("Assigning role ID for convergence layer"));
        IPowers(primaryLayer).request(mandateSlots[1], abi.encode(layerName, msg.sender), nonce, string.concat("Assigning delegate status for convergence layer"));
        IPowers(primaryLayer).request(mandateSlots[2], abi.encode(layerName, msg.sender), nonce, string.concat("Registering convergence layer to paymaster"));
        vm.stopBroadcast();

        deployedConvergenceLayer = Powers(payable(primaryLayer)).getRoleHolderAtIndex(3, 0);
        console2.log("Deployed Convergence Layer: ", deployedConvergenceLayer);
        unpackReformPackages(deployedConvergenceLayer, nonce, privateKeys);
        runSetupMandate(deployedConvergenceLayer, nonce, privateKeys);

        console2.log("Deployed Convergence Layer Successfully!");
    }

}
