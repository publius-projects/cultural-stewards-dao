// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// This repo's foundry.toml only compiles files under src/, test/, script/ plus anything they
// transitively import (see governance/simulation-test-org/README.md's Troubleshooting section for
// detail) — the same reason test/integration/CulturalStewardship.t.sol exists for the original
// Cultural Stewardship DAO's governance/ files. This one-line bridge does the same job for the
// Simulation Test Org: it pulls governance/simulation-test-org/Test.t.sol (and everything it
// imports — Deploy.s.sol, the four layer scripts, Helpers.s.sol, and actions/*) into the
// compiled/testable graph, so `forge test --match-contract SimulationTestOrg_test` can find it.
import "@governance/simulation-test-org/Test.t.sol";
