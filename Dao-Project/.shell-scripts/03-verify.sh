source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

forge verify-contract $TOKEN_ADDR GovernanceToken --chain sepolia --etherscan-api-key $ETHERSCAN_KEY
forge verify-contract $GOVERNOR_ADDR MyGovernor --chain sepolia --etherscan-api-key $ETHERSCAN_KEY
forge verify-contract $TIMELOCK_ADDR TimelockController --chain sepolia --etherscan-api-key $ETHERSCAN_KEY
forge verify-contract $TREASURY_ADDR Treasury --chain sepolia --etherscan-api-key $ETHERSCAN_KEY
forge verify-contract $BOX_ADDR Box --chain sepolia --etherscan-api-key $ETHERSCAN_KEY

cast call $TOKEN_ADDR "balanceOf(address)(uint256)" $DEPLOYER --rpc-url sepolia
cast call $TOKEN_ADDR "getVotes(address)(uint256)" $DEPLOYER --rpc-url sepolia
