import { Transaction } from '@mysten/sui/transactions';

import {
  createBlockchainClient,
  loadExecutorKeypair,
} from './blockchain-client.mjs';

const DEFAULT_GAS_BUDGET = 10_000_000n;
const MIN_GAS_BUDGET = 1_000_000n;
const MAX_GAS_BUDGET = 100_000_000n;

const DEFAULT_TRANSFER_MIST = 1n;
const MAX_TRANSFER_MIST = 1_000_000_000n;

const EXECUTION_CONFIRMATION =
  'EXECUTE_TESTNET_SELF_TRANSFER';

function safeJson(value) {
  return JSON.parse(
    JSON.stringify(
      value,
      (_, currentValue) => {
        if (typeof currentValue === 'bigint') {
          return currentValue.toString();
        }

        if (currentValue instanceof Uint8Array) {
          return Array.from(currentValue);
        }

        return currentValue;
      },
    ),
  );
}

function normalizeUnsignedInteger(
  value,
  fieldName,
  {
    minimum = 0n,
    maximum = null,
    defaultValue = null,
  } = {},
) {
  const candidate =
    value === undefined ||
    value === null ||
    value === ''
      ? defaultValue
      : value;

  if (candidate === null) {
    throw new Error(
      `${fieldName} is required`,
    );
  }

  let normalized;

  try {
    normalized = BigInt(candidate);
  } catch {
    throw new Error(
      `${fieldName} must be an integer`,
    );
  }

  if (normalized < minimum) {
    throw new Error(
      `${fieldName} must be at least ${minimum}`,
    );
  }

  if (
    maximum !== null &&
    normalized > maximum
  ) {
    throw new Error(
      `${fieldName} must not exceed ${maximum}`,
    );
  }

  return normalized;
}

function normalizeSuiAddress(
  value,
  fieldName = 'address',
) {
  if (typeof value !== 'string') {
    throw new Error(
      `${fieldName} must be a string`,
    );
  }

  const normalized = value.trim().toLowerCase();

  if (
    !/^0x[0-9a-f]{1,64}$/.test(normalized)
  ) {
    throw new Error(
      `${fieldName} must be a valid Sui address`,
    );
  }

  return normalized;
}

function normalizeTransactionKind(value) {
  const normalized =
    String(value ?? 'self-transfer')
      .trim()
      .toLowerCase();

  if (normalized !== 'self-transfer') {
    throw new Error(
      'Phase 3 supports only kind: self-transfer',
    );
  }

  return normalized;
}

function getRuntimeContext() {
  const blockchain =
    createBlockchainClient();

  if (
    !blockchain ||
    !blockchain.client
  ) {
    throw new Error(
      'Unable to initialize Sui gRPC client',
    );
  }

  const executor =
    loadExecutorKeypair();

  if (
    !executor ||
    !executor.keypair ||
    !executor.executorAddress
  ) {
    throw new Error(
      'Unable to initialize executor keypair',
    );
  }

  return {
    client: blockchain.client,
    network:
      blockchain.network ??
      process.env.SUI_NETWORK ??
      'testnet',
    transport:
      blockchain.transport ??
      'grpc',
    baseUrl:
      blockchain.baseUrl ??
      process.env.SUI_GRPC_URL ??
      null,
    keypair:
      executor.keypair,
    executorAddress:
      normalizeSuiAddress(
        executor.executorAddress,
        'executorAddress',
      ),
  };
}

function buildSelfTransferTransaction({
  sender,
  recipient,
  amountMist,
  gasBudget,
}) {
  const tx = new Transaction();

  tx.setSender(sender);
  tx.setGasBudget(gasBudget);

  const [splitCoin] =
    tx.splitCoins(
      tx.gas,
      [
        tx.pure.u64(amountMist),
      ],
    );

  tx.transferObjects(
    [splitCoin],
    recipient,
  );

  return tx;
}

function normalizeRequest({
  kind = 'self-transfer',
  recipient,
  amountMist = DEFAULT_TRANSFER_MIST,
  gasBudget = DEFAULT_GAS_BUDGET,
} = {}) {
  const runtime =
    getRuntimeContext();

  const transactionKind =
    normalizeTransactionKind(kind);

  const normalizedRecipient =
    normalizeSuiAddress(
      recipient ??
      runtime.executorAddress,
      'recipient',
    );

  const normalizedAmount =
    normalizeUnsignedInteger(
      amountMist,
      'amountMist',
      {
        minimum: 1n,
        maximum:
          MAX_TRANSFER_MIST,
        defaultValue:
          DEFAULT_TRANSFER_MIST,
      },
    );

  const normalizedGasBudget =
    normalizeUnsignedInteger(
      gasBudget,
      'gasBudget',
      {
        minimum:
          MIN_GAS_BUDGET,
        maximum:
          MAX_GAS_BUDGET,
        defaultValue:
          DEFAULT_GAS_BUDGET,
      },
    );

  const transaction =
    buildSelfTransferTransaction({
      sender:
        runtime.executorAddress,
      recipient:
        normalizedRecipient,
      amountMist:
        normalizedAmount,
      gasBudget:
        normalizedGasBudget,
    });

  return {
    ...runtime,
    transaction,
    transactionKind,
    recipient:
      normalizedRecipient,
    amountMist:
      normalizedAmount,
    gasBudget:
      normalizedGasBudget,
  };
}

