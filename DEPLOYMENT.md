# Assemble Protocol Deployment Guide

## Overview

The Assemble protocol uses CREATE2 for deterministic deployment with a vanity address starting with `0x0000000`. This guide covers the deployment process.

## Prerequisites

1. **Environment Setup**: Copy `.env.example` to `.env` and configure:
   ```bash
   cp .env.example .env
   ```

2. **Required Environment Variables**:
   - `ETHERSCAN_API_KEY`: Your Etherscan API key for contract verification
   - `DEPLOYER_PRIVATE_KEY`: Private key for deployment transactions
   - `SEPOLIA_RPC_URL`: RPC endpoint for Sepolia testnet
   - `MAINNET_RPC_URL`: RPC endpoint for Ethereum mainnet

## Vanity Address Deployment

### Step 1: Find Vanity Salt

Run the vanity address finder to generate a salt that produces an address starting with `0x0000000`:

```bash
node scripts/findVanitySalt.js
```

This will:
- Search for a CREATE2 salt that produces the desired vanity address
- Save results to `vanity-deployment.json` when found
- Display deployment commands

**Expected Time**: ~30-60 minutes (searching ~268M possibilities)

### Step 2: Deploy with Vanity Salt

Once the vanity salt is found, deploy using the helper script:

```bash
# For Sepolia testnet
./scripts/deployVanity.sh <SALT> sepolia

# For Ethereum mainnet  
./scripts/deployVanity.sh <SALT> mainnet
```

The deployment will:
1. Verify the salt produces a vanity address
2. Deploy Assemble contract to the vanity address
3. Immediately transfer control to the multisig (`0x1481ECEaBEb85124A82793CFf46FFA5fbFB1f3bF`)
4. Automatically verify the contract on Etherscan

### Step 3: Fallback Normal Deployment

If vanity address isn't required, use normal deployment:

```bash
forge script script/DeployVanityWithTransfer.s.sol:DeployVanityWithTransferScript \
  --sig "deployNormal()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Deployment Configuration

- **Initial Deployer**: `0xc1951eF408265A3b90d07B0BE030e63CCc7da6c6`
- **Target Multisig**: `0x1481ECEaBEb85124A82793CFf46FFA5fbFB1f3bF`
- **Protocol Fee**: 50 bps (0.5%)
- **Contract Size**: ~21.5kb (optimized with custom errors)

## Post-Deployment Verification

After deployment, verify:

1. **Contract Address**: Starts with `0x0000000` (if using vanity deployment)
2. **Fee Recipient**: Confirm `feeTo()` returns the multisig address
3. **Protocol Fee**: Confirm `protocolFeeBps()` returns `50`
4. **Etherscan Verification**: Contract source code is verified and readable

## Security Considerations

- ✅ Private keys and API keys stored in `.env` (gitignored)
- ✅ Immediate control transfer to multisig after deployment
- ✅ Deterministic deployment with CREATE2
- ✅ Automatic contract verification on Etherscan
- ✅ Gas-optimized with 1M optimizer runs

## Example Deployment Flow

```bash
# 1. Start vanity search
node scripts/findVanitySalt.js &

# 2. Wait for results (check periodically)
ls vanity-deployment.json

# 3. Deploy with found salt
SALT=$(jq -r '.salt' vanity-deployment.json)
./scripts/deployVanity.sh $SALT mainnet

# 4. Verify deployment success
echo "Deployed to vanity address!"
```

## Networks

The deployment scripts support:
- **Sepolia**: Ethereum testnet
- **Mainnet**: Ethereum mainnet
- **Base**: Base L2 mainnet
- **Custom**: Any RPC URL can be passed directly 