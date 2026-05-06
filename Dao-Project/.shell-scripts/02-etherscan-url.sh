source .env
trap 'hide-env-vars "$BASH_COMMAND"' DEBUG

echo https://sepolia.etherscan.io/address/$GOVERNOR_ADDR\#events
