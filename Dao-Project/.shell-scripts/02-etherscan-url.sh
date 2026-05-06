source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

echo https://sepolia.etherscan.io/address/$TOKEN_ADDR\#events
echo https://sepolia.etherscan.io/address/$GOVERNOR_ADDR\#events
echo https://sepolia.etherscan.io/address/$TIMELOCK_ADDR\#events
echo https://sepolia.etherscan.io/address/$TREASURY_ADDR\#events
echo https://sepolia.etherscan.io/address/$BOX_ADDR\#events
