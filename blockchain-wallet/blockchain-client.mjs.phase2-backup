import fs from 'node:fs';

import {
  SuiGrpcClient,
} from '@mysten/sui/grpc';

import {
  Ed25519Keypair,
} from '@mysten/sui/keypairs/ed25519';

export const DEFAULT_NETWORK = 'testnet';

export const DEFAULT_GRPC_URL =
  'https://fullnode.testnet.sui.io:443';

export const DEFAULT_EXECUTOR_KEY_FILE =
  '/home/boshin57/Tobmate_Live/.sui_testnet_executor_key';

export const SUI_COIN_TYPE =
  '0x2::sui::SUI';

export const MIST_PER_SUI =
  1_000_000_000n;

function normalizeNetwork(value) {
  const network = String(
    value || DEFAULT_NETWORK,
  )
    .trim()
    .toLowerCase();

  const supported = new Set([
    'testnet',
    'mainnet',
    'devnet',
    'localnet',
  ]);

  if (!supported.has(network)) {
    throw new Error(
      `Unsupported Sui network: ${network}`,
    );
  }

  return network;
}

function normalizeBaseUrl(value) {
  const baseUrl = String(
    value || DEFAULT_GRPC_URL,
  ).trim();

  if (!baseUrl) {
    throw new Error(
      'Sui gRPC base URL is empty',
    );
  }

  return baseUrl;
}

export function formatMistAsSui(rawValue) {
  const raw = BigInt(
    rawValue ?? '0',
  );

  const whole =
    raw / MIST_PER_SUI;

  const fraction =
    (raw % MIST_PER_SUI)
      .toString()
      .padStart(9, '0')
      .replace(/0+$/, '');

  return fraction
    ? `${whole}.${fraction}`
    : `${whole}.00`;
}

export function createBlockchainClient() {
  const network =
    normalizeNetwork(
      process.env.SUI_NETWORK,
    );

  const baseUrl =
    normalizeBaseUrl(
      process.env.SUI_GRPC_URL ||
      process.env.SUI_FULLNODE,
    );

  const client =
    new SuiGrpcClient({
      network,
      baseUrl,
    });

  return {
    client,
    network,
    baseUrl,
    transport: 'grpc',
  };
}

export function loadExecutorKeypair() {
  const keyFile = String(
    process.env.SUI_EXECUTOR_KEY_FILE ||
    DEFAULT_EXECUTOR_KEY_FILE,
  ).trim();

  if (!fs.existsSync(keyFile)) {
    throw new Error(
      `Executor key file not found: ${keyFile}`,
    );
  }

  const secret =
    fs.readFileSync(
      keyFile,
      'utf8',
    ).trim();

  if (!secret) {
    throw new Error(
      'Executor key file is empty',
    );
  }

  const keypair =
    Ed25519Keypair.fromSecretKey(
      secret,
    );

  return {
    keyFile,
    keypair,
    executorAddress:
      keypair.toSuiAddress(),
  };
}

export async function getSuiBalance(
  owner,
  coinType = SUI_COIN_TYPE,
) {
  const {
    client,
    network,
    baseUrl,
    transport,
  } = createBlockchainClient();

  const response =
    await client.getBalance({
      owner,
      coinType,
    });

  const balance =
    response?.balance;

  if (!balance) {
    throw new Error(
      'Sui gRPC balance response is missing balance data',
    );
  }

  const balanceRaw = String(
    balance.balance ??
    balance.coinBalance ??
    '0',
  );

  return {
    network,
    baseUrl,
    transport,
    owner,
    balanceRaw,
    balanceSui:
      formatMistAsSui(
        balanceRaw,
      ),
    coinBalance: String(
      balance.coinBalance ??
      balanceRaw,
    ),
    addressBalance: String(
      balance.addressBalance ??
      '0',
    ),
    coinType:
      balance.coinType ||
      coinType,
    raw: response,
  };
}

function toSafeString(value, fallback = '') {
  if (value === null || value === undefined) {
    return fallback;
  }

  if (typeof value === 'bigint') {
    return value.toString();
  }

  if (
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return String(value);
  }

  return fallback;
}

function normalizeCursor(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === 'string') {
    return value || null;
  }

  if (typeof value === 'object') {
    return (
      value.cursor ??
      value.nextCursor ??
      value.objectId ??
      value.objectID ??
      null
    );
  }

  return String(value);
}

export async function listWalletBalances(owner) {
  const {
    client,
    network,
    baseUrl,
    transport,
  } = createBlockchainClient();

  const response =
    await client.listBalances({
      owner,
    });

  const balances =
    Array.isArray(response?.balances)
      ? response.balances
      : [];

  return {
    network,
    baseUrl,
    transport,
    owner,
    balances: balances.map(
      (item) => {
        const rawBalance =
          toSafeString(
            item?.balance ??
            item?.coinBalance ??
            '0',
            '0',
          );

        return {
          coinType:
            toSafeString(
              item?.coinType,
            ),
          balanceRaw:
            rawBalance,
          balanceFormatted:
            item?.coinType?.endsWith(
              '::sui::SUI',
            )
              ? formatMistAsSui(
                  rawBalance,
                )
              : rawBalance,
          coinBalance:
            toSafeString(
              item?.coinBalance ??
              rawBalance,
              '0',
            ),
          addressBalance:
            toSafeString(
              item?.addressBalance ??
              '0',
              '0',
            ),
        };
      },
    ),
    balanceTypeCount:
      balances.length,
    raw: response,
  };
}

