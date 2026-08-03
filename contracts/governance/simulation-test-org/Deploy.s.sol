// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@lib/powers-monorepo/solidity/script/Configurations.s.sol";

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { SafeProxyFactory } from "@lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { Safe } from "@lib/safe-smart-account/contracts/Safe.sol";

import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";

import { Nominees } from "@lib/powers-monorepo/solidity/src/core/helpers/Nominees.sol";
import { ElectionRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/ElectionRegistry.sol";
import { PowersFactory } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersFactory.sol";
import { PowersDeployer } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersDeployer.sol";
import { PowersPaymaster } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersPaymaster.sol";

import { Helpers } from "./Helpers.s.sol";
import { PrimaryLayer } from "./PrimaryLayer.s.sol";
import { DigitalLayer } from "./DigitalLayer.s.sol";
import { IdeasLayer } from "./IdeasLayer.s.sol";
import { ConvergenceLayer } from "./ConvergenceLayer.s.sol";

/// @title Simulation Test Org - Deployment Script
/// @notice Top-level orchestrator: deploys Helpers, then Primary -> Digital -> Ideas ->
/// Convergence in dependency order. Derived from the Cultural Stewardship DAO's Deploy.s.sol.
/// Changes (see Spec.md):
///  - No `zkPassport_PowersRegistry` wiring anywhere — this org has no ZKPassport dependency.
///  - No `Soulbound1155`/`Governed721` deployment and no ownership-transfer lines for them
///    (Helpers.s.sol only deploys `ElectionRegistry` and `Nominees`).
///  - Safe treasury and `PowersPaymaster` deployment/funding are KEPT (account abstraction is
///    explicitly required for this org — gasless transactions for the live demo).
///  - This script stays focused on constitution only. Seeding the two demo Ideas Layers named
///    "Yin" and "Yang" is done separately via `actions/InitialiseRunner.s.sol`, run repeatedly
///    after this script (its phases are gated by real voting-period/timelock windows, which
///    cannot be fast-forwarded on a live testnet) — see README.md's deployment walkthrough.
contract Deploy is Script {
    PrimaryLayer primaryLayer;
    DigitalLayer digitalLayer;
    IdeasLayer ideasLayerFactory;
    ConvergenceLayer convergenceLayerFactory;
    Helpers helpers;

    /// @notice The two Ideas Layers pre-seeded for the live demo — see Spec.md "Demo Setup".
    /// Actual creation happens post-deploy via actions/InitialiseRunner.s.sol, not in this script.
    string[] public ideasLayerNames = ["Yin", "Yang"];

    function run() external returns (address primaryAddress, address digitalAddress, address ideasLayerFactoryAddress, address convergenceLayerFactoryAddress) {
        // step 1, setup.
        primaryLayer = new PrimaryLayer();
        digitalLayer = new DigitalLayer();
        ideasLayerFactory = new IdeasLayer();
        convergenceLayerFactory = new ConvergenceLayer();
        helpers = new Helpers();

        // step 2, deploying the core Powers and Powers factory instances:
        primaryLayer.run();
        digitalLayer.run();
        ideasLayerFactory.run();
        convergenceLayerFactory.run();
        helpers.run();

        // step 3, constituting the powers instances and powers factories.
        primaryLayer.constitutePowers(
            digitalLayer.getAddress(),
            ideasLayerFactory.getAddress(),
            convergenceLayerFactory.getAddress(),
            helpers.getElectionRegistry(),
            digitalLayer.getAssignConvergenceLayer()
        );
        digitalLayer.constitutePowers(
            primaryLayer.getAddress(),
            helpers.getElectionRegistry(),
            primaryLayer.requestAllowanceDigitalLayerId()
        );
        ideasLayerFactory.constitutePowers(
            primaryLayer.getAddress(),
            helpers.getElectionRegistry(),
            primaryLayer.getTreasury(),
            primaryLayer.requestParticipantpowersId(),
            primaryLayer.requestNewConvergenceLayerId()
        );
        convergenceLayerFactory.constitutePowers(
            primaryLayer.getAddress(),
            helpers.getNominees(),
            primaryLayer.requestAllowanceConvergenceLayerId()
        );

        // step 4: transfer ownership of helper contracts to Primary Layer.
        vm.startBroadcast();
        console2.log("Transferring ownership of Organisational helper contracts to Primary Layer...");
        Nominees(helpers.getNominees()).transferOwnership(primaryLayer.getAddress());
        vm.stopBroadcast();

        console2.log("Success! All contracts successfully deployed and constituted.");
        console2.log("Next step: run actions/InitialiseRunner.s.sol repeatedly to seed the 'Yin' and 'Yang' Ideas Layers (see README.md).");

        return (primaryLayer.getAddress(), digitalLayer.getAddress(), ideasLayerFactory.getAddress(), convergenceLayerFactory.getAddress());
    }
}
