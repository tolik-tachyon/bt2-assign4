source .env
source .env.secret
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast send $GOVERNOR_ADDR \
    "propose(address[],uint256[],bytes[],string)" \
    "[$BOX_ADDR]" "[0]" \
    "[$(cast calldata "store(uint256)" 42)]" \
    "Store 42 in Box" \
    --rpc-url sepolia \
    --private-key $RAW_PRIVATE_KEY
