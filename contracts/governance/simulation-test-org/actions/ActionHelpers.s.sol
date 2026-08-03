// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";

import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { IMandate } from "@src/interfaces/IMandate.sol";
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";

/// @notice Shared helper functions for the Simulation Test Org action/runner scripts.
/// Adapted unchanged from the Cultural Stewardship DAO's governance/actions/ActionHelpers.s.sol —
/// this file has no token or ZKPassport content, so no structural changes were needed.
contract ActionHelpers is Script {
    Configurations helperConfig = new Configurations();

    // mandate ID cache: org => descriptionHash => mandateId (0 = not found/slot unused)
    mapping(address => mapping(bytes32 => uint16)) internal _mandateCache;
    mapping(address => bool) private _mandateCacheLoaded;
    mapping(address => uint16) internal _mandateCounterCache;
    // role holder key cache: keccak256(powers, roleId, index) => privateKey
    mapping(bytes32 => uint256) private _roleHolderKeyCache;

    //////////////////////////////////////////////////////////////////////////////////
    //                             Helper Functions                                 //
    //////////////////////////////////////////////////////////////////////////////////

    function _loadMandateCache(Powers org) internal {
        if (_mandateCacheLoaded[address(org)]) return;
        uint16 counter = org.mandateCounter();
        _mandateCounterCache[address(org)] = counter;
        for (uint16 i = 1; i < counter; i++) {
            (address mandateAddress, , ) = org.getAdoptedMandate(i);
            string memory mandateDesc = IMandate(mandateAddress).getNameDescription(address(org), i);
            _mandateCache[address(org)][keccak256(abi.encodePacked(mandateDesc))] = i;
        }
        _mandateCacheLoaded[address(org)] = true;
    }

    // NB: the name + description needs to exactly match the name + description of the mandate in order to find the correct mandate ID.
    function findMandateIdInOrg(string memory description, Powers org) public returns (uint16) {
        _loadMandateCache(org);
        uint16 id = _mandateCache[address(org)][keccak256(abi.encodePacked(description))];
        if (id == 0) revert(string.concat("Mandate not found: ", description));
        return id;
    }

    function calculateActionId(uint16 mandateId, bytes memory mandateCalldata, uint256 nonce) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(mandateId, mandateCalldata, nonce)));
    }

    function getPrivateKeyRoleHolder(address powers, uint256 roleId, uint256 index, uint256[] memory privateKeys) public returns (uint256) {
        bytes32 cacheKey = keccak256(abi.encode(powers, roleId, index));
        if (_roleHolderKeyCache[cacheKey] != 0) return _roleHolderKeyCache[cacheKey];
        address roleHolder = Powers(payable(powers)).getRoleHolderAtIndex(roleId, index);
        for (uint256 i = 0; i < privateKeys.length; i++) {
            if (vm.addr(privateKeys[i]) == roleHolder) {
                _roleHolderKeyCache[cacheKey] = privateKeys[i];
                return privateKeys[i];
            }
        }
        revert("The selected role does not match any of the provided private keys");
    }

    function voteOnProposal(
        address organisation,
        uint16 mandateToVoteOn,
        uint256 actionIdLocal,
        uint256[] memory privateKeys,
        uint256 randomiser,
        uint256 passChance // in percentage
    )
        public
        returns (uint256 roleCountLocal, uint256 againstVoteLocal, uint256 forVoteLocal, uint256 abstainVoteLocal)
    {
        uint256 currentRandomiser;
        for (uint256 i = 0; i < privateKeys.length; i++) {
            if (currentRandomiser < 10) {
                currentRandomiser = randomiser;
            } else {
                currentRandomiser = currentRandomiser / 10;
            }
            address voter = vm.addr(privateKeys[i]);
            console2.log("Voter: ", voter);
            if (Powers(payable(organisation)).canCallMandate(voter, mandateToVoteOn)) {
                roleCountLocal++;
                if (currentRandomiser % 100 >= passChance) {
                    vm.startBroadcast(privateKeys[i]);
                    Powers(payable(organisation)).castVote(actionIdLocal, 0); // = against
                    vm.stopBroadcast();
                    againstVoteLocal++;
                } else if (currentRandomiser % 100 < passChance) {
                    vm.startBroadcast(privateKeys[i]);
                    Powers(payable(organisation)).castVote(actionIdLocal, 1); // = for
                    vm.stopBroadcast();
                    forVoteLocal++;
                } else {
                    vm.startBroadcast(privateKeys[i]);
                    Powers(payable(organisation)).castVote(actionIdLocal, 2); // = abstain
                    vm.stopBroadcast();
                    abstainVoteLocal++;
                }
            }
        }
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                         Election Helper Functions                            //
    //////////////////////////////////////////////////////////////////////////////////
    // These functions are split at time-dependent points in the election flow.
    // Phase 1: createElectionAndNominate() - creates election and nominates candidates
    // ⏳ TIME BREAK - wait for nomination period to end (startBlock)
    // Phase 2: openVotingAndCastVotes() - opens voting and casts votes
    // ⏳ TIME BREAK - wait for voting period to end (endBlock)
    // Phase 3: tallyElection() + cleanupElection() - tallies results and cleans up

    function createElectionAndNominate(
        address organisation,
        uint16 createElectionMandateId,
        uint16 nominateMandateId,
        string memory electionTitle,
        uint256[] memory nomineePrivateKeys,
        uint256 nonce
    ) public returns (uint256 electionId) {
        electionId = uint256(keccak256(abi.encodePacked(organisation, electionTitle)));

        bytes memory createCalldata = abi.encode(electionTitle);

        console2.log("Creating election:", electionTitle);
        vm.startBroadcast(nomineePrivateKeys[0]);
        Powers(payable(organisation)).request(createElectionMandateId, createCalldata, nonce, "");
        vm.stopBroadcast();

        for (uint256 i = 0; i < nomineePrivateKeys.length; i++) {
            address nominee = vm.addr(nomineePrivateKeys[i]);
            bytes memory nominateCalldata = abi.encode(electionTitle);
            nonce = nonce + i;

            console2.log("Nominating:", nominee);
            vm.startBroadcast(nomineePrivateKeys[i]);
            Powers(payable(organisation)).request(nominateMandateId, nominateCalldata, nonce + i, "");
            vm.stopBroadcast();
        }

        return electionId;
    }

    function openVotingAndCastVotes(
        address organisation,
        address electionRegistry,
        uint16 openVoteMandateId,
        uint256 electionId,
        string memory electionTitle,
        uint256[] memory voterPrivateKeys,
        bool[][] memory voteSelections,
        uint256 nonce
    ) public returns (uint16 voteMandateId) {
        require(voterPrivateKeys.length == voteSelections.length, "Voter count must match vote selections count");

        bytes memory openVoteCalldata = abi.encode(electionTitle);

        voteMandateId = Powers(payable(organisation)).mandateCounter();

        console2.log("Opening election voting for:", electionTitle);
        console2.log("Vote mandate will be ID:", voteMandateId);

        vm.startBroadcast(voterPrivateKeys[0]);
        Powers(payable(organisation)).request(openVoteMandateId, openVoteCalldata, nonce, "");
        vm.stopBroadcast();

        address[] memory nominees = ElectionRegistry(electionRegistry).getNominees(electionId);

        for (uint256 i = 0; i < voterPrivateKeys.length; i++) {
            address voter = vm.addr(voterPrivateKeys[i]);

            if (!Powers(payable(organisation)).canCallMandate(voter, voteMandateId)) {
                console2.log("Voter cannot call mandate, skipping:", voter);
                continue;
            }

            if (ElectionRegistry(electionRegistry).hasUserVoted(voter, electionId)) {
                console2.log("Voter already voted, skipping:", voter);
                continue;
            }

            require(voteSelections[i].length == nominees.length, "Vote selection length must match nominee count");

            bytes memory voteCalldata = new bytes(nominees.length * 32);
            for (uint256 j = 0; j < nominees.length; j++) {
                bytes32 boolValue = voteSelections[i][j] ? bytes32(uint256(1)) : bytes32(uint256(0));
                for (uint256 k = 0; k < 32; k++) {
                    voteCalldata[j * 32 + k] = boolValue[k];
                }
            }

            console2.log("Voter casting vote:", voter);
            vm.startBroadcast(voterPrivateKeys[i]);
            Powers(payable(organisation)).request(voteMandateId, voteCalldata, nonce + i, "");
            vm.stopBroadcast();
        }

        return voteMandateId;
    }

    /// @dev All Tally/CleanUp mandates in this org require role 1 (Participants/Writers) — see
    /// PrimaryLayer.s.sol / IdeasLayer.s.sol / DigitalLayer.s.sol's election flows.
    function tallyElection(
        address organisation,
        uint16 tallyMandateId,
        uint16 cleanupMandateId,
        uint256[] memory privateKeys,
        string memory electionTitle,
        uint256 nonce
    ) public {
        uint256 privateKeyVoter = getPrivateKeyRoleHolder(organisation, 1, 0, privateKeys);

        console2.log("Tallying election:", electionTitle);
        vm.startBroadcast(privateKeyVoter);
        Powers(payable(organisation)).request(tallyMandateId, abi.encode(electionTitle), nonce, "");
        vm.stopBroadcast();

        console2.log("Cleaning up election:", electionTitle);
        vm.startBroadcast(privateKeyVoter);
        Powers(payable(organisation)).request(cleanupMandateId, abi.encode(electionTitle), nonce, "");
        vm.stopBroadcast();
    }
}
