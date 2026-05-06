source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast call $TOKEN_ADDR "getVotes(address)(uint256)" $DEPLOYER --rpc-url sepolia
