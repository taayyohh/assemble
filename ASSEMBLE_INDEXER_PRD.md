# Assemble Protocol Indexer - Product Requirements Document (PRD)

## Claude Implementation Prompt

```
You are tasked with building a multi-chain blockchain indexer for the Assemble Protocol that closely follows the architecture of the ponderfinance/ponder-indexer repository. This is NOT a Ponder.sh framework project - it's a custom TypeScript indexer using Prisma ORM with MongoDB, GraphQL API, and multi-chain support.

Key Requirements:
- Follow the EXACT structure and patterns from ponderfinance/ponder-indexer
- Use TypeScript throughout
- Prisma ORM with MongoDB database
- GraphQL API (NOT Express REST API)
- Multi-chain blockchain event indexing
- Real-time event processing
- Relay-compatible GraphQL schema for frontend
- Production-ready error handling and logging
- No Docker usage (follow the existing pattern)
- Leverage ALL existing work from ponderfinance/ponder-indexer
- Protocol-agnostic core indexer that can be reused
- Sophisticated retry mechanisms and state recovery

The indexer should track Assemble Protocol events across multiple chains and provide a GraphQL API for the frontend to consume via Relay.
```

## Project Overview

The **Assemble Protocol Indexer** is a custom-built, multi-chain blockchain indexer that tracks events from the Assemble Protocol smart contracts across supported networks. It provides a GraphQL API optimized for Relay consumption by the frontend application.

**Key Innovation**: The indexer is built with a **protocol-agnostic core** that can be easily adapted for other protocols, maximizing code reuse and maintaining the sophisticated infrastructure already developed in the ponderfinance indexer.

### Core Purpose
Index and serve Assemble Protocol data including:
- Event creation and management
- Ticket purchases and RSVPs
- Social interactions (tips, friend connections)
- Payment splits and fund distributions
- Cross-chain activity aggregation

## Technical Architecture

### Tech Stack (Mirroring ponderfinance/ponder-indexer)

**Core Framework:**
- **TypeScript** - Primary language
- **Node.js** - Runtime environment
- **Prisma ORM** - Database ORM and migrations
- **MongoDB** - Primary database
- **GraphQL** - API layer (Relay-compatible)
- **pnpm** - Package manager

**Blockchain Integration:**
- **viem** - Ethereum client library
- **WebSocket** - Real-time blockchain connections
- **Multi-chain RPC** - Support for all Assemble Protocol chains

**Development Tools:**
- **TypeScript** - Type safety and development experience
- **Prisma Studio** - Database management
- **GraphQL Playground** - API testing
- **Winston** - Logging framework

### Database Configuration

**MongoDB Connection:**
```
mongodb+srv://theo:UsSUjbCN8MLEwgCt@assemble.ilxfxkn.mongodb.net/?retryWrites=true&w=majority&appName=assemble
```

**Prisma Schema Structure:**
- Event entities (events, tickets, RSVPs)
- User entities (profiles, friendships)
- Transaction entities (payments, tips, splits)
- Chain-specific metadata
- Indexing state management

## Project Structure (Following ponderfinance/ponder-indexer)

```
assemble-indexer/
├── prisma/
│   ├── schema.prisma           # Database schema
│   └── migrations/             # Database migrations
├── src/
│   ├── core/                   # Protocol-agnostic indexer core
│   │   ├── indexer/            # Base indexer implementation
│   │   ├── blockchain/         # Generic blockchain clients
│   │   ├── retry/              # Retry mechanisms and strategies
│   │   ├── state/              # State management and recovery
│   │   ├── monitoring/         # Metrics and health checks
│   │   └── types/              # Core type definitions
│   ├── protocols/
│   │   └── assemble/           # Assemble-specific implementations
│   │       ├── config/         # Protocol configuration
│   │       ├── handlers/       # Event handlers
│   │       ├── processors/     # Data processors
│   │       └── schema/         # Protocol-specific schema
│   ├── graphql/
│   │   ├── schema/             # GraphQL schema definitions
│   │   ├── resolvers/          # GraphQL resolvers
│   │   └── types/              # GraphQL type definitions
│   ├── database/
│   │   ├── client.ts           # Prisma client setup
│   │   ├── operations/         # Database operations
│   │   └── migrations/         # Migration utilities
│   ├── services/
│   │   ├── blockchain/         # Blockchain connection services
│   │   ├── metrics/            # Performance metrics
│   │   ├── logging/            # Logging configuration
│   │   └── cleanup/            # Data cleanup and maintenance
│   ├── utils/
│   │   ├── constants.ts        # Application constants
│   │   ├── helpers.ts          # Utility functions
│   │   └── types.ts            # TypeScript type definitions
│   └── main.ts                 # Application entry point
├── scripts/
│   ├── deploy.ts               # Deployment scripts
│   ├── migrate.ts              # Database migration scripts
│   ├── seed.ts                 # Database seeding
│   ├── cleanup/                # Data cleanup scripts
│   │   ├── duplicates.ts       # Duplicate transaction cleanup
│   │   └── orphaned.ts         # Orphaned data cleanup
│   └── maintenance/            # Maintenance utilities
├── logs/                       # Application logs
├── data/                       # Local data storage
├── dist/                       # Compiled TypeScript
├── package.json
├── tsconfig.json
├── tsconfig.build.json
└── pnpm-lock.yaml
```

