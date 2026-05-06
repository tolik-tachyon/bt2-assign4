source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast receipt $DELEGATE_HASH --rpc-url sepolia | grep gasUsed
cast receipt $CASTVOTE_HASH --rpc-url sepolia | grep gasUsed
cast receipt $QUEUE_HASH    --rpc-url sepolia | grep gasUsed
cast receipt $EXECUTE_HASH  --rpc-url sepolia | grep gasUsed
cast receipt $PROPOSAL_HASH --rpc-url sepolia | grep gasUsed
