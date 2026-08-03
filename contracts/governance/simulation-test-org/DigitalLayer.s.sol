// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { DeploySetup } from "./DeploySetup.s.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { ElectionRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/ElectionRegistry.sol";

/// @notice Digital Layer — Simulation Test Org.
/// Per Spec.md, this layer needs ZERO structural changes from the original Cultural Stewardship
/// DAO's DigitalLayer.s.sol — it never used tokens or ZKPassport. Only retimed per the Demo Timing
/// Policy and mandate-address wiring adapted to this org's DeploySetup/registry.
contract DigitalLayer is DeploySetup {
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;

    PowersTypes.MandateInitData[] constitution;
    Powers powers;
    uint16 assignConvergenceLayer;

    //////////////////////////////////////////////////////////////////////
    //                        INITIALISATION                            //
    //////////////////////////////////////////////////////////////////////
    function run() public {
        console2.log("Deploying Digital Layer...");
        vm.startBroadcast();
            powers = new Powers(
                "Digital Layer",
                string.concat(baseURI, "digitalLayer.json"),
                helperConfig.getMaxCallDataLength(block.chainid),
                helperConfig.getMaxReturnDataLength(block.chainid),
                helperConfig.getMaxExecutionsLength(block.chainid),
                address(registry)
            );
        vm.stopBroadcast();

        console2.log("Digital Layer deployed at:", address(powers));

        // running constitute script with empty data to calculate assignConvergenceLayerMandateId.
        _createConstitution(
            address(0),
            address(0),
            0
         );
    }

    //////////////////////////////////////////////////////////////////////
    //                          CONSTITUTE                              //
    //////////////////////////////////////////////////////////////////////
    function constitutePowers(
        address primaryLayer,
        address electionRegistry,
        uint16 requestAllowanceDigitalLayerId
    ) public {
        delete constitution;
        _createConstitution(primaryLayer, electionRegistry, requestAllowanceDigitalLayerId);

        for (uint256 i = 0; i < constitution.length; i += PACKAGE_SIZE) {
            uint256 packageLength = constitution.length - i < PACKAGE_SIZE ? constitution.length - i : PACKAGE_SIZE;
            PowersTypes.MandateInitData[] memory constitutionPart = new PowersTypes.MandateInitData[](packageLength);
            for (uint256 j = 0; j < constitutionPart.length; j++) {
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

    function getAssignConvergenceLayer() public view returns (uint16) {
        return assignConvergenceLayer;
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
        m_ExternalAction_Simple = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple");
        m_PresetActions_OnOwnPowers = registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers");
        m_SafeAllowance_Transfer = registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Transfer");
        m_Safe_RecoverTokens = registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_RecoverTokens");
        m_StatementOfIntent = registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent");
    }

    //////////////////////////////////////////////////////////////////////
    //                        CONSTITUTION                              //
    //////////////////////////////////////////////////////////////////////
    function _createConstitution(
        address primaryLayer,
        address electionRegistry,
        uint16 requestAllowanceDigitalLayerId
    ) internal {
        blocksPerHour = helperConfig.getBlocksPerHour(block.chainid);
        mandateCount = 0;
        if (m_StatementOfIntent == address(0)) _initMandateAddresses();

        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        calldatas = new bytes[](12);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Read", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Write", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Maintain", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 6, "Primary Layer", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 7, "Convergence Layer", "");
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, testAccount1);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, hannah);
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, hannah);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 6, primaryLayer);
        calldatas[11] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

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
        calldatas[0] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, cedars);
        calldatas[1] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, hannah);
        calldatas[2] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, cedars);
        calldatas[3] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, hannah);
        calldatas[4] = abi.encodeWithSelector(IPowers.assignRole.selector, 0, cedars);
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Second Setup: Assign Write and Maintain roles to cedars and hannah, revokes itself after execution",
                targetMandate: m_PresetActions_OnOwnPowers,
                config: abi.encode(calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // REQUEST ALLOWANCES FROM PRIMARY LAYER //
        uint16[] memory mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Request Allowances from Primary Layer: This flow includes the veto and request of allowances from the Primary Layer.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](5);
        inputParams[0] = "address DigitalLayer";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        // Writers: Veto request allowance from Primary Layer
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto request allowance: Writers can veto a request for additional allowance",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Repository admins: Request allowance from Primary Layer
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request allowance: Repository admins can request an allowance from the Primary Layer Safe Treasury.",
                targetMandate: m_ExternalAction_Simple,
                config: abi.encode(
                    address(primaryLayer),
                    requestAllowanceDigitalLayerId,
                    "Requesting allowance from Primary Layer Safe Treasury",
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // PAYMENT OF GENERAL RECEIPTS //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Payment of Receipts: This flow includes the submission, oking, and approval of receipts for payment reimbursement.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](3);
        inputParams[0] = "address token";
        inputParams[1] = "uint256 amount";
        inputParams[2] = "address payableTo";

        // Public: Submit a receipt (Payment Reimbursement - After Action)
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Submit a Receipt: Anyone can submit a receipt for payment reimbursement.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Repository admins: Approve Payment of Receipt
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Approve payment of receipt: Execute a transaction from the Safe Treasury.",
                targetMandate: m_SafeAllowance_Transfer,
                config: abi.encode(helperConfig.getSafeAllowanceModule(block.chainid), treasury),
                conditions: conditions
            })
        );
        delete conditions;

        // REQUESTS FROM CONVERGENCE LAYER //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Request from Convergence Layer: This flow handles requests for project payments coming from the Convergence Layer.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](3);
        inputParams[0] = "address token";
        inputParams[1] = "uint256 amount";
        inputParams[2] = "address payableTo";

        // Public: Submit a receipt (Payment Reimbursement - After Action)
        mandateCount++;
        conditions.allowedRole = 7;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Submit a Request: Any Convergence Layer can submit a request for project payments in their name.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Repository admins: Approve Payment of Receipt
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Approve payment for request: Executes a transaction from the Safe Treasury.",
                targetMandate: m_SafeAllowance_Transfer,
                config: abi.encode(helperConfig.getSafeAllowanceModule(block.chainid), treasury),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // REVOKE Writer //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Revoke Writer: This flow allows Writers to veto and Executives to revoke Writer role.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "address WriterAddress";

        // Writers: veto Revoke Writer
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Revoke Writer: Writers can veto revoking Writer from other Writers.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Revoke Writer
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.timelock = minutesToBlocks(1, blocksPerHour);
        conditions.needNotFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Writer: Executives can revoke Writer role.",
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

        // ELECT Repository admins //
        mandateIds = new uint16[](6);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;

        flows.push(PowersTypes.Flow({
            nameDescription: "Elect Repository Setup Initiators: This flow includes the creation, voting, tallying, and cleanup of an election for Repository Setup Initiators.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "string Title";

        // Writers: create election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.throttleExecution = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create a Convener election: an election for the convener role can be initiated be any Writer. After an election is created, participants have 2 minutes to nominate themselves.",
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

        // Writers: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for Convener election: After initiating an election, Writers can open the vote for a convener election. This will create a dedicated vote mandate. The vote will stay open for 2 minutes.",
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

        // Writers: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally Convener elections: After the vote closes, tally the results and assign the Convener role to the winners.",
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

        // Writers: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up Convener election: After tallying the results, clean up related mandates.",
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

        // Writers: Nominate for Executive election
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any Writer can nominate for an election.",
                targetMandate: m_ElectionRegistry_Nominate,
                config: abi.encode(electionRegistry, true),
                conditions: conditions
            })
        );
        delete conditions;

        // Writers revoke nomination for Executive election.
        mandateCount++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any Writer can revoke their nomination for an election.",
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
        mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            nameDescription: "Adopt Mandates: This flow allows for the adoption of new mandates, initiated by Writers, adopted by Repository admins, and subject to veto by the Primary Layer.",
            mandateIds: mandateIds
        }));

        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Writers: initiate Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Adopting Mandates: Writers can initiate adopting new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // primaryLayer: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 6;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: primaryLayer can veto proposals to adopt new mandates",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Repository admins: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Repository admins can adopt new mandates into the organization",
                targetMandate: m_Adopt_Mandates,
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        // UPDATE URI //
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Repository admins: Update URI
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
                    address(powers),
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
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the Layer can be recovered by sending them to the treasury",
                targetMandate: m_Safe_RecoverTokens,
                config: abi.encode(
                    treasury,
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ASSIGN: CONVERGENCE LAYER ROLE
        inputParams = new string[](1);
        inputParams[0] = "address ConvergenceLayer";

        mandateCount++;
        conditions.allowedRole = 6;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Convergence Layer Role: The Primary Layer can assign the Convergence Layer role to accounts of their choosing. This is necessary for the Convergence Layer to be able to submit requests for payments.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(7),
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;
        assignConvergenceLayer = mandateCount;
    }
}