## Core Indexer Architecture (Protocol-Agnostic)

### 1. Base Indexer Core (`src/core/indexer/`)

**`BaseIndexer.ts` - Protocol-agnostic indexer foundation:**
```typescript
export abstract class BaseIndexer<TEvent, TProcessedData> {
  protected readonly config: IndexerConfig;
  protected readonly logger: Logger;
  protected readonly metrics: MetricsCollector;
  protected readonly retryManager: RetryManager;
  protected readonly stateManager: StateManager;
  
  constructor(config: IndexerConfig) {
    this.config = config;
    this.logger = createLogger(config.logging);
    this.metrics = new MetricsCollector(config.metrics);
    this.retryManager = new RetryManager(config.retry);
    this.stateManager = new StateManager(config.state);
  }
  
  abstract processEvent(event: TEvent): Promise<TProcessedData>;
  abstract validateEvent(event: TEvent): boolean;
  abstract getEventSignature(): string;
  
  async start(): Promise<void> {
    await this.initializeState();
    await this.startEventListening();
    await this.startHealthChecks();
  }
  
  protected async handleEvent(rawEvent: any): Promise<void> {
    const startTime = Date.now();
    
    try {
      const event = this.parseEvent(rawEvent);
      
      if (!this.validateEvent(event)) {
        this.logger.warn('Invalid event received', { event });
        return;
      }
      
      const processedData = await this.retryManager.execute(
        () => this.processEvent(event),
        {
          context: { eventHash: rawEvent.transactionHash, blockNumber: rawEvent.blockNumber },
          maxRetries: this.config.retry.maxRetries
        }
      );
      
      await this.stateManager.updateProcessedBlock(rawEvent.blockNumber);
      this.metrics.recordEventProcessed(Date.now() - startTime);
      
    } catch (error) {
      this.logger.error('Failed to process event', { error, rawEvent });
      this.metrics.recordEventError();
      throw error;
    }
  }
}
```

**`IndexerConfig.ts` - Configuration interface:**
```typescript
export interface IndexerConfig {
  chains: ChainConfig[];
  database: DatabaseConfig;
  retry: RetryConfig;
  logging: LoggingConfig;
  metrics: MetricsConfig;
  state: StateConfig;
  protocol: ProtocolConfig;
}

export interface ChainConfig {
  chainId: number;
  name: string;
  rpcUrl: string;
  wsUrl?: string;
  contracts: ContractConfig[];
  startBlock: number;
  confirmations: number;
  batchSize: number;
  maxBlockRange: number;
}

export interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  backoffMultiplier: number;
  jitter: boolean;
  retryableErrors: string[];
  circuitBreaker: CircuitBreakerConfig;
}
```

### 2. Advanced Retry Mechanisms (`src/core/retry/`)

