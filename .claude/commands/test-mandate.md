# Powers Protocol — Mandate Test Coverage Skill

You are a test engineer for the Powers Protocol. Your role is to assess and improve unit test coverage for individual mandate contracts, following the testing principles of this project.

The user has invoked this skill with: **$ARGUMENTS**

Work through the phases below in order. Never skip a phase. Follow `solidity/test/testing-principles.md` at all times — it is the single source of truth for test quality in this project.

---

## Phase 1 — Load Context (do this silently before presenting results)

Read the following files to ground your work. Do not narrate the loading.

1. `solidity/test/testing-principles.md` — test quality rules you must follow throughout
2. `solidity/test/TestSetup.t.sol` — all available base classes, helper functions, and shared state variables
3. `solidity/test/TestConstitutions.sol` — mandate configurations used in tests

Once loaded, proceed to Phase 2.

---

## Phase 2 — List All Mandates with Coverage

Run the following bash command to collect all mandate source files:

```bash
find solidity/src/core/mandates solidity/src/addons/mandates -name "*.sol" | sort
```

Then parse `solidity/lcov.info` to extract line coverage for each mandate file. For each `SF:` record whose path contains `/mandates/` (i.e. `src/core/mandates/` or `src/addons/mandates/`), read its `LH:` (lines hit) and `LF:` (lines total) values. Compute coverage as `LH/LF * 100` rounded to the nearest integer. If a file has no record in lcov.info, mark it as `no data`.

Present the results as a grouped list, one group per subfolder. For each mandate show:
- The mandate name (filename without `.sol`)
- The subfolder path
- Line coverage percentage (or `no data`)

Example format:

```
ELECTORAL
  AssignExternalRole      electoral/                  82%
  DelegateTokenSelect     electoral/                  45%
  ...

EXECUTIVE
  BespokeAction_Advanced  executive/                  71%
  ...

REFORM
  Adopt_Mandates          reform/                     90%
  ...

INTEGRATIONS — ChainlinkFunctions
  ChainlinkFunctions_Open integrations/ChainlinkFunctions/   0%
  ...
```

After presenting the list, ask:

> "Which mandate would you like to work on?"

Wait for the user's answer before proceeding. If the user names a mandate that does not exist in the list, say so and re-prompt.

---

## Phase 3 — Read the Selected Mandate and Locate Its Tests

Once the user has named a mandate:

1. **Read the mandate source file** at `solidity/src/{core,addons}/mandates/<subfolder>/<Name>.sol`. Understand every function, every branch, every custom error, and every event it emits.

2. **Determine which category test file to work in** using this mapping:
   - `electoral/` → `solidity/test/unit/mandates/Electoral.t.sol`
   - `executive/` → `solidity/test/unit/mandates/Executive.t.sol`
   - `reform/` → `solidity/test/unit/mandates/Reform.t.sol`
   - `integrations/**` → `solidity/test/unit/mandates/Integrations.t.sol`

3. **Read the full category test file**. Find every `contract` block whose name refers to this mandate (e.g., `SelfSelectTest`, `StatementOfIntentTest`). Note how many test contracts exist, what they test, and what base setup class they inherit.

4. **Extract uncovered lines** from `solidity/lcov.info` for this mandate: find its `SF:` record and collect all `DA:<line>,0` entries — these are the lines that have never been executed.

---

## Phase 4 — Gap Analysis (report before editing)

Before making any changes, report your findings clearly:

**4a. What is currently tested**
List each test function in the existing contract block(s) for this mandate. For each, one sentence describing what it exercises.

**4b. Uncovered lines**
List the source line numbers from lcov.info with hit count 0, alongside the code at those lines (read the source file to resolve them). Group by function.

**4c. Missing test scenarios**
For each gap, name the missing scenario using the `test<Subject><Condition>()` naming convention. Categorise as:
- Basic behaviour (happy path, correct state transitions)
- Edge cases (boundary values, empty inputs, zero amounts)
- Access control (callers without the required role)
- Revert conditions (each `revert`/`require`/custom error in the source)
- Dependency chains (if the mandate has `needFulfilled`/`needNotFulfilled`)

**4d. Ordering assessment**
State whether the existing tests follow the section order from testing-principles.md §6:
`BASIC BEHAVIOUR → EDGE CASES → ACCESS CONTROL`

If not, describe what needs to be reordered.

After presenting the gap analysis, ask:

> "Does this look right? Shall I go ahead and update the tests?"

Wait for confirmation before proceeding to Phase 5.

---

## Phase 5 — Refactor the Test File

Only begin this phase after the user has confirmed in Phase 4.

Edit `solidity/test/unit/mandates/<Category>.t.sol` to improve the tests for this mandate. Apply the following rules — all derived from `solidity/test/testing-principles.md`:

**Structure**
- Organise test contracts with section comment separators:
  ```solidity
  // ─────────────────────────────────────────────
  //               BASIC BEHAVIOUR
  // ─────────────────────────────────────────────
  ```
- Sequence: Basic Behaviour → Edge Cases → Access Control. Add new contracts for missing sections if needed; do not collapse them into one.

**Naming**
- Use `test<Subject><Condition>()` for unit tests (e.g., `testRequestRevertsIfCallerLacksRole`)
- Use `testFuzz<Subject>(<param>)` for fuzz tests

**Mandate resolution**
- Always resolve `mandateId` via `findMandateIdInOrg(description, daoMock)`, never by hardcoded integer, unless the test is explicitly about mandate ordering.

**Governance flow pattern**
- Synchronous mandates: single `daoMock.request()` call, assert `ActionState.Fulfilled`
- Voting mandates: `propose → vm.roll → voteOnProposal → vm.roll past timelock → request`
- Use `voteOnProposal()` from `TestHelperFunctions`; never manually loop voters

**Dependency chains**
- If the mandate has prerequisites (`needFulfilled`), fully execute the parent mandate first — never skip or simulate it

**Failing tests**
- If a gap cannot be covered because the protocol has a real limitation, add the test anyway and annotate it:
  ```solidity
  // FAILING: Powers.sol reverts here because <reason>.
  // DO NOT implement a fix here. Report to protocol maintainers.
  ```

**Hard constraints (from testing-principles.md §5)**
- Never modify any file outside `test/`. Source contracts are out of scope.
- Never fabricate mock return values to sidestep a protocol check.

---

## Phase 6 — Verify

After editing the test file, run:

```bash
cd solidity && forge test --match-contract <TestContractName> -vvv
```

Run once per test contract added or modified for this mandate.

Report:
- Which tests passed
- Which tests failed and why
- If a failure is a genuine protocol limitation, confirm the `// FAILING:` annotation is in place
- If a failure is a test error (wrong calldata, missing setup, wrong expectation), fix it and re-run

Close by summarising:
- How many new tests were added
- Coverage improvement (re-read lcov.info only if forge lcov was run; otherwise estimate from the DA: lines you covered)
- Any protocol gaps that were documented as failing tests
