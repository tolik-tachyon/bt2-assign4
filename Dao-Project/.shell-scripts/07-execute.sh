source .env
source .env.secret
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast send $GOVERNOR_ADDR \
  "execute(address[],uint256[],bytes[],bytes32)" \
  "[$BOX_ADDR]" "[0]" \
  "[$(cast calldata "store(uint256)" 42)]" \
  "$(cast keccak "Store 42 in Box")" \
  --rpc-url sepolia --private-key $RAW_PRIVATE_KEY

cast call $BOX_ADDR "retrieve()(uint256)" --rpc-url sepolia

cast send $GOVERNOR_ADDR \
  "propose(address[],uint256[],bytes[],string)" \
  "[$TREASURY_ADDR]" "[0]" \
  "[$(cast calldata "withdrawETH(address,uint256)" $DEPLOYER 1000000000000000)]" \
  "Withdraw 0.001 ETH from Treasury" \
  --rpc-url sepolia --private-key $RAW_PRIVATE_KEY

cast send $TREASURY_ADDR --value "0.01ether" \
  --rpc-url sepolia --private-key $RAW_PRIVATE_KEY
