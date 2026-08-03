// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@lib/powers-monorepo/solidity/script/Configurations.s.sol";
import { Safe } from "@lib/safe-smart-account/contracts/Safe.sol";
import { ModuleManager } from "@lib/safe-smart-account/contracts/base/ModuleManager.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";

import { PowersFactory } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersFactory.sol";
import { ElectionRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/ElectionRegistry.sol";
import { DeploySetup } from "./DeploySetup.s.sol";
import { Nominees } from "@lib/powers-monorepo/solidity/src/core/helpers/Nominees.sol";

/// @notice Deploys the shared helper contracts for the Simulation Test Org.
/// Unlike the original Cultural Stewardship DAO's Helpers.s.sol, this deploys only
/// `ElectionRegistry` (formal Steward-type elections) and `Nominees` (Convergence Layer
/// Steward PeerSelect candidate pool) — no `Soulbound1155`/`Soulbound1155Factory` activity
/// token and no `Governed721` art NFT, per Spec.md's token removal.
contract Helpers is DeploySetup {
    Nominees nominees;
    ElectionRegistry electionRegistry;

    function run() public {
        console2.log("Deploying Organisation's Helper contracts...");
        uint256 blocksPerHour = helperConfig.getBlocksPerHour(block.chainid);

        vm.startBroadcast();
        nominees = new Nominees();
        electionRegistry = new ElectionRegistry(minutesToBlocks(5, blocksPerHour), minutesToBlocks(5, blocksPerHour));
        vm.stopBroadcast();
    }

    function getNominees() public view returns (address) {
        return address(nominees);
    }

    function getElectionRegistry() public view returns (address) {
        return address(electionRegistry);
    }
}