**`RetryManager.ts` - Sophisticated retry handling:**
```typescript
export class RetryManager {
  private readonly config: RetryConfig;
  private readonly circuitBreakers: Map<string, CircuitBreaker>;
  private readonly rateLimiters: Map<string, RateLimiter>;
  private readonly logger: Logger;
  
  constructor(config: RetryConfig) {
    this.config = config;
    this.circuitBreakers = new Map();
    this.rateLimiters = new Map();
    this.logger = createLogger({ module: 'RetryManager' });
  }
  
  async execute<T>(
    operation: () => Promise<T>,
    options: RetryOptions
  ): Promise<T> {
    const { context, maxRetries = this.config.maxRetries } = options;
    const operationId = this.generateOperationId(context);
    
    // Check circuit breaker
    const circuitBreaker = this.getCircuitBreaker(operationId);
    if (circuitBreaker.isOpen()) {
      throw new Error(`Circuit breaker open for operation: ${operationId}`);
    }
    
    // Apply rate limiting
    await this.applyRateLimit(operationId);
    
    let lastError: Error;
    
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const result = await operation();
        
        // Success - reset circuit breaker
        circuitBreaker.recordSuccess();
        
        if (attempt > 0) {
          this.logger.info('Operation succeeded after retry', {
            operationId,
            attempt,
            context
          });
        }
        
        return result;
        
      } catch (error) {
        lastError = error as Error;
        
        // Record failure
        circuitBreaker.recordFailure();
        
        // Check if error is retryable
        if (!this.isRetryableError(error) || attempt === maxRetries) {
          this.logger.error('Operation failed permanently', {
            operationId,
            attempt,
            error: error.message,
            context
          });
          throw error;
        }
        
        // Calculate delay with exponential backoff and jitter
        const delay = this.calculateDelay(attempt);
        
        this.logger.warn('Operation failed, retrying', {
          operationId,
          attempt,
          nextRetryIn: delay,
          error: error.message,
          context
        });
        
        await this.sleep(delay);
      }
    }
    
    throw lastError!;
  }
  
  private calculateDelay(attempt: number): number {
    const exponentialDelay = this.config.baseDelay * 
      Math.pow(this.config.backoffMultiplier, attempt);
    
    const cappedDelay = Math.min(exponentialDelay, this.config.maxDelay);
    
    if (this.config.jitter) {
      // Add ±25% jitter to prevent thundering herd
      const jitterAmount = cappedDelay * 0.25;
      return cappedDelay + (Math.random() - 0.5) * 2 * jitterAmount;
    }
    
    return cappedDelay;
  }
  
  private isRetryableError(error: any): boolean {
    const errorMessage = error.message?.toLowerCase() || '';
    const errorCode = error.code || '';
    
    // Network/connection errors
    if (errorMessage.includes('network') || 
        errorMessage.includes('timeout') ||
        errorMessage.includes('connection') ||
        errorCode === 'ECONNRESET' ||
        errorCode === 'ETIMEDOUT') {
      return true;
    }
    
    // Rate limiting
    if (error.status === 429 || errorMessage.includes('rate limit')) {
      return true;
    }
    
    // Temporary server errors
    if (error.status >= 500 && error.status < 600) {
      return true;
    }
    
    // Custom retryable errors from config
    return this.config.retryableErrors.some(retryableError =>
      errorMessage.includes(retryableError.toLowerCase())
    );
  }
}
```

**`CircuitBreaker.ts` - Circuit breaker implementation:**
```typescript
export class CircuitBreaker {
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  private failureCount = 0;
  private lastFailureTime?: number;
  private successCount = 0;
  
  constructor(private config: CircuitBreakerConfig) {}
  
  isOpen(): boolean {
    if (this.state === 'OPEN') {
      if (Date.now() - (this.lastFailureTime || 0) > this.config.timeout) {
        this.state = 'HALF_OPEN';
        this.successCount = 0;
        return false;
      }
      return true;
    }
    return false;
  }
  
  recordSuccess(): void {
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= this.config.successThreshold) {
        this.state = 'CLOSED';
        this.failureCount = 0;
      }
    } else {
      this.failureCount = 0;
    }
  }
  
  recordFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    
    if (this.state === 'HALF_OPEN' || 
        this.failureCount >= this.config.failureThreshold) {
      this.state = 'OPEN';
    }
  }
}
```

### 3. State Management & Recovery (`src/core/state/`)

**`StateManager.ts` - Indexing state and recovery:**
```typescript
export class StateManager {
  private readonly prisma: PrismaClient;
  private readonly config: StateConfig;
  private readonly logger: Logger;
  private checkpointInterval: NodeJS.Timeout | null = null;
  
  constructor(config: StateConfig) {
    this.config = config;
    this.prisma = getPrismaClient();
    this.logger = createLogger({ module: 'StateManager' });
  }
  
  async initializeState(): Promise<void> {
    await this.createStateTablesIfNotExists();
    await this.recoverFromLastCheckpoint();
    this.startPeriodicCheckpoints();
  }
  
  async getLastProcessedBlock(chainId: number): Promise<number> {
    const state = await this.prisma.indexerState.findUnique({
      where: { chainId }
    });
    
    return state?.lastProcessedBlock || this.config.startBlock;
  }
  
  async updateProcessedBlock(
    chainId: number, 
    blockNumber: number,
    transactionHash?: string
  ): Promise<void> {
    await this.prisma.indexerState.upsert({
      where: { chainId },
      update: {
        lastProcessedBlock: blockNumber,
        lastProcessedAt: new Date(),
        lastTransactionHash: transactionHash,
        isHealthy: true
      },
      create: {
        chainId,
        lastProcessedBlock: blockNumber,
        lastProcessedAt: new Date(),
        lastTransactionHash: transactionHash,
        isHealthy: true
      }
    });
  }
  
  async createCheckpoint(chainId: number): Promise<void> {
    const currentState = await this.prisma.indexerState.findUnique({
      where: { chainId }
    });
    
    if (!currentState) return;
    
    await this.prisma.indexerCheckpoint.create({
      data: {
        chainId,
        blockNumber: currentState.lastProcessedBlock,
        checkpointAt: new Date(),
        metadata: {
          transactionHash: currentState.lastTransactionHash,
          version: this.config.version
        }
      }
    });
    
    // Cleanup old checkpoints
    await this.cleanupOldCheckpoints(chainId);
  }
  
  async recoverFromLastCheckpoint(): Promise<void> {
    const chains = await this.prisma.indexerState.findMany();
    
    for (const chain of chains) {
      if (!chain.isHealthy) {
        this.logger.warn('Unhealthy chain detected, recovering', {
          chainId: chain.chainId,
          lastBlock: chain.lastProcessedBlock
        });
        
        await this.performRecovery(chain.chainId);
      }
    }
  }
  
  private async performRecovery(chainId: number): Promise<void> {
    const latestCheckpoint = await this.prisma.indexerCheckpoint.findFirst({
      where: { chainId },
      orderBy: { checkpointAt: 'desc' }
    });
    
    if (latestCheckpoint) {
      this.logger.info('Recovering from checkpoint', {
        chainId,
        checkpointBlock: latestCheckpoint.blockNumber
      });
      
      // Roll back to checkpoint
      await this.rollbackToBlock(chainId, latestCheckpoint.blockNumber);
    }
    
    // Mark as healthy
    await this.prisma.indexerState.update({
      where: { chainId },
      data: { isHealthy: true }
    });
  }
}
```

