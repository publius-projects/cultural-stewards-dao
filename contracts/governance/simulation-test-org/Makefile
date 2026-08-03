-include ../../.env
-include .env.local

SCRIPT = governance/simulation-test-org/Deploy.s.sol:Deploy
TEST   = SimulationTestOrg_test

# Wallet — set DEPLOYER_ACCOUNT and DEPLOYER_ADDRESS in .env.local
# (copy .env.example to .env.local and follow the instructions inside)

ANVIL_DEPLOY_ARGS       := --rpc-url http://localhost:8545 \
                            --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
                            --broadcast --ffi -vv

SEPOLIA_DEPLOY_ARGS     := --rpc-url $(SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast -vv

ARB_SEPOLIA_DEPLOY_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) \
                            --verifier etherscan --chain 421614 --verify --ffi -vv

OPT_SEPOLIA_DEPLOY_ARGS := --rpc-url $(OPT_SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) \
                            --chain 11155420 --ffi -vv

.PHONY: help deploy-anvil deploy-sepolia deploy-arb-sepolia deploy-opt-sepolia test setup-wallet check-wallet initialise-runner

help:
	@echo "Available targets:"
	@echo "  deploy-anvil        Deploy to local Anvil (no wallet setup needed)"
	@echo "  deploy-sepolia      Deploy to Ethereum Sepolia"
	@echo "  deploy-arb-sepolia  Deploy to Arbitrum Sepolia"
	@echo "  deploy-opt-sepolia  Deploy to Optimism Sepolia"
	@echo "  test                Run tests (needs SEPOLIA_RPC_URL — no private keys required)"
	@echo "  initialise-runner   Print the command to seed the Yin/Yang Ideas Layers post-deploy"
	@echo "  setup-wallet        Print wallet setup instructions"
	@echo "  check-wallet        Verify wallet variables are configured"

setup-wallet:
	@echo ""
	@echo "=== Wallet setup for live network deployments ==="
	@echo ""
	@echo "1. Create an encrypted keystore (you will be prompted for a password):"
	@echo "      cast wallet import my-wallet --interactive"
	@echo ""
	@echo "2. Get the Ethereum address of that keystore:"
	@echo "      cast wallet address --account my-wallet"
	@echo ""
	@echo "3. Copy .env.example to .env.local and fill in the values:"
	@echo "      cp .env.example .env.local"
	@echo "      # then edit .env.local"
	@echo ""
	@echo "4. Fund the deployer address on the target network with ETH for gas"
	@echo "   (plus at least the PowersPaymaster seed amount — see README.md)."
	@echo ""

check-wallet:
	@test -n "$(DEPLOYER_ACCOUNT)" || (echo "ERROR: DEPLOYER_ACCOUNT is not set. Run 'make setup-wallet' for instructions."; exit 1)
	@test -n "$(DEPLOYER_ADDRESS)" || (echo "ERROR: DEPLOYER_ADDRESS is not set. Run 'make setup-wallet' for instructions."; exit 1)
	@echo "Wallet OK: $(DEPLOYER_ADDRESS)  (keystore: $(DEPLOYER_ACCOUNT))"

deploy-anvil:
	cd ../.. && forge script $(SCRIPT) $(ANVIL_DEPLOY_ARGS)

deploy-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(SEPOLIA_DEPLOY_ARGS)

deploy-arb-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(ARB_SEPOLIA_DEPLOY_ARGS)

deploy-opt-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(OPT_SEPOLIA_DEPLOY_ARGS)

test:
	cd ../.. && forge test --match-contract $(TEST) -vvv

initialise-runner:
	@echo "Seed the two demo Ideas Layers ('Yin' and 'Yang') after deploying:"
	@echo ""
	@echo "  forge script governance/simulation-test-org/actions/InitialiseRunner.s.sol:InitialiseRunner \\"
	@echo "    --sig \"run(address,address,uint256,string[],uint256[])\" \\"
	@echo "    <primaryLayer> <digitalLayer> 1 '[\"Yin\",\"Yang\"]' '[]' \\"
	@echo "    --rpc-url \$$SEPOLIA_RPC_URL --account $(DEPLOYER_ACCOUNT) --broadcast"
	@echo ""
	@echo "Run it again after each voting window closes (2 minutes) until it logs 'seeding complete'."
