#!/bin/bash

# Vanity Deployment Helper Script
# Usage: ./scripts/deployVanity.sh <SALT> [NETWORK]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎭 Assemble Vanity Deployment Helper${NC}"
echo "=================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo -e "${GREEN}✅ Loaded .env file${NC}"
else
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please create a .env file with ETHERSCAN_API_KEY"
    exit 1
fi

# Check if salt is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Salt required${NC}"
    echo "Usage: $0 <SALT> [NETWORK]"
    echo "Example: $0 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef sepolia"
    exit 1
fi

SALT=$1
NETWORK=${2:-"sepolia"}  # Default to sepolia

# Get RPC URL based on network
case $NETWORK in
    "sepolia")
        RPC_URL=${SEPOLIA_RPC_URL:-"https://sepolia.infura.io/v3/YOUR_INFURA_KEY"}
        ;;
    "mainnet")
        RPC_URL=${MAINNET_RPC_URL:-"https://mainnet.infura.io/v3/YOUR_INFURA_KEY"}
        ;;
    "base")
        RPC_URL=${BASE_RPC_URL:-"https://mainnet.base.org"}
        ;;
    *)
        RPC_URL=$NETWORK  # Use as direct RPC URL
        ;;
esac

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  Salt: $SALT"
echo "  Network: $NETWORK"
echo "  RPC URL: $RPC_URL"
echo "  Deployer: $INITIAL_DEPLOYER"
echo "  Multisig: $MULTISIG_ADDRESS"
echo "  API Key: ${ETHERSCAN_API_KEY:0:8}...***"
echo ""

# Verify the salt produces a vanity address
echo -e "${BLUE}🔍 Verifying salt produces vanity address...${NC}"
forge script script/DeployVanityWithTransfer.s.sol:DeployVanityWithTransferScript \
    --sig "verifyVanitySalt(bytes32)" $SALT \
    --rpc-url $RPC_URL

echo ""
read -p "Does the salt produce a vanity address starting with 0x0000000? (y/N): " confirm

if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo -e "${RED}❌ Deployment cancelled${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🚀 Starting deployment...${NC}"

# Deploy with the vanity salt
forge script script/DeployVanityWithTransfer.s.sol:DeployVanityWithTransferScript \
    --sig "run(bytes32)" $SALT \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Verify the contract address starts with 0x0000000"
echo "2. Confirm the multisig has control (feeTo = $MULTISIG_ADDRESS)"
echo "3. Test basic functionality"
echo "4. Announce the vanity address to the community! 🎉" 