### 4. Event Listener Memory Leak Prevention

**`EventListenerManager.ts` - Memory leak prevention (from EVENT_LISTENER_MEMORY_LEAK_FIX.md):**
```typescript
export class EventListenerManager {
  private readonly listeners: Map<string, Set<Function>> = new Map();
  private readonly cleanupTimers: Map<string, NodeJS.Timeout> = new Map();
  private readonly maxListeners = 100;
  private readonly cleanupInterval = 5 * 60 * 1000; // 5 minutes
  
  addEventListener(eventName: string, listener: Function): void {
    if (!this.listeners.has(eventName)) {
      this.listeners.set(eventName, new Set());
    }
    
    const eventListeners = this.listeners.get(eventName)!;
    
    if (eventListeners.size >= this.maxListeners) {
      this.logger.warn('Max listeners reached, cleaning up oldest', { eventName });
      this.cleanupOldestListeners(eventName);
    }
    
    eventListeners.add(listener);
    this.scheduleCleanup(eventName);
  }
  
  removeEventListener(eventName: string, listener: Function): void {
    const eventListeners = this.listeners.get(eventName);
    if (eventListeners) {
      eventListeners.delete(listener);
      
      if (eventListeners.size === 0) {
        this.listeners.delete(eventName);
        this.cancelCleanup(eventName);
      }
    }
  }
  
  private cleanupOldestListeners(eventName: string): void {
    const eventListeners = this.listeners.get(eventName);
    if (!eventListeners) return;
    
    const listenersArray = Array.from(eventListeners);
    const toRemove = listenersArray.slice(0, Math.floor(this.maxListeners * 0.2));
    
    toRemove.forEach(listener => eventListeners.delete(listener));
  }
  
  cleanup(): void {
    this.listeners.clear();
    this.cleanupTimers.forEach(timer => clearTimeout(timer));
    this.cleanupTimers.clear();
  }
}
```

### 5. Metrics and Monitoring (`src/core/monitoring/`)

**`MetricsCollector.ts` - Performance tracking (from METRICS_UPDATE_FREQUENCY.md):**
```typescript
export class MetricsCollector {
  private readonly metrics: Map<string, Metric> = new Map();
  private readonly updateInterval: number;
  private updateTimer: NodeJS.Timeout | null = null;
  
  constructor(config: MetricsConfig) {
    this.updateInterval = config.updateFrequency || 30000; // 30 seconds
    this.startPeriodicUpdates();
  }
  
  recordEventProcessed(processingTimeMs: number): void {
    this.incrementCounter('events_processed_total');
    this.recordHistogram('event_processing_duration_ms', processingTimeMs);
    this.updateGauge('last_event_processed_at', Date.now());
  }
  
  recordEventError(errorType?: string): void {
    this.incrementCounter('events_error_total', { error_type: errorType || 'unknown' });
  }
  
  recordBlockchainSync(chainId: number, blockNumber: number, latency: number): void {
    this.updateGauge('last_synced_block', blockNumber, { chain_id: chainId.toString() });
    this.recordHistogram('blockchain_sync_latency_ms', latency, { chain_id: chainId.toString() });
  }
  
  recordDatabaseOperation(operation: string, durationMs: number, success: boolean): void {
    this.recordHistogram('database_operation_duration_ms', durationMs, { 
      operation, 
      status: success ? 'success' : 'error' 
    });
  }
  
  getMetrics(): Record<string, any> {
    const result: Record<string, any> = {};
    
    this.metrics.forEach((metric, name) => {
      result[name] = metric.getValue();
    });
    
    return result;
  }
  
  private startPeriodicUpdates(): void {
    this.updateTimer = setInterval(() => {
      this.updateDerivedMetrics();
      this.exportMetrics();
    }, this.updateInterval);
  }
  
  private updateDerivedMetrics(): void {
    // Calculate rates and averages
    const eventsProcessed = this.getCounter('events_processed_total');
    const eventsErrors = this.getCounter('events_error_total');
    
    if (eventsProcessed > 0) {
      const errorRate = eventsErrors / eventsProcessed;
      this.updateGauge('event_error_rate', errorRate);
    }
    
    // Update system metrics
    this.updateGauge('memory_usage_bytes', process.memoryUsage().heapUsed);
    this.updateGauge('uptime_seconds', process.uptime());
  }
}
```

