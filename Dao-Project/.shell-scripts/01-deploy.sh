source .env.secret
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

forge script script/Deploy.s.sol \
    --broadcast --rpc-url sepolia \
    --private-key $RAW_PRIVATE_KEY
