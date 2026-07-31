import { SuiGrpcClient } from '@mysten/sui/grpc';
import { Transaction } from '@mysten/sui/transactions';

const NETWORK = process.env.SUI_NETWORK || 'testnet';
const BASE_URL =
  process.env.SUI_GRPC_URL ||
  'https://fullnode.testnet.sui.io:443';

const client = new SuiGrpcClient({
  network: NETWORK,
  baseUrl: BASE_URL
});

const tx = new Transaction();

console.log(JSON.stringify({
  ok: true,
  module: 'tobmate-sui-executor',
  network: NETWORK,
  grpc_url: BASE_URL,
  client_ready: Boolean(client),
  transaction_ready: Boolean(tx)
}));

try {
  const epochResult =
    await client.ledgerService.getEpoch({});

  console.log(JSON.stringify({
    ok: true,
    grpc_connected: true,
    epoch_response: Boolean(epochResult)
  }));
} catch (error) {
  console.error(JSON.stringify({
    ok: false,
    grpc_connected: false,
    error: String(error?.message || error)
  }));
  process.exitCode = 1;
}