## Protocol-Specific Implementation (Assemble)

### 1. Assemble Protocol Configuration (`src/protocols/assemble/config/`)

**`assembleConfig.ts` - Protocol-specific settings:**
```typescript
export const ASSEMBLE_CONFIG: ProtocolConfig = {
  name: 'assemble',
  version: '1.0.0',
  contracts: {
    1: { // Ethereum
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 21000000,
        abi: ASSEMBLE_ABI
      }
    },
    480: { // World Chain
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 1000000,
        abi: ASSEMBLE_ABI
      }
    },
    747: { // Flow EVM
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 1000000,
        abi: ASSEMBLE_ABI
      }
    },
    11155111: { // Sepolia
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 5000000,
        abi: ASSEMBLE_ABI
      }
    }
  },
  events: {
    EventCreated: {
      signature: 'EventCreated(uint256,address,string,uint256,uint256,uint8)',
      processor: 'EventCreatedProcessor'
    },
    TicketPurchased: {
      signature: 'TicketPurchased(uint256,uint256,address,uint256,uint256,uint256,address)',
      processor: 'TicketPurchasedProcessor'
    },
    EventTipped: {
      signature: 'EventTipped(uint256,address,uint256,uint256,address)',
      processor: 'EventTippedProcessor'
    },
    CheckedIn: {
      signature: 'CheckedIn(uint256,address)',
      processor: 'CheckedInProcessor'
    },
    FriendAdded: {
      signature: 'FriendAdded(address,address)',
      processor: 'FriendAddedProcessor'
    },
    RSVPUpdated: {
      signature: 'RSVPUpdated(uint256,address,uint8)',
      processor: 'RSVPUpdatedProcessor'
    },
    CommentPosted: {
      signature: 'CommentPosted(uint256,uint256,address,string,uint256)',
      processor: 'CommentPostedProcessor'
    },
    InvitationSent: {
      signature: 'InvitationSent(uint256,address,address)',
      processor: 'InvitationSentProcessor'
    },
    // ERC-6909 Multi-token events
    Transfer: {
      signature: 'Transfer(address,address,address,uint256,uint256)',
      processor: 'ERC6909TransferProcessor'
    }
  },
  tokenTypes: {
    EVENT_TICKET: 0,
    ATTENDANCE_BADGE: 1,
    ORGANIZER_CRED: 2
  },
  retry: {
    maxRetries: 5,
    baseDelay: 1000,
    maxDelay: 30000,
    backoffMultiplier: 2,
    jitter: true,
    retryableErrors: ['network', 'timeout', 'rate limit', 'internal server error']
  }
};
```

### 2. Event Processors (`src/protocols/assemble/processors/`)

