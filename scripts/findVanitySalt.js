#!/usr/bin/env node

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Production configuration
const TARGET_PREFIX = '0000000'; // Address should start with 0x0000000
const DEPLOYER_ADDRESS = '0xc1951eF408265A3b90d07B0BE030e63CCc7da6c6'; // Your production address
const FEE_TO_ADDRESS = '0xc1951eF408265A3b90d07B0BE030e63CCc7da6c6'; // Constructor argument

/**
 * Compute CREATE2 address
 * address = keccak256(0xff + deployer + salt + keccak256(initCode))[12:]
 */
function computeCreate2Address(deployerAddress, salt, initCodeHash) {
    const deployerBytes = Buffer.from(deployerAddress.slice(2), 'hex');
    const saltBytes = Buffer.from(salt.slice(2).padStart(64, '0'), 'hex');
    const initCodeHashBytes = Buffer.from(initCodeHash.slice(2), 'hex');
    
    const data = Buffer.concat([
        Buffer.from('ff', 'hex'),
        deployerBytes,
        saltBytes,
        initCodeHashBytes
    ]);
    
    const hash = crypto.createHash('sha3-256').update(data).digest();
    return '0x' + hash.slice(12).toString('hex');
}

/**
 * Get contract bytecode and constructor args from forge compilation
 */
function getContractBytecode() {
    try {
        // Read the compiled contract
        const artifactPath = path.join(__dirname, '../out/Assemble.sol/Assemble.json');
        const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
        
        const bytecode = artifact.bytecode.object;
        
        // Encode constructor arguments (address _feeTo)
        const constructorArgs = FEE_TO_ADDRESS.slice(2).padStart(64, '0');
        
        const initCode = bytecode + constructorArgs;
        const initCodeHash = '0x' + crypto.createHash('sha3-256').update(Buffer.from(initCode.slice(2), 'hex')).digest('hex');
        
        console.log('📄 Contract bytecode length:', bytecode.length / 2 - 1, 'bytes');
        console.log('🔧 Constructor args (feeTo):', FEE_TO_ADDRESS);
        console.log('📦 Init code hash:', initCodeHash);
        console.log('🚀 Deployer address:', DEPLOYER_ADDRESS);
        console.log('🎯 Target prefix: 0x' + TARGET_PREFIX);
        console.log('');
        
        return { bytecode, initCode, initCodeHash };
    } catch (error) {
        console.error('❌ Error reading contract bytecode:', error.message);
        console.log('💡 Make sure to run "forge build" first');
        process.exit(1);
    }
}

/**
 * Generate random salt
 */
function generateRandomSalt() {
    return '0x' + crypto.randomBytes(32).toString('hex');
}

/**
 * Check if address starts with target prefix
 */
function hasTargetPrefix(address) {
    return address.toLowerCase().startsWith('0x' + TARGET_PREFIX.toLowerCase());
}

/**
 * Main function to find vanity salt
 */
function findVanitySalt() {
    console.log('🔍 Finding CREATE2 salt for vanity address...\n');
    
    const { initCodeHash } = getContractBytecode();
    
    let attempts = 0;
    const startTime = Date.now();
    
    console.log('⏳ Searching for salt (this may take a while)...\n');
    
    while (true) {
        attempts++;
        
        const salt = generateRandomSalt();
        const address = computeCreate2Address(DEPLOYER_ADDRESS, salt, initCodeHash);
        
        if (hasTargetPrefix(address)) {
            const duration = (Date.now() - startTime) / 1000;
            const attemptsPerSecond = Math.round(attempts / duration);
            
            console.log('🎉 SUCCESS! Found vanity address!');
            console.log('');
            console.log('📍 Address:', address);
            console.log('🧂 Salt:', salt);
            console.log('⚡ Attempts:', attempts.toLocaleString());
            console.log('⏱️  Duration:', duration.toFixed(2), 'seconds');
            console.log('🚀 Speed:', attemptsPerSecond.toLocaleString(), 'attempts/second');
            console.log('');
            console.log('📋 Deployment command:');
            console.log(`forge create src/Assemble.sol:Assemble \\`);
            console.log(`  --constructor-args ${FEE_TO_ADDRESS} \\`);
            console.log(`  --salt ${salt} \\`);
            console.log(`  --rpc-url https://sepolia.infura.io/v3/YOUR_API_KEY \\`);
            console.log(`  --private-key YOUR_PRIVATE_KEY`);
            console.log('');
            
            // Save results to file
            const results = {
                address,
                salt,
                deployerAddress: DEPLOYER_ADDRESS,
                feeToAddress: FEE_TO_ADDRESS,
                attempts,
                duration,
                timestamp: new Date().toISOString()
            };
            
            fs.writeFileSync('vanity-deployment.json', JSON.stringify(results, null, 2));
            console.log('💾 Results saved to vanity-deployment.json');
            
            break;
        }
        
        // Progress update every 10000 attempts
        if (attempts % 10000 === 0) {
            const duration = (Date.now() - startTime) / 1000;
            const attemptsPerSecond = Math.round(attempts / duration);
            console.log(`🔄 Attempt ${attempts.toLocaleString()} (${attemptsPerSecond.toLocaleString()}/sec) - Latest: ${address}`);
        }
    }
}

/**
 * Estimate difficulty
 */
function estimateDifficulty() {
    const prefixLength = TARGET_PREFIX.length;
    const difficulty = Math.pow(16, prefixLength); // 16^n where n is hex digits
    const expectedAttempts = difficulty / 2; // On average, need half the search space
    
    console.log('📊 Difficulty Analysis:');
    console.log(`🎯 Target prefix: ${TARGET_PREFIX} (${prefixLength} hex digits)`);
    console.log(`🔢 Search space: 16^${prefixLength} = ${difficulty.toLocaleString()}`);
    console.log(`⏱️  Expected attempts: ~${expectedAttempts.toLocaleString()}`);
    console.log(`⏰ Estimated time: ~${Math.round(expectedAttempts / 1000)} seconds at 1K attempts/sec`);
    console.log('');
}

// Run the script
if (require.main === module) {
    console.log('🎭 Assemble Vanity Address Generator');
    console.log('=====================================\n');
    
    estimateDifficulty();
    findVanitySalt();
} 