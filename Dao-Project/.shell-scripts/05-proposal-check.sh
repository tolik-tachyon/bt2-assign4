source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

cast call $GOVERNOR_ADDR "state(uint256)(uint8)" \
    $PROPOSAL_ID --rpc-url sepolia

cast call $GOVERNOR_ADDR "proposalVotes(uint256)(uint256,uint256,uint256)" \
    $PROPOSAL_ID --rpc-url sepolia