**`EventCreatedProcessor.ts` - Assemble-specific event processing:**
```typescript
export class EventCreatedProcessor extends BaseEventProcessor<EventCreatedEvent, ProcessedEvent> {
  
  async processEvent(event: EventCreatedEvent): Promise<ProcessedEvent> {
    // Extract event data
    const { eventId, creator, title, startTime, endTime } = event.args;
    
    // Validate event data
    this.validateEventData(event);
    
    // Transform and normalize data
    const processedEvent: ProcessedEvent = {
      id: this.generateEventId(event),
      eventId: BigInt(eventId),
      creator: creator.toLowerCase(),
      title: this.sanitizeString(title),
      startTime: new Date(Number(startTime) * 1000),
      endTime: endTime ? new Date(Number(endTime) * 1000) : null,
      chainId: event.chainId,
      blockNumber: BigInt(event.blockNumber),
      transactionHash: event.transactionHash,
      logIndex: event.logIndex,
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    // Store in database with conflict resolution
    await this.storeEvent(processedEvent);
    
    // Update related entities
    await this.updateUserStats(creator);
    await this.updateChainMetrics(event.chainId);
    
    return processedEvent;
  }
  
  private async storeEvent(event: ProcessedEvent): Promise<void> {
    try {
      await this.prisma.event.upsert({
        where: {
          eventId_chainId: {
            eventId: event.eventId,
            chainId: event.chainId
          }
        },
        update: {
          title: event.title,
          startTime: event.startTime,
          endTime: event.endTime,
          updatedAt: event.updatedAt
        },
        create: event
      });
    } catch (error) {
      if (this.isDuplicateError(error)) {
        this.logger.warn('Duplicate event detected, updating', {
          eventId: event.eventId,
          chainId: event.chainId
        });
        
        // Handle duplicate with conflict resolution
        await this.resolveDuplicate(event);
      } else {
        throw error;
      }
    }
  }
  
  private async resolveDuplicate(event: ProcessedEvent): Promise<void> {
    const existing = await this.prisma.event.findUnique({
      where: {
        eventId_chainId: {
          eventId: event.eventId,
          chainId: event.chainId
        }
      }
    });
    
    if (existing && existing.blockNumber < event.blockNumber) {
      // Update with newer data
      await this.prisma.event.update({
        where: { id: existing.id },
        data: {
          title: event.title,
          startTime: event.startTime,
          endTime: event.endTime,
          blockNumber: event.blockNumber,
          transactionHash: event.transactionHash,
          updatedAt: event.updatedAt
        }
      });
    }
  }
}
```

## Core Features & Requirements

### 1. Multi-Chain Event Indexing

