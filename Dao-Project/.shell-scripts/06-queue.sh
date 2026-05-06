source .env
source .env.secret
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast send $GOVERNOR_ADDR \
  "queue(address[],uint256[],bytes[],bytes32)" \
  "[$BOX_ADDR]" "[0]" \
  "[$(cast calldata "store(uint256)" 42)]" \
  "$(cast keccak "Store 42 in Box")" \
  --rpc-url sepolia --private-key $RAW_PRIVATE_KEY

cast call $TIMELOCK_ADDR "getMinDelay()(uint256)" \
    --rpc-url sepolia
