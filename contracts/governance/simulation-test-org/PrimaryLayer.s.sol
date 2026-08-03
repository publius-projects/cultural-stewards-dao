// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@lib/powers-monorepo/solidity/script/Configurations.s.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";

import { PowersFactory } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersFactory.sol";
import { ElectionRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/ElectionRegistry.sol";
import { DeploySetup } from "./DeploySetup.s.sol";
import { PowersPaymaster } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersPaymaster.sol";

import { Safe } from "@lib/safe-smart-account/contracts/Safe.sol";
import { ModuleManager } from "@lib/safe-smart-account/contracts/base/ModuleManager.sol";
import { SafeProxyFactory } from "@lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/// @notice Primary Layer — Simulation Test Org.
/// Derived from the Cultural Stewardship DAO's PrimaryLayer.s.sol. Changes (see Spec.md):
///  - "Mint token Convergence Layer" (GovernedToken_MintEncodedToken) removed outright — no
///    replacement, no `activityToken` dependency anywhere in this layer.
///  - "Claim Participant Role" flow step 2 replaced: GovernedToken_GatedAccess (token-gated) ->
///    BespokeAction_Advanced (Stewards vote to assign role 1 directly).
///  - Every votingPeriod/timelock/throttleExecution/quorum/succeedAt retimed per the Demo Timing
///    Policy (Spec.md): votingPeriod=2min, timelock=1min, throttleExecution=1min; two tiers —
///    standard 20%/51%, veto/high-trust 30%/66%.
///  - The 9-step Adopt Mandate reform flow and the 6-step formal Steward election are kept
///    structurally unchanged (per explicit design choice), only retimed.
contract PrimaryLayer is DeploySetup {
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;

    PowersTypes.MandateInitData[] constitution;
    Powers powers;

    uint16 public requestNewConvergenceLayerId;
    uint16 public requestAllowanceConvergenceLayerId;
    uint16 public requestAllowanceDigitalLayerId;
    uint16 public requestParticipantpowersId;
    uint16 public vetoConvergenceLayerMandateId;

    uint256 i;
    uint256 j;
    uint256 packageLength;
    bytes signature;

    //////////////////////////////////////////////////////////////////////
    //                        INITIALISATION                            //
    //////////////////////////////////////////////////////////////////////
    function run() public {
        console2.log("Deploying Primary Layer...");
        vm.startBroadcast();
            powers = new Powers(
                "Primary Layer", // name
                string.concat(baseURI, "primaryLayer.json"), // uri
                helperConfig.getMaxCallDataLength(block.chainid), // max call data length
                helperConfig.getMaxReturnDataLength(block.chainid), // max return data length
                helperConfig.getMaxExecutionsLength(block.chainid), // max executions length
                address(registry) // mandate registry
            );
        vm.stopBroadcast();

        console2.log("Primary Layer deployed at:", address(powers));

        // setup Safe treasury.
        address[] memory owners = new address[](1);
        owners[0] = address(powers);

        vm.startBroadcast();
        treasury = address(
            SafeProxyFactory(helperConfig.getSafeProxyFactory(block.chainid))
                .createProxyWithNonce(
                    helperConfig.getSafeL2Canonical(block.chainid),
                    abi.encodeWithSelector(
                        Safe.setup.selector,
                        owners,
                        1, // threshold
                        address(0), // to
                        "", // data
                        address(0), // fallbackHandler
                        address(0), // paymentToken
                        0, // payment
                        address(0) // paymentReceiver
                    ),
                    1 // = nonce
                )
        );
        vm.stopBroadcast();
        console2.log("Safe treasury deployed at:", treasury);

        // deploy paymaster (gasless transactions — kept per explicit user instruction).
        vm.startBroadcast();
        paymaster = address(new PowersPaymaster(
            IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032),
            address(powers)));
        vm.stopBroadcast();
        console2.log("Paymaster deployed at:", paymaster);
    }

    //////////////////////////////////////////////////////////////////////
    //                          CONSTITUTE                              //
    //////////////////////////////////////////////////////////////////////
    function constitutePowers(
        address digitalLayer,
        address ideasLayerFactory,
        address convergenceLayerFactory,
        address electionRegistry,
        uint16 assignConvergenceLayerMandateId
        ) public {
        _createConstitution(digitalLayer, ideasLayerFactory, convergenceLayerFactory, electionRegistry, assignConvergenceLayerMandateId);

        for (i = 0; i < constitution.length; i += PACKAGE_SIZE) {
            packageLength = constitution.length - i < PACKAGE_SIZE ? constitution.length - i : PACKAGE_SIZE;
            PowersTypes.MandateInitData[] memory constitutionPart = new PowersTypes.MandateInitData[](packageLength);
            for (j = 0; j < constitutionPart.length; j++) {
                constitutionPart[j] = constitution[i + j];
            }
            vm.startBroadcast();
            powers.constitute(constitutionPart);
            vm.stopBroadcast();
        }
        vm.startBroadcast();
        powers.closeConstitute(cedars, flows);
        vm.stopBroadcast();
    }

    //////////////////////////////////////////////////////////////////////
    //                            GETTERS                               //
    //////////////////////////////////////////////////////////////////////
    function getAddress() public view returns (address) {
        return address(powers);
    }

    function getTreasury() public view returns (address) {
        return treasury;
    }

    function _initMandateAddresses() internal {
        m_Adopt_Mandates = _latestMandateAddress("Adopt_Mandates");
        m_BespokeAction_Advanced = registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced");
        m_BespokeAction_OnReturnValue = registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue");
        m_BespokeAction_Simple = registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple");
        m_ElectionRegistry_CreateVoteMandate = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate");
        m_ElectionRegistry_Nominate = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate");
        m_ElectionRegistry_Tally = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally");
        m_ElectionRegistry_Vote = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote");
        m_ExternalAction_Flexible = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Flexible");
        m_PresetActions = registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions");
        m_PresetActions_OnOwnPowers = registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers");
        m_SafeAllowance_Action = registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Action");
        m_Safe_ExecTransaction = registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction");
        m_Safe_ExecTransaction_OnReturnValue = registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction_OnReturnValue");
        m_Safe_RecoverTokens = registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_RecoverTokens");
        m_StatementOfIntent = registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent");
    }

    //////////////////////////////////////////////////////////////////////
    //                        CONSTITUTION                              //
    //////////////////////////////////////////////////////////////////////
    function _createConstitution(
        address digitalLayer,
        address ideasLayerFactory,
        address convergenceLayerFactory,
        address electionRegistry,
        uint16 assignConvergenceLayerMandateId
        ) internal {
        blocksPerHour = helperConfig.getBlocksPerHour(block.chainid);
        mandateCount = 0;
        if (m_StatementOfIntent == address(0)) _initMandateAddresses();

        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        signature = abi.encodePacked(
            uint256(uint160(address(powers))), // r = address of the signer (powers contract)
            uint256(0), // s = 0
            uint8(1) // v = 1 This is a type 1 call. See Safe.sol for details.
        );

        targets = new address[](18);
        values = new uint256[](18);
        calldatas = new bytes[](18);

        for (i = 0; i < 18; i++) {
            targets[i] = address(powers);
        }
        targets[13] = treasury;
        targets[14] = treasury;
        targets[15] = paymaster;
        targets[16] = paymaster;

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Setup Initiators", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Participants", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Stewards", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Convergence Layers", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Ideas Layers", "");
        calldatas[6] = abi.encodeWithSelector(IPowers.labelRole.selector, 5, "Digital Layers", "");
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, testAccount1);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 5, digitalLayer);
        calldatas[11] = abi.encodeWithSelector(IPowers.setTreasury.selector, treasury);
        calldatas[12] = abi.encodeWithSelector(IPowers.setPaymaster.selector, paymaster);
        calldatas[13] = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            treasury,
            0,
            abi.encodeWithSelector(
                ModuleManager.enableModule.selector,
                helperConfig.getSafeAllowanceModule(block.chainid)
            ),
            0, 0, 0, 0, address(0), address(0),
            signature
        );
        calldatas[14] = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            helperConfig.getSafeAllowanceModule(block.chainid),
            0,
            abi.encodeWithSignature(
                "addDelegate(address)",
                digitalLayer
            ),
            0, 0, 0, 0, address(0), address(0),
            signature
        );
        calldatas[15] = abi.encodeWithSignature("addSponsoredTarget(address)", address(powers));
        calldatas[16] = abi.encodeWithSignature("addSponsoredTarget(address)", digitalLayer);
        calldatas[17] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: m_PresetActions,
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // SECOND SETUP //
        calldatas = new bytes[](4);
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, cedars);
        calldatas[1] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, hannah);
        calldatas[2] = abi.encodeWithSelector(IPowers.assignRole.selector, 0, cedars);
        calldatas[3] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Second Setup: Assign Stewards role to cedars and hannah, revokes itself after execution",
                targetMandate: m_PresetActions_OnOwnPowers,
                config: abi.encode(calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // CREATE IDEAS LAYER //
        uint16[] memory mandateIds = new uint16[](4);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;

        flows.push(PowersTypes.Flow({
            nameDescription: "Create and Revoke Ideas Layers: This flow includes the initiation and execution of the Ideas Layer creation, as well as the assigning of the role id to the new layer. This flow can be triggered by any Participant. It also includes the revoking of an Ideas layer.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "string Name";

        // Participants: Initiate Ideas Layer creation
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Ideas Layer: Initiate creation of Ideas Layer",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Execute Ideas Layer creation
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Ideas Layer: Execute Ideas Layer creation",
                targetMandate: m_BespokeAction_Simple,
                config: abi.encode(
                    address(ideasLayerFactory),
                    bytes4(keccak256("createPowers(string)")),
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Assign role Id to Ideas Layer //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign role Id to layer: Assign role id 4 (Ideas Layer) to the new layer",
                targetMandate: m_BespokeAction_OnReturnValue,
                config: abi.encode(
                    address(powers),
                    IPowers.assignRole.selector,
                    abi.encode(4),
                    inputParams,
                    mandateCount - 1,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Register Ideas layer to paymaster //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Register Ideas Layer to Paymaster: Register the new Ideas Layer to the paymaster as a sponsored target",
                targetMandate: m_BespokeAction_OnReturnValue,
                config: abi.encode(
                    paymaster,
                    bytes4(keccak256("addSponsoredTarget(address)")),
                    abi.encode(),
                    inputParams,
                    mandateCount - 2,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REVOKE IDEAS LAYER //
        inputParams = new string[](1);
        inputParams[0] = "address IdeasSubLayer";

        // Participants: Veto Revoke Ideas Layer creation mandate //
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto revoke Ideas Layer: Veto the revoking of an Ideas Layer from Cultural Stewards",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Revoke Ideas Layer (revoke role Id) //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.quorum = 30;
        conditions.succeedAt = 66;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke role Id: Revoke role id 4 (Ideas Layer) from the layer",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(powers),
                    IPowers.revokeRole.selector,
                    abi.encode(4),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Revoke Ideas layer from paymaster //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Ideas Layer from Paymaster: Remove the Ideas Layer from the paymaster's sponsored targets.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    paymaster,
                    bytes4(keccak256("removeSponsoredTarget(address)")),
                    abi.encode(),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // CREATE CONVERGENCE LAYER //
        mandateIds = new uint16[](6);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;

        flows.push(PowersTypes.Flow({
            nameDescription: "Create a Convergence Layer: This flow includes the initiation and execution of the Convergence Layer creation, as well as the assigning of the role id to the new layer and the assigning of delegate status to the new layer for the Safe treasury. This flow can only be triggered by an Ideas Layer.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](2);
        inputParams[0] = "string Name";
        inputParams[1] = "address Initiator";

        // Primary Stewards: Veto creation of Convergence Layer.
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto creation Convergence Layer: Stewards can veto the creation of a Convergence Layer from an Ideas Layer",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        vetoConvergenceLayerMandateId = mandateCount;

        // Ideas Layer: Create Convergence Layer
        mandateCount++;
        conditions.allowedRole = 4;
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Convergence Layer: Ideas Layers can create a Convergence Layer",
                targetMandate: m_BespokeAction_Simple,
                config: abi.encode(
                    address(convergenceLayerFactory),
                    bytes4(keccak256("createPowers(string,address)")),
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;
        requestNewConvergenceLayerId = mandateCount;

        // Primary Steward: Assign role Id to Convergence Layer //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needNotFulfilled = vetoConvergenceLayerMandateId;
        conditions.needFulfilled = requestNewConvergenceLayerId;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign role Id: Assign role Id 3 to Convergence Layer",
                targetMandate: m_BespokeAction_OnReturnValue,
                config: abi.encode(
                    address(powers),
                    IPowers.assignRole.selector,
                    abi.encode(uint16(3)),
                    inputParams,
                    mandateCount - 1,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Assign Delegate status to Convergence Layer //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needNotFulfilled = vetoConvergenceLayerMandateId;
        conditions.needFulfilled = requestNewConvergenceLayerId;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Delegate status: Assign delegate status at Safe treasury to the Convergence Layer",
                targetMandate: m_Safe_ExecTransaction_OnReturnValue,
                config: abi.encode(
                    helperConfig.getSafeAllowanceModule(block.chainid),
                    bytes4(0xe71bdf41),
                    abi.encode(),
                    inputParams,
                    mandateCount - 2,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Register Convergence layer to paymaster //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needNotFulfilled = vetoConvergenceLayerMandateId;
        conditions.needFulfilled = requestNewConvergenceLayerId;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Register Convergence Layer to Paymaster: Register the new Convergence Layer to the paymaster as a sponsored target, this means gas cost for interacting with the new Convergence Layer can be sponsored by the paymaster",
                targetMandate: m_BespokeAction_OnReturnValue,
                config: abi.encode(
                    paymaster,
                    bytes4(keccak256("addSponsoredTarget(address)")),
                    abi.encode(),
                    inputParams,
                    mandateCount - 3,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: assign convergence role ID to new layer at digital layer. //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.needNotFulfilled = vetoConvergenceLayerMandateId;
        conditions.needFulfilled = requestNewConvergenceLayerId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Convergence Layer to Digital Layer: Assign the new Convergence Layer as a sponsored target to the Digital Layer, this means that the Convergence Layer can call functions on the Digital Layer with the paymaster sponsoring the gas cost.",
                targetMandate: m_BespokeAction_OnReturnValue,
                config: abi.encode(
                    digitalLayer,
                    bytes4(keccak256("request(uint16,bytes,uint256,string)")),
                    abi.encode(assignConvergenceLayerMandateId),
                    inputParams,
                    mandateCount - 4,
                    abi.encode(
                        1234,
                        "Assigning new Convergence Layer as a sponsored target to the Digital Layer"
                    )
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REVOKE CONVERGENCE LAYER //
        mandateIds = new uint16[](4);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;

        flows.push(PowersTypes.Flow({
            nameDescription: "Revoke Convergence Layer: This flow includes the vetoing and revoking of a Convergence Layer. The revoking is done by revoking the role id of the Convergence Layer, and revoking the delegate status at the Safe treasury. This flow can be triggered by any Steward, but the veto can only be triggered by Participants.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](2);
        inputParams[0] = "address ConvergenceSubLayer";
        inputParams[1] = "bool removeAllowance";

        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto revoke Convergence Layer: Veto the revoking of an Convergence Layer from Cultural Stewards",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Revoke Convergence Layer (Revoke Role ID) //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Role Id: Revoke role Id 3 from Convergence Layer",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(powers),
                    IPowers.revokeRole.selector,
                    abi.encode(3),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Revoke Convergence Layer (Revoke Delegate status) //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Delegate status: Revoke delegate status Convergence Layer at the Safe treasury",
                targetMandate: m_Safe_ExecTransaction,
                config: abi.encode(
                    inputParams,
                    bytes4(0xdd43a79f),
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Revoke Convergence layer from paymaster //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Convergence Layer from Paymaster: Remove the Convergence Layer from the paymaster's sponsored targets.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    paymaster,
                    bytes4(keccak256("removeSponsoredTarget(address)")),
                    abi.encode(),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ASSIGN ADDITIONAL ALLOWANCE TO CONVERGENCE LAYER //
        mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            nameDescription: "Assign additional allowance to a convergence layer: This flow includes the proposal, veto and execution of assigning an additional allowance. Any layer can propose to assign an additional allowance to either layer, but only the Primary Steward can execute it, and only the Participants can veto it.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](5);
        inputParams[0] = "address Sub-Layer";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        // Convergence Layer: Veto additional allowance
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.quorum = 30;
        conditions.succeedAt = 66;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto allowance: Veto setting an allowance to a Convergence Layer.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Convergence Layer: Request additional allowance
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request additional allowance: Any Convergence Layer can request an allowance from the Safe Treasury.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestAllowanceConvergenceLayerId = mandateCount;

        // Primary Steward: Grant Allowance to Convergence Layer
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.needFulfilled = mandateCount - 1;
        conditions.needNotFulfilled = mandateCount - 2;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Execute and set allowance for a Convergence Layer.",
                targetMandate: m_SafeAllowance_Action,
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388),
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ASSIGN ADDITIONAL ALLOWANCE TO DIGITAL LAYER //
        mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            nameDescription: "Assign additional allowance to a Digital Layer: This flow includes the proposal, veto and execution of assigning an additional allowance. Any layer can propose to assign an additional allowance to either layer, but only the Primary Steward can execute it, and only the Participants can veto it.",
            mandateIds: mandateIds
        }));

        // Convergence Layer: Veto additional allowance
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.quorum = 30;
        conditions.succeedAt = 66;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto allowance: Veto setting an allowance to the digital layer.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Digital Layer: Request additional allowance
        mandateCount++;
        conditions.allowedRole = 5;
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request additional allowance: The Digital Layer can request an allowance from the Safe Treasury.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestAllowanceDigitalLayerId = mandateCount;

        // Primary Steward: Grant Allowance to Digital Layer
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.needFulfilled = mandateCount - 1;
        conditions.needNotFulfilled = mandateCount - 2;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Execute and set allowance for the Digital Layer.",
                targetMandate: m_SafeAllowance_Action,
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388),
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // UPDATE URI //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Update Primary Layer URI: This flow includes the veto and execution of updating the Primary Layer URI. Only Participants can veto, but any Steward can execute the update.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Participants: Veto update URI
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto update URI: Participants can veto updating the Primary Layer URI",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Update URI
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: Set allowed token for Cultural Stewards",
                targetMandate: m_BespokeAction_Simple,
                config: abi.encode(
                    address(powers),
                    IPowers.setUri.selector,
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;


        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // CLAIM PARTICIPANT ROLE (PRIMARY LAYER) //
        // Replaces the original's token-gated (GovernedToken_GatedAccess) step 2 with a
        // Steward vote that assigns role 1 directly — see Spec.md "Flow: Claim Participant Role".
        mandateIds = new uint16[](4);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;

        flows.push(PowersTypes.Flow({
            nameDescription: "Claim and revoke Participant Primary Layer: This flow includes the claiming and revoking of the Participant role at the Primary Layer. To claim the Participant role, an address needs to first express their intent at an Ideas Layer, after which Stewards vote to approve and assign the role directly (no token check). The revoking of the Participant role can only be done by the Primary Steward, but it requires a veto from the Participants.",
            mandateIds: mandateIds
        }));

        // Ideas LAYER: request Participant - statement of intent.
        inputParams = new string[](1);
        inputParams[0] = "address Applicant";

        mandateCount++;
        conditions.allowedRole = 4; // = ideas layer
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Participant Step 1: A forwarded request to become Participant from an Ideas Layer",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestParticipantpowersId = mandateCount;

        // Stewards: vote to assign Participant role directly (replaces token-gated check).
        mandateCount++;
        conditions.allowedRole = 2; // = Stewards
        conditions.needFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Participant Step 2: Stewards vote to assign the Participant role to the candidate forwarded by an Ideas Layer.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(powers),
                    IPowers.assignRole.selector,
                    abi.encode(1), // params before: role id 1 = Participants
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        inputParams = new string[](1);
        inputParams[0] = "address ParticipantAddress";

        // Participants: veto Revoke Participant
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Revoke Participant: Participants can veto revoking Participant from other Participants.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Primary Steward: Revoke Participant
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Participant: Primary Steward can revoke Participant from Participants.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(powers),
                    IPowers.revokeRole.selector,
                    abi.encode(1),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ELECT PRIMARY STEWARD // (kept structurally unchanged — 6-step formal election)
        mandateIds = new uint16[](6);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;

        flows.push(PowersTypes.Flow({
            nameDescription: "Elect Primary Steward: This flow includes the creation of an Steward election, opening the vote, tallying the results and cleaning up after the election. Any Participant can trigger this flow, but it requires multiple steps that need to be executed by different roles, so effectively it requires the coordination of both Participants and Primary Steward to successfully elect new Primary Steward.",
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
                nameDescription: "Create an Steward election: an election for the Steward role can be initiated be any Participant. After the election is created, participants have 2 minutes to nominate themselves.",
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

        // Participants: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for Steward election: After the initiation of an election, participants can open the vote. This will create a dedicated vote mandate. The vote will stay open for 2 minutes.",
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
                    5
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up Steward election: After an Steward election has finished, clean up related mandates.",
                targetMandate: m_BespokeAction_OnReturnValue,
                config: abi.encode(
                    address(powers),
                    IPowers.revokeMandate.selector,
                    abi.encode(),
                    inputParams,
                    mandateCount - 2,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Participants: Nominate for Steward election
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

        // Participants revoke nomination for Steward election.
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

        // ADOPT MANDATE // (kept structurally unchanged — 9-step 4-way veto reform flow)
        mandateIds = new uint16[](9);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;
        mandateIds[6] = mandateCount + 7;
        mandateIds[7] = mandateCount + 8;
        mandateIds[8] = mandateCount + 9;

        flows.push(PowersTypes.Flow({
            nameDescription: "Adopt Mandate: This flow includes the proposal, veto and execution of adopting a new mandate into the constitution. Any layer can propose to adopt a new mandate into the constitution, but only the Primary Steward can execute it, and the Participants and all layers have veto power over it.",
            mandateIds: mandateIds
        }));

        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Primary Steward: Propose Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate mandate adoption: Any Steward can propose adopting new mandates into the organization.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        uint16 initiateReformId = mandateCount;

        // Participants: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needFulfilled = initiateReformId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Participants can veto proposals to adopt new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 vetoParticipantsId = mandateCount;

        // Digital Layer: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 5;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = initiateReformId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Digital Layer can veto proposals to adopt new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 vetoDigitalId = mandateCount;

        // Ideas Layers: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 4;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = initiateReformId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Ideas Layer can veto proposals to adopt new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 vetoIdeasId = mandateCount;

        // Convergence Layers: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = initiateReformId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Convergence Layer can veto proposals to adopt new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 vetoConvergenceId = mandateCount;

        // Checkpoint 1: Primary Steward confirm Participants Veto passed (or timed out without veto)
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = initiateReformId;
        conditions.needNotFulfilled = vetoParticipantsId;
        conditions.timelock = minutesToBlocks(2, blocksPerHour); // match voting period
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Reform Checkpoint 1: Primary Steward confirm Participants did not veto.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 checkpoint1Id = mandateCount;

        // Checkpoint 2: Primary Steward confirm Digital Veto passed
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = checkpoint1Id;
        conditions.needNotFulfilled = vetoDigitalId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Reform Checkpoint 2: Primary Steward confirm Digital Layer did not veto.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 checkpoint2Id = mandateCount;

        // Checkpoint 3: Primary Steward confirm Ideas Veto passed
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = checkpoint2Id;
        conditions.needNotFulfilled = vetoIdeasId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Reform Checkpoint 3: Primary Steward confirm Ideas Layer did not veto.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 checkpoint3Id = mandateCount;

        // Primary Steward: Adopt Mandates (Final Step)
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needFulfilled = checkpoint3Id;
        conditions.needNotFulfilled = vetoConvergenceId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Primary Steward can adopt new mandates into the organization.",
                targetMandate: m_Adopt_Mandates,
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        // MISCELLANEOUS //
        // EXECUTE VETO ON MANDATE ADOPTION AT OTHER SUB-layer //
        inputParams = new string[](2);
        inputParams[0] = "uint16[] MandateId";
        inputParams[1] = "uint256[] roleIds";

        // Executioners: Veto call to Powers instance and mandateIds in other layers
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Call to sub-layers: Executioners can veto updating the Primary Layer URI",
                targetMandate: m_ExternalAction_Flexible,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // NB: "Mint token Convergence Layer" (GovernedToken_MintEncodedToken) removed outright —
        // no activity token exists in this org (see Spec.md).

        // TRANSFER TOKENS INTO TREASURY //
        mandateCount++;
        conditions.allowedRole = 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the Primary Layer can be recovered by sending them to the treasury",
                targetMandate: m_Safe_RecoverTokens,
                config: abi.encode(
                    treasury,
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;
    }
}