**Supported Chains (from https://github.com/taayyohh/assemble):**
- Ethereum Mainnet (Chain ID: 1)
- World Chain Mainnet (Chain ID: 480)
- Flow EVM Mainnet (Chain ID: 747)
- Sepolia Testnet (Chain ID: 11155111)

**Assemble Protocol Contract Address (CREATE2 - Same on all chains):**
```
0x00000004FE7c1E461A1703AF603F1A5F080Be253
```

**Event Types to Index (from actual contract):**
```typescript
// Core Assemble Protocol Events
- EventCreated
- EventUpdated
- TicketPurchased (with platform fee tracking)
- EventTipped (with platform fee tracking)
- EventCancelled
- CheckedIn
- CheckedInWithTicket
- CheckedInDelegate
- FriendAdded
- RSVPUpdated
- CommentPosted
- InvitationSent
- InvitationRemoved
- RefundClaimed
```

**ERC-6909 Token Events:**
```typescript
// Multi-token standard events
- Transfer (for tickets and badges)
- TransferSingle
- TransferBatch
- OperatorSet
```

**Real-time Processing:**
- WebSocket connections to each chain
- Event filtering and validation
- Duplicate detection and handling
- Chain reorganization handling
- Automatic retry mechanisms

### 2. Database Schema (Prisma + MongoDB)

**Core Models (Updated for actual contract):**
```prisma
model Event {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  eventId         BigInt   @unique
  creator         String
  title           String
  description     String?
  location        String?
  startTime       DateTime
  endTime         DateTime?
  visibility      EventVisibility @default(PUBLIC)
  maxAttendees    Int?
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  
  // Relations
  ticketTiers     TicketTier[]
  paymentSplits   PaymentSplit[]
  tickets         Ticket[]
  rsvps          RSVP[]
  tips           Tip[]
  comments       Comment[]
  invitations    Invitation[]
  checkIns       CheckIn[]
  
  @@unique([eventId, chainId])
  @@map("events")
}

model TicketTier {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  eventId         String   @db.ObjectId
  tierId          Int
  name            String
  price           BigInt
  maxSupply       Int?
  soldCount       Int      @default(0)
  chainId         Int
  
  // Relations
  event           Event    @relation(fields: [eventId], references: [id])
  tickets         Ticket[]
  
  @@unique([eventId, tierId])
  @@map("ticket_tiers")
}

model Ticket {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  tokenId         String   @unique // ERC-6909 token ID
  eventId         String   @db.ObjectId
  tierId          Int
  purchaser       String
  quantity        Int
  totalPaid       BigInt
  platformFee     BigInt?  @default(0)
  referrer        String?
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  
  // Relations
  event           Event    @relation(fields: [eventId], references: [id])
  tier            TicketTier @relation(fields: [eventId, tierId], references: [eventId, tierId])
  user            User     @relation(fields: [purchaser], references: [address])
  
  @@map("tickets")
}

model AttendanceBadge {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  tokenId         String   @unique // Soulbound ERC-6909 token ID
  eventId         BigInt
  attendee        String
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  
  // Relations
  user            User     @relation(fields: [attendee], references: [address])
  
  @@map("attendance_badges")
}

model Tip {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  eventId         BigInt
  tipper          String
  amount          BigInt
  platformFee     BigInt?  @default(0)
  referrer        String?
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  
  // Relations
  event           Event    @relation(fields: [eventId], references: [eventId])
  user            User     @relation(fields: [tipper], references: [address])
  
  @@map("tips")
}

model Comment {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  commentId       BigInt   @unique
  eventId         BigInt
  author          String
  content         String
  parentId        BigInt?
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  
  // Relations
  event           Event    @relation(fields: [eventId], references: [eventId])
  user            User     @relation(fields: [author], references: [address])
  parent          Comment? @relation("CommentReplies", fields: [parentId], references: [commentId])
  replies         Comment[] @relation("CommentReplies")
  
  @@map("comments")
}

model Invitation {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  eventId         BigInt
  inviter         String
  invitee         String
  isActive        Boolean  @default(true)
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  
  // Relations
  event           Event    @relation(fields: [eventId], references: [eventId])
  inviterUser     User     @relation("SentInvitations", fields: [inviter], references: [address])
  inviteeUser     User     @relation("ReceivedInvitations", fields: [invitee], references: [address])
  
  @@unique([eventId, invitee])
  @@map("invitations")
}

model CheckIn {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  eventId         BigInt
  attendee        String
  ticketTokenId   String?  // Optional - for ticket-based check-ins
  checkInType     CheckInType
  chainId         Int
  blockNumber     BigInt
  transactionHash String
  createdAt       DateTime @default(now())
  
  // Relations
  event           Event    @relation(fields: [eventId], references: [eventId])
  user            User     @relation(fields: [attendee], references: [address])
  
  @@unique([eventId, attendee])
  @@map("check_ins")
}

model User {
  id              String   @id @default(auto()) @map("_id") @db.ObjectId
  address         String   @unique
  ensName         String?
  profilePicUrl   String?
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  
  // Relations
  createdEvents   Event[]
  tickets         Ticket[]
  badges          AttendanceBadge[]
  rsvps          RSVP[]
  tips           Tip[]
  comments       Comment[]
  sentInvitations Invitation[] @relation("SentInvitations")
  receivedInvitations Invitation[] @relation("ReceivedInvitations")
  checkIns       CheckIn[]
  friendships    Friendship[]
  
  @@map("users")
}

enum EventVisibility {
  PUBLIC
  PRIVATE
  INVITE_ONLY
}

enum CheckInType {
  BASIC
  WITH_TICKET
  DELEGATE
}

// Additional models for IndexerState, IndexerCheckpoint, etc. remain the same
```

### 3. Blockchain Integration

**Chain Configuration (Updated with actual deployments):**
```typescript
// src/indexer/chains/config.ts
export const CHAIN_CONFIGS = {
  1: {
    name: 'ethereum',
    displayName: 'Ethereum Mainnet',
    rpcUrl: process.env.ETHEREUM_RPC_URL,
    contracts: {
      assemble: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
    },
    startBlock: 21000000, // Update with actual deployment block
  },
  480: {
    name: 'worldchain',
    displayName: 'World Chain Mainnet',
    rpcUrl: process.env.WORLDCHAIN_RPC_URL,
    contracts: {
      assemble: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
    },
    startBlock: 1000000, // Update with actual deployment block
  },
  747: {
    name: 'flow',
    displayName: 'Flow EVM Mainnet',
    rpcUrl: process.env.FLOW_RPC_URL,
    contracts: {
      assemble: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
    },
    startBlock: 1000000, // Update with actual deployment block
  },
  11155111: {
    name: 'sepolia',
    displayName: 'Sepolia Testnet',
    rpcUrl: process.env.SEPOLIA_RPC_URL,
    contracts: {
      assemble: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
    },
    startBlock: 5000000, // Update with actual deployment block
  }
};
```

### 4. Protocol-Specific Implementation (Assemble)

**`assembleConfig.ts` - Updated with actual contract details:**
```typescript
export const ASSEMBLE_CONFIG: ProtocolConfig = {
  name: 'assemble',
  version: '1.0.0',
  contractAddress: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
  contracts: {
    1: { // Ethereum
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 21000000,
        abi: ASSEMBLE_ABI
      }
    },
    480: { // World Chain
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 1000000,
        abi: ASSEMBLE_ABI
      }
    },
    747: { // Flow EVM
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 1000000,
        abi: ASSEMBLE_ABI
      }
    },
    11155111: { // Sepolia
      assemble: {
        address: '0x00000004FE7c1E461A1703AF603F1A5F080Be253',
        startBlock: 5000000,
        abi: ASSEMBLE_ABI
      }
    }
  },
  events: {
    EventCreated: {
      signature: 'EventCreated(uint256,address,string,uint256,uint256,uint8)',
      processor: 'EventCreatedProcessor'
    },
    TicketPurchased: {
      signature: 'TicketPurchased(uint256,uint256,address,uint256,uint256,uint256,address)',
      processor: 'TicketPurchasedProcessor'
    },
    EventTipped: {
      signature: 'EventTipped(uint256,address,uint256,uint256,address)',
      processor: 'EventTippedProcessor'
    },
    CheckedIn: {
      signature: 'CheckedIn(uint256,address)',
      processor: 'CheckedInProcessor'
    },
    FriendAdded: {
      signature: 'FriendAdded(address,address)',
      processor: 'FriendAddedProcessor'
    },
    RSVPUpdated: {
      signature: 'RSVPUpdated(uint256,address,uint8)',
      processor: 'RSVPUpdatedProcessor'
    },
    CommentPosted: {
      signature: 'CommentPosted(uint256,uint256,address,string,uint256)',
      processor: 'CommentPostedProcessor'
    },
    InvitationSent: {
      signature: 'InvitationSent(uint256,address,address)',
      processor: 'InvitationSentProcessor'
    },
    // ERC-6909 Multi-token events
    Transfer: {
      signature: 'Transfer(address,address,address,uint256,uint256)',
      processor: 'ERC6909TransferProcessor'
    }
  },
  tokenTypes: {
    EVENT_TICKET: 0,
    ATTENDANCE_BADGE: 1,
    ORGANIZER_CRED: 2
  },
  retry: {
    maxRetries: 5,
    baseDelay: 1000,
    maxDelay: 30000,
    backoffMultiplier: 2,
    jitter: true,
    retryableErrors: ['network', 'timeout', 'rate limit', 'internal server error']
  }
};
```

### Environment Configuration (Updated)
```bash
# Database
DATABASE_URL="mongodb+srv://theo:UsSUjbCN8MLEwgCt@assemble.ilxfxkn.mongodb.net/?retryWrites=true&w=majority&appName=assemble"

# RPC URLs for actual supported chains
ETHEREUM_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/..."
WORLDCHAIN_RPC_URL="https://worldchain-mainnet.g.alchemy.com/v2/..."
FLOW_RPC_URL="https://flow-mainnet.g.alchemy.com/v2/..."
SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/..."

# Assemble Protocol Contract (same address on all chains)
ASSEMBLE_CONTRACT_ADDRESS="0x00000004FE7c1E461A1703AF603F1A5F080Be253"

# API Configuration
GRAPHQL_PORT=4000
GRAPHQL_PLAYGROUND=true

# Indexer Configuration
MAX_RETRIES=5
RETRY_BASE_DELAY=1000
RETRY_MAX_DELAY=30000
CIRCUIT_BREAKER_FAILURE_THRESHOLD=5
METRICS_UPDATE_FREQUENCY=30000

# Logging
LOG_LEVEL=info
```

## Deployment & Operations

### Production Deployment
- **Environment**: Node.js production server
- **Database**: MongoDB Atlas (existing connection)
- **Monitoring**: Application metrics and health checks
- **Scaling**: Horizontal scaling for multiple chains

### Data Migration Strategy
- Prisma migrations for schema changes
- Backfill scripts for historical data
- Chain-specific indexing state management

### Error Handling
- Automatic retry mechanisms for failed RPC calls
- Circuit breakers for unhealthy endpoints
- Dead letter queues for failed event processing
- Graceful degradation for chain outages
- Comprehensive error logging and alerting
- Memory leak prevention and cleanup

## Success Metrics

### Technical KPIs
- **Indexing Latency**: < 30 seconds from blockchain to API
- **API Response Time**: < 200ms for standard queries
- **Uptime**: 99.9% availability
- **Data Accuracy**: 100% event capture rate
- **Memory Stability**: No memory leaks detected
- **Error Rate**: < 0.1% event processing errors

### Business KPIs
- **Query Performance**: Support for complex Relay queries
- **Real-time Updates**: Live data for frontend
- **Multi-chain Coverage**: All supported Assemble Protocol chains
- **Developer Experience**: Easy to extend and maintain

## Future Enhancements

### Phase 2 Features
- Real-time subscriptions via GraphQL subscriptions
- Advanced analytics and reporting
- Data export capabilities
- Admin dashboard for monitoring
- Cross-protocol compatibility layer

### Scalability Considerations
- Database sharding strategies
- Caching layer implementation
- CDN integration for static data
- Microservice architecture migration
- Event sourcing for audit trails

---

This PRD provides a comprehensive blueprint for building the Assemble Protocol Indexer following the exact patterns and architecture of the [ponderfinance/ponder-indexer](https://github.com/ponderfinance/ponder-indexer/) repository while serving the specific needs of the Assemble Protocol ecosystem. The architecture is designed to be **protocol-agnostic at its core**, allowing for maximum code reuse and easy adaptation to other protocols in the future.