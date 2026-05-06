source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast call $TIMELOCK_ADDR "hasRole(bytes32,address)" \
  $(cast keccak "PROPOSER_ROLE") $GOVERNOR_ADDR --rpc-url sepolia

cast call $TIMELOCK_ADDR "hasRole(bytes32,address)" \
  $(cast keccak "TIMELOCK_ADMIN_ROLE") $DEPLOYER --rpc-url sepolia

cast call $GOVERNOR_ADDR "votingDelay()(uint256)" --rpc-url sepolia
cast call $GOVERNOR_ADDR "votingPeriod()(uint256)" --rpc-url sepolia
cast call $GOVERNOR_ADDR "quorumNumerator()(uint256)" --rpc-url sepolia