export async function listWalletCoins(
  owner,
  {
    coinType = SUI_COIN_TYPE,
    limit = 50,
    cursor = null,
  } = {},
) {
  const {
    client,
    network,
    baseUrl,
    transport,
  } = createBlockchainClient();

  const safeLimit =
    Math.min(
      Math.max(
        Number.parseInt(
          String(limit),
          10,
        ) || 50,
        1,
      ),
      100,
    );

  const request = {
    owner,
    coinType,
    limit: safeLimit,
  };

  if (cursor) {
    request.cursor = cursor;
  }

  const response =
    await client.listCoins(
      request,
    );

  const objects =
    Array.isArray(response?.objects)
      ? response.objects
      : Array.isArray(response?.coins)
        ? response.coins
        : [];

  return {
    network,
    baseUrl,
    transport,
    owner,
    coinType,
    limit: safeLimit,
    count: objects.length,
    hasNextPage:
      Boolean(
        response?.hasNextPage ??
        response?.hasNext,
      ),
    nextCursor:
      normalizeCursor(
        response?.cursor ??
        response?.nextCursor,
      ),
    coins: objects.map(
      (coin) => ({
        objectId:
          toSafeString(
            coin?.objectId ??
            coin?.coinObjectId ??
            coin?.object?.objectId,
          ),
        version:
          toSafeString(
            coin?.version ??
            coin?.object?.version,
          ),
        digest:
          toSafeString(
            coin?.digest ??
            coin?.object?.digest,
          ),
        balanceRaw:
          toSafeString(
            coin?.balance ??
            coin?.coinBalance ??
            '0',
            '0',
          ),
        balanceFormatted:
          coinType.endsWith(
            '::sui::SUI',
          )
            ? formatMistAsSui(
                coin?.balance ??
                coin?.coinBalance ??
                '0',
              )
            : toSafeString(
                coin?.balance ??
                coin?.coinBalance ??
                '0',
                '0',
              ),
        coinType:
          toSafeString(
            coin?.coinType ??
            coinType,
          ),
        previousTransaction:
          toSafeString(
            coin?.previousTransaction,
          ),
      }),
    ),
    raw: response,
  };
}

export async function listWalletObjects(
  owner,
  {
    limit = 50,
    cursor = null,
  } = {},
) {
  const {
    client,
    network,
    baseUrl,
    transport,
  } = createBlockchainClient();

  const safeLimit =
    Math.min(
      Math.max(
        Number.parseInt(
          String(limit),
          10,
        ) || 50,
        1,
      ),
      100,
    );

  const request = {
    owner,
    limit: safeLimit,
  };

  if (cursor) {
    request.cursor = cursor;
  }

  const response =
    await client.listOwnedObjects(
      request,
    );

  const objects =
    Array.isArray(response?.objects)
      ? response.objects
      : Array.isArray(response?.data)
        ? response.data
        : [];

  return {
    network,
    baseUrl,
    transport,
    owner,
    limit: safeLimit,
    count: objects.length,
    hasNextPage:
      Boolean(
        response?.hasNextPage ??
        response?.hasNext,
      ),
    nextCursor:
      normalizeCursor(
        response?.cursor ??
        response?.nextCursor,
      ),
    objects: objects.map(
      (item) => {
        const object =
          item?.object ??
          item?.data ??
          item;

        return {
          objectId:
            toSafeString(
              object?.objectId ??
              object?.objectID ??
              object?.id,
            ),
          version:
            toSafeString(
              object?.version,
            ),
          digest:
            toSafeString(
              object?.digest,
            ),
          type:
            toSafeString(
              object?.type ??
              object?.objectType,
            ),
          owner:
            object?.owner ??
            null,
          previousTransaction:
            toSafeString(
              object?.previousTransaction,
            ),
        };
      },
    ),
    raw: response,
  };
}

export async function getWalletSummary() {
  const {
    executorAddress,
  } = loadExecutorKeypair();

  const [
    balances,
    coins,
    objects,
  ] = await Promise.all([
    listWalletBalances(
      executorAddress,
    ),
    listWalletCoins(
      executorAddress,
      {
        coinType:
          SUI_COIN_TYPE,
        limit: 50,
      },
    ),
    listWalletObjects(
      executorAddress,
      {
        limit: 50,
      },
    ),
  ]);

  const suiBalance =
    balances.balances.find(
      (item) =>
        item.coinType.endsWith(
          '::sui::SUI',
        ),
    ) ?? null;

  return {
    ok: true,
    service:
      'tobmate-blockchain-hub',
    transport:
      balances.transport,
    network:
      balances.network,
    address:
      executorAddress,
    suiBalance:
      suiBalance,
    balanceTypeCount:
      balances.balanceTypeCount,
    coinCount:
      coins.count,
    objectCount:
      objects.count,
    coinPageHasNext:
      coins.hasNextPage,
    objectPageHasNext:
      objects.hasNextPage,
    checkedAt:
      new Date().toISOString(),
  };
}
