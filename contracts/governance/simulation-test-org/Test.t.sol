// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Run with: forge test --match-contract SimulationTestOrg_test -vvv

import { Test, console2 } from "forge-std/Test.sol";
import { Powers } from "@lib/powers-monorepo/solidity/src/Powers.sol";
import { IPowers } from "@lib/powers-monorepo/solidity/src/interfaces/IPowers.sol";
import { Configurations } from "@lib/powers-monorepo/solidity/script/Configurations.s.sol";

import { IMandate } from "@lib/powers-monorepo/solidity/src/interfaces/IMandate.sol";
import { MandateRegistry } from "@lib/powers-monorepo/solidity/src/core/helpers/MandateRegistry.sol";
import { Adopt_Mandates } from "@lib/powers-monorepo/solidity/src/core/mandates/reform/Adopt_Mandates.sol";
import { PowersTypes } from "@lib/powers-monorepo/solidity/src/interfaces/PowersTypes.sol";
import { Deploy } from "./Deploy.s.sol";
import { Initialise } from "./actions/Initialise.s.sol";
import { InitialiseRunner } from "./actions/InitialiseRunner.s.sol";

/// @notice Fork-based integration test for the Simulation Test Org. Follows the design-org
/// skill's canonical Test.t.sol structure (inherits forge-std/Test.sol directly — NOT
/// TestHelperFunctions/TestSetup.t.sol, which breaks at this folder's nesting depth).
///
/// Covers the live-demo happy path: seed "Yin"/"Yang" -> Marc joins Yin as Participant ->
/// Yin proposes a Convergence Layer ("Basel Art Exhibition") -> the auto-assigned Legal
/// Interfacer (hannah, from DeploySetup.s.sol) immediately requests an allowance -- plus one
/// negative test showing an application is blocked without Assessor approval.
contract SimulationTestOrg_test is Test {
    Configurations helperConfig;
    Deploy deploy;
    InitialiseRunner runner;

    address primaryLayer;
    address digitalLayer;
    address ideasLayerFactory;
    address convergenceLayerFactory;

    // Demo Timing Policy (Spec.md), expressed in Sepolia blocks (300 blocks/hour = 5 blocks/min).
    uint256 constant VOTING_PERIOD_BLOCKS = 10; // 2 minutes
    uint256 constant TIMELOCK_BLOCKS = 5;       // 1 minute
    uint256 constant BUFFER_BLOCKS = 3;         // safety margin against off-by-one boundaries

    // Synthetic private key constants — TEST_ACCOUNT_KEY_1/2/3 are re-pointed at these via
    // vm.setEnv() before any DeploySetup-derived contract reads them, so `testAccount1`/`2`/`3`
    // (used throughout the deploy scripts' setup mandates) resolve to addresses this test
    // controls. `hannah`/`cedars` remain the real hardcoded addresses from DeploySetup.s.sol —
    // this test uses vm.prank/vm.startPrank for those two, since their private keys are not
    // (and must never be) available to this test suite.
    uint256 constant TEST_KEY_1 = 101;
    uint256 constant TEST_KEY_2 = 102;
    uint256 constant TEST_KEY_3 = 103;
    uint256 constant MARC_KEY = 201;

    address testAccount1;
    address testAccount2;
    address marc;

    uint256[] privateKeys; // [TEST_KEY_1, TEST_KEY_2] — used by the action/runner scripts.

    address constant HANNAH = 0xc9ce1DC547C42F66464f5a7f0E3cd60EBf1C5Bd2;
    address constant CEDARS = 0x95e51Ce331e9F81917d729C5b1F9127ca1138a01;

    string[] ideasLayerNames;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        vm.selectFork(fork);
        helperConfig = new Configurations();

        // Point TEST_ACCOUNT_KEY_1/2/3 at synthetic keys before any contract reads them.
        vm.setEnv("TEST_ACCOUNT_KEY_1", vm.toString(TEST_KEY_1));
        vm.setEnv("TEST_ACCOUNT_KEY_2", vm.toString(TEST_KEY_2));
        vm.setEnv("TEST_ACCOUNT_KEY_3", vm.toString(TEST_KEY_3));

        testAccount1 = vm.addr(TEST_KEY_1);
        testAccount2 = vm.addr(TEST_KEY_2);
        marc = vm.addr(MARC_KEY);

        privateKeys = new uint256[](2);
        privateKeys[0] = TEST_KEY_1;
        privateKeys[1] = TEST_KEY_2;

        vm.deal(testAccount1, 10 ether);
        vm.deal(testAccount2, 10 ether);
        vm.deal(marc, 10 ether);
        vm.deal(HANNAH, 10 ether);
        vm.deal(CEDARS, 10 ether);
        vm.deal(address(this), 1 ether); // covers paymaster seeding

        _ensureAdoptMandatesV2Registered();

        deploy = new Deploy();
        vm.deal(address(deploy), 1 ether);
        (primaryLayer, digitalLayer, ideasLayerFactory, convergenceLayerFactory) = deploy.run();

        runner = new InitialiseRunner();

        ideasLayerNames = new string[](2);
        ideasLayerNames[0] = "Yin";
        ideasLayerNames[1] = "Yang";

        // Phase 0+1: run Primary/Digital setup mandates, propose Yin/Yang initiation.
        runner.run(primaryLayer, digitalLayer, 1, ideasLayerNames, privateKeys);
        // Phase 2: execute initiation, propose creation.
        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);
        runner.run(primaryLayer, digitalLayer, 1, ideasLayerNames, privateKeys);
        // Phase 3: execute creation — Yin and Yang now hold role 4 at the Primary Layer.
        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);
        runner.run(primaryLayer, digitalLayer, 1, ideasLayerNames, privateKeys);

        assertEq(IPowers(primaryLayer).getAmountRoleHolders(4), 2, "Yin and Yang should both be deployed");
    }

    /// @notice Makes Adopt_Mandates v0.2.0 available on the fork if it is not already registered
    /// on the live MandateRegistry.
    /// @dev This org's reform flows are wired to v0.2.0, which takes a full MandateInitData[] and
    /// so can adopt configured, voted mandates. v0.1.9 — the version registered when this refactor
    /// was written — forced every adoption to an empty config and zeroed conditions. Registering
    /// here (fork-local, pranking the registry owner) lets the suite exercise the reform flow
    /// before the real registration transaction has been broadcast. Once v0.2.0 is registered on
    /// the live registry this becomes a no-op, so the helper is correct either way.
    function _ensureAdoptMandatesV2Registered() internal {
        MandateRegistry reg = MandateRegistry(helperConfig.getMandateRegistry(block.chainid));
        if (reg.isVersionActive(0, 2, 0, "Adopt_Mandates")) return;

        Adopt_Mandates adoptV2 = new Adopt_Mandates(address(reg));
        vm.prank(reg.owner());
        reg.registerMandate("Adopt_Mandates", address(adoptV2), keccak256(type(Adopt_Mandates).creationCode));
    }

    function _yin() internal view returns (address) {
        return IPowers(primaryLayer).getRoleHolderAtIndex(4, 0);
    }

    //////////////////////////////////////////////////////////////////////
    //                    HAPPY PATH: JOIN IDEAS LAYER                  //
    //////////////////////////////////////////////////////////////////////

    /// @notice Marc applies to Yin as a Participant and an Assessor (testAccount1, assigned via
    /// Yin's own setup mandate) approves — the "apply -> approve" pattern used throughout this
    /// org wherever membership isn't automatic (Spec.md's "Claim Participant/Attendee Role").
    function test_MarcJoinsIdeasLayer_HappyPath() public {
        address yin = _yin();

        // Yin's own "Initial Setup" mandate must run once before its roles are usable.
        Initialise initialise = new Initialise();
        initialise.runSetupMandate(yin, 1, privateKeys);
        assertTrue(IPowers(yin).hasRoleSince(testAccount1, 3) > 0, "testAccount1 should hold Assessor role at Yin");

        uint16 applyMandateId = _findMandate(yin, "Apply for Participant role: Anyone can apply for a Participant role to the Ideas Layer by submitting an application.");
        uint16 assignMandateId = _findMandate(yin, "Assess and Assign Participant: Assessors can assess applications and assign a Participant role to applicants.");

        bytes memory callData = abi.encode(marc, "Marc wants to join Yin");

        vm.prank(marc);
        IPowers(yin).request(applyMandateId, callData, 1, "Marc applies for Participant role");

        vm.prank(testAccount1);
        IPowers(yin).request(assignMandateId, callData, 1, "Assessor approves Marc's application");

        assertTrue(IPowers(yin).hasRoleSince(marc, 1) > 0, "Marc should hold the Participant role at Yin");
    }

    /// @notice Negative test: Marc applies, but no Assessor approval is ever submitted — Marc
    /// must NOT hold the Participant role (the needFulfilled gate has nothing to fulfil it).
    function test_MarcApplication_BlockedWithoutApproval() public {
        address yin = _yin();
        Initialise initialise = new Initialise();
        initialise.runSetupMandate(yin, 1, privateKeys);

        uint16 applyMandateId = _findMandate(yin, "Apply for Participant role: Anyone can apply for a Participant role to the Ideas Layer by submitting an application.");

        vm.prank(marc);
        IPowers(yin).request(applyMandateId, abi.encode(marc, "Marc wants to join Yin"), 1, "Marc applies for Participant role");

        assertEq(IPowers(yin).hasRoleSince(marc, 1), 0, "Marc must not hold the Participant role without Assessor approval");
    }

    //////////////////////////////////////////////////////////////////////
    //          HAPPY PATH: CREATE CONVERGENCE LAYER + REQUEST FUNDS     //
    //////////////////////////////////////////////////////////////////////

    /// @notice Full "Basel Art Exhibition" Convergence Layer creation from Yin, then verifies the
    /// auto-assigned Legal Interfacer (hannah) can immediately call "Request allowance" — no
    /// live nomination step required, per Spec.md's "Demo Setup — Pre-Seeded State".
    function test_CreateConvergenceLayer_AndLegalInterfacerRequestsFunds() public {
        address yin = _yin();
        Initialise initialise = new Initialise();
        initialise.runSetupMandate(yin, 1, privateKeys);

        string memory layerName = "Basel Art Exhibition";

        // Phase 4: Yin Participants propose a new Convergence Layer.
        initialise.deployConvergenceLayer1(yin, layerName, 1, privateKeys);
        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);

        // Phase 5: execute the request + Stewards propose sending it to the Primary Layer.
        initialise.deployConvergenceLayer2(yin, layerName, 1, privateKeys);
        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);

        // Phase 6: send the request — Primary Layer creates the Convergence Layer.
        // NB: creation only deploys and constitutes the new Powers instance. Granting it role 3
        // at the Primary Layer is a separate, timelocked governance step (phases 7-8), so the
        // role-holder count is asserted after phase 8, not here.
        initialise.deployConvergenceLayer3(yin, layerName, 1, privateKeys);

        // Phase 7: Primary Stewards propose the role/delegate/paymaster assignments (timelocked).
        initialise.deployConvergenceLayer4(primaryLayer, layerName, 1, privateKeys);
        vm.roll(block.number + TIMELOCK_BLOCKS + BUFFER_BLOCKS);

        // Phase 8: execute the assignments — the Convergence Layer is fully wired up.
        initialise.deployConvergenceLayer5(primaryLayer, layerName, 1, privateKeys);

        assertEq(IPowers(primaryLayer).getAmountRoleHolders(3), 1, "One Convergence Layer should be registered at the Primary Layer");

        address convergenceLayer = IPowers(primaryLayer).getRoleHolderAtIndex(3, 0);
        assertTrue(convergenceLayer != address(0), "Convergence Layer should be deployed");

        // The Convergence Layer's own setup mandate auto-assigns hannah as Legal Interfacer
        // (role 3) — see ConvergenceLayer.s.sol's setup PresetActions calldata.
        assertTrue(IPowers(convergenceLayer).hasRoleSince(HANNAH, 3) > 0, "hannah should be auto-assigned Legal Interfacer at creation");

        // hannah immediately requests an allowance from the Primary Layer — no extra clicks.
        uint16 requestAllowanceId = _findMandate(convergenceLayer, "Request allowance: Legal Interfacer can request an allowance from the Primary Layer Safe Treasury.");
        bytes memory allowanceCallData = abi.encode(convergenceLayer, address(0), uint96(1 ether), uint16(0), uint32(0));

        vm.prank(HANNAH);
        uint256 actionId = IPowers(convergenceLayer).propose(requestAllowanceId, allowanceCallData, 1, "hannah requests an allowance for Basel Art Exhibition");

        // Powers measures succeedAt against the *role-holder count*, not against votes cast
        // (Powers.sol `_voteSucceeded`: amountMembers * succeedAt <= forVotes * DENOMINATOR).
        // Role 3 at a Convergence Layer has two holders — testAccount1 from the base setup and
        // hannah from the demo auto-assignment — so at succeedAt = 66 both must vote FOR.
        vm.prank(HANNAH);
        IPowers(convergenceLayer).castVote(actionId, 1); // for

        vm.prank(testAccount1);
        IPowers(convergenceLayer).castVote(actionId, 1); // for

        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);

        vm.prank(HANNAH);
        IPowers(convergenceLayer).request(requestAllowanceId, allowanceCallData, 1, "hannah requests an allowance for Basel Art Exhibition");

        // Reaching this line without revert demonstrates the auto-assigned Legal Interfacer could
        // immediately propose, vote, and execute a funds request with no prior setup step.
    }

    //////////////////////////////////////////////////////////////////////
    //                      REFORM FLOW (Adopt_Mandates v0.2.0)          //
    //////////////////////////////////////////////////////////////////////

    /// @notice Yin's Stewards adopt a brand-new, fully configured mandate through the reform flow.
    /// @dev This is the capability that Adopt_Mandates v0.1.9 could not provide: it forced every
    /// adoption to an empty config, zeroed conditions and the fixed name "Reform mandate". The
    /// assertions below deliberately check the *config* and *conditions* of the adopted mandate,
    /// not merely that the counter went up — under v0.1.9 the count would rise but the payload
    /// would be discarded.
    function test_ReformFlow_AdoptsConfiguredMandate() public {
        address yin = _yin();
        Initialise initialise = new Initialise();
        initialise.runSetupMandate(yin, 1, privateKeys);

        uint16 adoptMandateId = _findMandate(yin, "Adopt new Mandates: Stewards can adopt new mandates into the organization");
        uint16 countBefore = Powers(payable(yin)).mandateCounter();

        // The mandate to be adopted: a Participants-only proposal step with a real config and
        // real voting conditions.
        string[] memory newParams = new string[](1);
        newParams[0] = "string Proposal";

        PowersTypes.MandateInitData[] memory payload = new PowersTypes.MandateInitData[](1);
        payload[0] = PowersTypes.MandateInitData({
            nameDescription: "Reform Test: A configured mandate adopted through governance.",
            targetMandate: MandateRegistry(helperConfig.getMandateRegistry(block.chainid))
                .getMandateAddress(0, 1, 9, "StatementOfIntent"),
            config: abi.encode(newParams),
            conditions: PowersTypes.Conditions({
                allowedRole: 1,
                votingPeriod: uint32(VOTING_PERIOD_BLOCKS),
                timelock: 0,
                throttleExecution: 0,
                needFulfilled: 0,
                needNotFulfilled: 0,
                quorum: 30,
                succeedAt: 51,
                maxExecutionDelay: uint32(VOTING_PERIOD_BLOCKS)
            })
        });
        bytes memory reformCallData = abi.encode(payload);

        // Stewards propose and carry the vote. Role 2 at Yin holds only testAccount1 at this
        // point (cedars/hannah are added by the separate "Second Setup" mandate), so one FOR vote
        // clears both the 30% quorum and the 66% threshold.
        vm.prank(testAccount1);
        uint256 actionId = IPowers(yin).propose(adoptMandateId, reformCallData, 1, "Adopting a configured mandate via reform");

        vm.prank(testAccount1);
        IPowers(yin).castVote(actionId, 1); // for

        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);

        // No Participant veto was cast, so needNotFulfilled is satisfied.
        vm.prank(testAccount1);
        IPowers(yin).request(adoptMandateId, reformCallData, 1, "Adopting a configured mandate via reform");

        assertEq(Powers(payable(yin)).mandateCounter(), countBefore + 1, "one new mandate should have been adopted");

        // The adopted mandate kept its name, its config and its conditions.
        uint16 adopted = _findMandate(yin, "Reform Test: A configured mandate adopted through governance.");
        PowersTypes.Conditions memory adoptedConditions = Powers(payable(yin)).getConditions(adopted);
        assertEq(adoptedConditions.allowedRole, 1, "adopted mandate should be gated to Participants");
        assertEq(adoptedConditions.quorum, 30, "adopted mandate should keep its quorum");
        assertEq(adoptedConditions.succeedAt, 51, "adopted mandate should keep its succeedAt threshold");
        assertEq(adoptedConditions.votingPeriod, uint32(VOTING_PERIOD_BLOCKS), "adopted mandate should keep its voting period");
    }

    /// @notice A Participant veto blocks the adoption entirely.
    function test_ReformFlow_BlockedByParticipantVeto() public {
        address yin = _yin();
        Initialise initialise = new Initialise();
        initialise.runSetupMandate(yin, 1, privateKeys);

        uint16 vetoMandateId = _findMandate(yin, "Veto Adopting Mandates: Participants can veto proposals to adopt new mandates");
        uint16 adoptMandateId = _findMandate(yin, "Adopt new Mandates: Stewards can adopt new mandates into the organization");

        PowersTypes.MandateInitData[] memory payload = new PowersTypes.MandateInitData[](1);
        payload[0] = PowersTypes.MandateInitData({
            nameDescription: "Reform Test: A mandate that should never be adopted.",
            targetMandate: MandateRegistry(helperConfig.getMandateRegistry(block.chainid))
                .getMandateAddress(0, 1, 9, "StatementOfIntent"),
            config: abi.encode(new string[](0)),
            conditions: PowersTypes.Conditions({
                allowedRole: 1, votingPeriod: 0, timelock: 0, throttleExecution: 0,
                needFulfilled: 0, needNotFulfilled: 0, quorum: 0, succeedAt: 0, maxExecutionDelay: 0
            })
        });
        bytes memory reformCallData = abi.encode(payload);

        // Participants veto first. Role 1 at Yin holds testAccount1 and testAccount2, so both
        // must vote FOR to clear the 66% threshold (measured against role-holder count).
        vm.prank(testAccount1);
        uint256 vetoActionId = IPowers(yin).propose(vetoMandateId, reformCallData, 1, "Participants veto the adoption");
        vm.prank(testAccount1);
        IPowers(yin).castVote(vetoActionId, 1);
        vm.prank(testAccount2);
        IPowers(yin).castVote(vetoActionId, 1);

        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);

        vm.prank(testAccount1);
        IPowers(yin).request(vetoMandateId, reformCallData, 1, "Participants veto the adoption");

        // Stewards now try to adopt the same payload — needNotFulfilled must block it.
        uint16 countBefore = Powers(payable(yin)).mandateCounter();

        vm.prank(testAccount1);
        uint256 actionId = IPowers(yin).propose(adoptMandateId, reformCallData, 1, "Stewards attempt the vetoed adoption");
        vm.prank(testAccount1);
        IPowers(yin).castVote(actionId, 1);

        vm.roll(block.number + VOTING_PERIOD_BLOCKS + BUFFER_BLOCKS);

        vm.prank(testAccount1);
        vm.expectRevert();
        IPowers(yin).request(adoptMandateId, reformCallData, 1, "Stewards attempt the vetoed adoption");

        assertEq(Powers(payable(yin)).mandateCounter(), countBefore, "no mandate should have been adopted after a veto");
    }

    //////////////////////////////////////////////////////////////////////
    //                              HELPERS                              //
    //////////////////////////////////////////////////////////////////////

    function _findMandate(address org, string memory description) internal view returns (uint16) {
        uint16 counter = Powers(payable(org)).mandateCounter();
        for (uint16 i = 1; i < counter; i++) {
            (address mandateAddress, , ) = Powers(payable(org)).getAdoptedMandate(i);
            if (mandateAddress == address(0)) continue;
            string memory desc = IMandate(mandateAddress).getNameDescription(org, i);
            if (keccak256(bytes(desc)) == keccak256(bytes(description))) {
                return i;
            }
        }
        revert(string.concat("Mandate not found: ", description));
    }

    function minutesToBlocks(uint256 minutes_, uint256 blocksPerHour) internal pure returns (uint32) {
        return uint32((minutes_ * blocksPerHour) / 60);
    }
}
