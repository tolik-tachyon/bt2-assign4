source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast receipt $PROPOSAL_HASH --rpc-url sepolia
