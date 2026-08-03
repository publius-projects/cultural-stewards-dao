// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/console2.sol";
import { DeploySetup } from "./DeploySetup.s.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { Nominees } from "@lib/powers-monorepo/solidity/src/core/helpers/Nominees.sol";
import { PowersFactory } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersFactory.sol";
import { PowersDeployer } from "@lib/powers-monorepo/solidity/src/core/helpers/PowersDeployer.sol";

/// @notice Convergence Layer (PowersFactory template) — Simulation Test Org.
/// Derived from the Cultural Stewardship DAO's ConvergenceLayer.s.sol. Changes (see Spec.md):
///  - "Sell NFT artwork" (Governed721) removed outright — no replacement.
///  - "Mint POAPs for Attendees" removed outright — its target mandate (Primary Layer's
///    GovernedToken_MintEncodedToken) no longer exists.
///  - "Request Membership" (GovernedToken_GatedAccess, token-gated) replaced with a 2-step
///    "Claim Attendee Role" flow: StatementOfIntent (Public, throttled) -> BespokeAction_Advanced
///    (Steward vote, assigns role 1 directly).
///  - "Select Stewards" flow: ZKPassport_Check age-gate step removed with no replacement (the
///    `Nominate` mandate's fixed `bool shouldNominate` input schema cannot carry a self-attested
///    payload — accepted gap, see Spec.md Limitations). Resulting flow: Nominate (open) ->
///    revoke-nomination (Legal Interfacer) -> PeerSelect (Legal Interfacer).
///  - Setup `PresetActions_OnOwnPowers` calldata extended with one extra call —
///    `assignRole(3, hannah)` — so every spawned Convergence Layer instance auto-assigns an
///    initial Legal Interfacer at creation (the same demo Steward account already used for
///    initial Primary Layer Stewards in DeploySetup.s.sol). This must be static/template-wide
///    since the factory reuses one template for every instance — see Spec.md's "Demo Setup"
///    section for why a per-instance dynamic assignment isn't feasible here.
///  - `PauseMandates` target list rebuilt: the original referenced a stale, never-adopted
///    mandate name ("Vote on 'Merit' NFT proposals") that never actually resolved to anything
///    (a silent no-op bug). Replaced with two mandates that genuinely exist in this layer:
///    payment-of-receipts and allowance-request.
///  - `zkPassport_PowersRegistry`/`activityToken`/`governed721`/`mintPoapTokenId` parameters
///    removed entirely from `constitutePowers`/`_createConstitution`.
///  - Every votingPeriod/timelock/throttleExecution/quorum/succeedAt retimed per the Demo Timing
///    Policy. "Assign Legal Interfacer" (called externally by the Ideas Layer) is kept
///    structurally unchanged, only its input params are adapted to the new forwarding shape.
contract ConvergenceLayer is DeploySetup {
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;

    PowersTypes.MandateInitData[] constitution;
    PowersFactory powersFactory;

    //////////////////////////////////////////////////////////////////////
    //                        INITIALISATION                            //
    //////////////////////////////////////////////////////////////////////
    function run() external {
        console2.log("Deploying Convergence Layer factory (contract only)...");
        vm.startBroadcast();
        PowersDeployer ConvergenceLayerDeployer = new PowersDeployer();
        powersFactory = new PowersFactory(
            string.concat(baseURI, "convergenceLayer.json"),
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(ConvergenceLayerDeployer),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Convergence Layer factory deployed at:", address(powersFactory));
    }

    //////////////////////////////////////////////////////////////////////
    //                          CONSTITUTE                              //
    //////////////////////////////////////////////////////////////////////
    function constitutePowers(
        address primaryLayer,
        address nominees,
        uint16 requestAllowanceConvergenceLayerId
    ) public {
        _createConstitution(primaryLayer, nominees, requestAllowanceConvergenceLayerId);

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
        m_ExternalAction_Simple = registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple");
        m_Nominate = registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate");
        m_PauseMandates = registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates");
        m_PeerSelect = registry.getMandateAddress(MAJOR, MINOR, PATCH, "PeerSelect");
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
        address nominees,
        uint16 requestAllowanceConvergenceLayerId
    ) internal {
        blocksPerHour = helperConfig.getBlocksPerHour(block.chainid);
        mandateCount = 3; // resetting mandate count (matches original factory-template offset).
        if (m_StatementOfIntent == address(0)) _initMandateAddresses();
        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////

        // setup role labels //
        calldatas = new bytes[](13);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Ideas Layer", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Attendee", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Steward", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Legal Interfacer", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 6, "Primary Layer", "");
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 0, cedars);
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, testAccount1);
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, testAccount1);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 6, primaryLayer);
        // Demo Setup: auto-assign the designated demo Steward account (hannah — see
        // DeploySetup.s.sol) as this Convergence Layer's initial Legal Interfacer, so "Request
        // funds" works immediately after creation with no live nomination step. See Spec.md's
        // "Demo Setup — Pre-Seeded State" section for why this must be static per-template.
        calldatas[11] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, hannah);
        calldatas[12] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

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

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // NB: "Sell NFT artwork" (Governed721) removed outright — no art-sale mechanism in this
        // org (see Spec.md Limitations).

        // REQUEST ALLOWANCES FROM PRIMARY LAYER //
        uint16[] memory mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Request Allowances from Primary Layer: This flow includes the veto and request of allowances from the Primary Layer.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](5);
        inputParams[0] = "address ConvergenceLayer";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        // Stewards: Veto request allowance from Primary Layer
        mandateCount++;
        conditions.allowedRole = 2;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto request allowance: Stewards can veto a request for additional allowance",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Legal Interfacer: Request allowance from Primary Layer
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request allowance: Legal Interfacer can request an allowance from the Primary Layer Safe Treasury.",
                targetMandate: m_ExternalAction_Simple,
                config: abi.encode(
                    address(primaryLayer),
                    requestAllowanceConvergenceLayerId,
                    "Requesting allowance from Primary Layer Safe Treasury",
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // PAYMENT OF RECEIPTS //
        mandateIds = new uint16[](1);
        mandateIds[0] = mandateCount + 1;

        flows.push(PowersTypes.Flow({
            nameDescription: "Payment of Receipts: This flow allows Stewards to submit and approve payment of receipts.",
            mandateIds: mandateIds
        }));

        inputParams = new string[](3);
        inputParams[0] = "address Token";
        inputParams[1] = "uint256 Amount";
        inputParams[2] = "address PayableTo";

        // Stewards: Submit & approve Payment of Receipt
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Submit & Approve payment of receipt: Execute a transaction from the Safe Treasury.",
                targetMandate: m_SafeAllowance_Transfer,
                config: abi.encode(helperConfig.getSafeAllowanceModule(block.chainid), treasury),
                conditions: conditions
            })
        );
        delete conditions;

        // ASSIGN LEGAL INTERFACER (from Ideas Layer) //
        // Called by the parent Ideas Layer (role 0) via ExternalAction_Flexible after the
        // Primary Layer veto window expires. Receives (address Candidate, bool AttestsAge18Plus,
        // bool AttestsGBREligible) as forwarded calldata and assigns role 3 (Legal Interfacer) on
        // this CL — role id is fixed in `paramsBefore`, only Candidate is functionally used.
        // NB: role 0 must be assigned to the parent Ideas Layer instance at CL instantiation time.
        mandateIds = new uint16[](1);
        mandateIds[0] = mandateCount + 1;

        flows.push(PowersTypes.Flow({
            nameDescription: "Assign Legal Interfacer: The parent Ideas Layer assigns the Legal Interfacer role (role 3) after its own propose/veto flow completes. Called externally via ExternalAction_Flexible. Used to REPLACE the Legal Interfacer after the initial auto-assignment at creation.",
            mandateIds: mandateIds
        }));

        {
            string[] memory assignLegalInterfacerParams = new string[](3);
            assignLegalInterfacerParams[0] = "address Candidate";
            assignLegalInterfacerParams[1] = "bool AttestsAge18Plus";
            assignLegalInterfacerParams[2] = "bool AttestsGBREligible";

            mandateCount++;
            conditions.allowedRole = 0; // = Ideas Layer (role 0 must be assigned to the parent IL instance at CL setup)
            constitution.push(
                PowersTypes.MandateInitData({
                    nameDescription: "Assign Legal Interfacer: The parent Ideas Layer can assign the Legal Interfacer role (role 3) to a candidate after its own propose/veto flow completes.",
                    targetMandate: m_BespokeAction_Advanced,
                    config: abi.encode(
                        address(0), // target: own Powers contract
                        IPowers.assignRole.selector,
                        abi.encode(uint256(3)), // paramsBefore — role id 3 = Legal Interfacer, fixed
                        assignLegalInterfacerParams, // Candidate + attestation booleans (booleans unused, decoded and ignored)
                        abi.encode() // no paramsAfter
                    ),
                    conditions: conditions
                })
            );
        }
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // NB: "Mint POAPs for Attendees" removed outright — no activity token exists in this org.

        // CLAIM ATTENDEE ROLE //
        // Replaces the original's token-gated "Request Membership" (GovernedToken_GatedAccess)
        // with a governance-approved application, mirroring the Primary Layer's "Claim
        // Participant Role" flow and the Ideas Layer's own Participant-application pattern.
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            nameDescription: "Claim Attendee Role: This flow allows anyone to apply for the Attendee role; a Steward vote assigns it directly (no token check - see Spec.md).",
            mandateIds: mandateIds
        }));

        inputParams = new string[](1);
        inputParams[0] = "address Applicant";

        // Public: apply for Attendee role (throttled).
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        conditions.throttleExecution = minutesToBlocks(1, blocksPerHour);
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Apply for Attendee role: Anyone can apply for the Attendee role of this Convergence Layer by submitting an application.",
                targetMandate: m_StatementOfIntent,
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Stewards: assess and assign Attendee role.
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assess and Assign Attendee: Stewards can assess applications and assign the Attendee role to applicants.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(1), // role id 1 = Attendee
                    inputParams,
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // SELECT Stewards //
        // ZKPassport_Check age-gate step removed — the Nominate mandate's fixed
        // `bool shouldNominate` input schema has no room for a self-attestation payload, so this
        // instance of ZKPassport removal has no direct replacement (see Spec.md Limitations).
        mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            nameDescription: "Select Stewards: This flow allows for the nomination and peer election of Stewards. Nomination is open to anyone (no eligibility gate - see Spec.md Limitations).",
            mandateIds: mandateIds
        }));

        // Anyone: Nominate for selection to be Steward.
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for selection: any member can nominate to be selected for Steward role.",
                targetMandate: m_Nominate,
                config: abi.encode(nominees),
                conditions: conditions
            })
        );
        delete conditions;

        // Legal Interfacers: force revoke nomination.
        inputParams = new string[](1);
        inputParams[0] = "address Nominee";

        mandateCount++;
        conditions.allowedRole = 3;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: Legal Interfacers can revoke nominations for Steward elections.",
                targetMandate: m_BespokeAction_Advanced,
                config: abi.encode(
                    nominees,
                    Nominees.revokeNomination.selector,
                    abi.encode(),
                    inputParams,
                    abi.encode(false)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Legal Interfacers: adopt peer select mandate to select Stewards from the pool of nominees.
        mandateCount++;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        conditions.maxExecutionDelay = minutesToBlocks(2, blocksPerHour); // stale-state rule: PeerSelect reads live nominee state.
        conditions.allowedRole = 3;
        constitution.push(PowersTypes.MandateInitData({
                nameDescription: "Select Stewards: Legal Interfacers can select Stewards from the pool of nominees.",
                targetMandate: m_PeerSelect,
                config: abi.encode(
                    uint8(3),
                    uint256(2),
                    nominees
                ),
                conditions: conditions
            }));
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
            nameDescription: "Adopt Mandates: This flow allows for the adoption of new mandates, initiated by Members, adopted by Stewards, and subject to veto by the Primary Layer. It also allows for pausing of mandates by Legal Interfacers.",
            mandateIds: mandateIds
        }));

        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Members: initiate Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Adopting Mandates: Members can initiate adopting new mandates",
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

        // Stewards: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = mandateCount - 2;
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

        // LEGAL REPS CAN PAUSE AND RESTART MANDATES //
        mandateIds = new uint16[](1);
        mandateIds[0] = mandateCount + 1;

        flows.push(PowersTypes.Flow({
            nameDescription: "Pause Mandates: This flow allows Legal Interfacers to adopt or revoke executive mandates, effectively controlling the Layer's functional state.",
            mandateIds: mandateIds
        }));

        // Pause targets rebuilt to reference mandates that genuinely exist in this simplified
        // layer — the original's target list included a stale reference to a mandate that was
        // never actually adopted ("Vote on 'Merit' NFT proposals"), which silently resolved to
        // an empty index set. These two strings must match the nameDescriptions pushed above
        // exactly (findIndices does an exact string match).
        string[] memory mandatesToPause = new string[](2);
        mandatesToPause[0] = "Submit & Approve payment of receipt: Execute a transaction from the Safe Treasury.";
        mandatesToPause[1] = "Request allowance: Legal Interfacer can request an allowance from the Primary Layer Safe Treasury.";
        (uint16[] memory indexFlows16, uint16[] memory indexMandates16) = findIndices(mandatesToPause, constitution, flows);

        uint8[] memory indexFlows = new uint8[](indexFlows16.length);
        uint8[] memory indexMandates = new uint8[](indexMandates16.length);
        for(uint256 i = 0; i < indexFlows16.length; i++) {
            indexFlows[i] = uint8(indexFlows16[i]);
            indexMandates[i] = uint8(indexMandates16[i]);
        }

        // Legal Interfacers: Pause Mandates
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.votingPeriod = minutesToBlocks(2, blocksPerHour);
        conditions.succeedAt = 66;
        conditions.quorum = 30;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Pause Mandates: Legal Interfacers can pause mandates in the organization",
                targetMandate: m_PauseMandates,
                config: abi.encode(
                    indexFlows,
                    indexMandates
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // MISCELLANEOUS //
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
    }
}