function getFailureMessage(result) {
  return (
    result?.FailedTransaction
      ?.status
      ?.error
      ?.message ??
    result?.FailedTransaction
      ?.status
      ?.error ??
    result?.status
      ?.error
      ?.message ??
    result?.status
      ?.error ??
    null
  );
}

function getResultKind(result) {
  if (
    result?.$kind
  ) {
    return result.$kind;
  }

  if (
    result?.FailedTransaction
  ) {
    return 'FailedTransaction';
  }

  if (
    result?.Transaction
  ) {
    return 'Transaction';
  }

  return 'Unknown';
}

function getTransactionDigest(result) {
  return (
    result?.Transaction?.digest ??
    result?.digest ??
    null
  );
}

export async function simulateTransaction(
  input = {},
) {
  const context =
    normalizeRequest(input);

  const result =
    await context.client
      .simulateTransaction({
        transaction:
          context.transaction,
        include: {
          effects: true,
          events: true,
          balanceChanges: true,
          objectTypes: true,
          transaction: true,
          commandResults: true,
        },
      });

  const resultKind =
    getResultKind(result);

  const failure =
    getFailureMessage(result);

  return {
    ok:
      resultKind !==
        'FailedTransaction' &&
      !failure,

    service:
      'tobmate-blockchain-hub',

    phase: '3A',
    mode: 'simulation',
    transport:
      context.transport,
    network:
      context.network,
    baseUrl:
      context.baseUrl,

    transactionKind:
      context.transactionKind,

    sender:
      context.executorAddress,
    recipient:
      context.recipient,

    amountMist:
      context.amountMist.toString(),
    gasBudget:
      context.gasBudget.toString(),

    resultKind,
    failure,

    simulation:
      safeJson(result),

    checkedAt:
      new Date().toISOString(),
  };
}

export async function executeTransaction({
  confirmation,
  ...input
} = {}) {
  const context =
    normalizeRequest(input);

  if (
    context.network !== 'testnet'
  ) {
    throw new Error(
      'Phase 3 execution is restricted to testnet',
    );
  }

  if (
    process.env
      .SUI_TX_EXECUTION_ENABLED !==
    'true'
  ) {
    throw new Error(
      'Transaction execution is disabled. Set SUI_TX_EXECUTION_ENABLED=true',
    );
  }

  if (
    confirmation !==
    EXECUTION_CONFIRMATION
  ) {
    throw new Error(
      `confirmation must equal ${EXECUTION_CONFIRMATION}`,
    );
  }

  const result =
    await context.client
      .signAndExecuteTransaction({
        transaction:
          context.transaction,
        signer:
          context.keypair,
        include: {
          effects: true,
          events: true,
          balanceChanges: true,
          objectTypes: true,
          transaction: true,
        },
      });

  const resultKind =
    getResultKind(result);

  const failure =
    getFailureMessage(result);

  const digest =
    getTransactionDigest(result);

  if (
    resultKind !==
      'FailedTransaction' &&
    digest &&
    typeof context.client
      .waitForTransaction ===
      'function'
  ) {
    await context.client
      .waitForTransaction({
        result,
      });
  }

  return {
    ok:
      resultKind !==
        'FailedTransaction' &&
      !failure,

    service:
      'tobmate-blockchain-hub',

    phase: '3B',
    mode: 'execution',
    transport:
      context.transport,
    network:
      context.network,
    baseUrl:
      context.baseUrl,

    transactionKind:
      context.transactionKind,

    sender:
      context.executorAddress,
    recipient:
      context.recipient,

    amountMist:
      context.amountMist.toString(),
    gasBudget:
      context.gasBudget.toString(),

    resultKind,
    digest,
    failure,

    execution:
      safeJson(result),

    checkedAt:
      new Date().toISOString(),
  };
}

export function getPhase3Capabilities() {
  return {
    phase: 3,
    transport: 'grpc',
    supportedTransactions: [
      'self-transfer',
    ],
    endpoints: {
      simulate:
        'POST /api/blockchain/tx/simulate',
      execute:
        'POST /api/blockchain/tx/execute',
    },
    executionSafety: {
      network: 'testnet only',
      environmentVariable:
        'SUI_TX_EXECUTION_ENABLED=true',
      confirmation:
        EXECUTION_CONFIRMATION,
    },
  };
}
