import {
  createBlockchainClient,
  getSuiBalance,
  loadExecutorKeypair,
} from './blockchain-client.mjs';

export async function getBlockchainStatus() {
  const checkedAt =
    new Date().toISOString();

  try {
    const {
      client,
      network,
      baseUrl,
      transport,
    } = createBlockchainClient();

    const {
      executorAddress,
    } = loadExecutorKeypair();

    const [
      balance,
      referenceGasPrice,
    ] = await Promise.all([
      getSuiBalance(
        executorAddress,
      ),
      client.getReferenceGasPrice(),
    ]);

    return {
      ok: true,
      online: true,
      service:
        'tobmate-blockchain-hub',
      transport,
      network,
      baseUrl,
      executorAddress,
      balanceRaw:
        balance.balanceRaw,
      balanceSui:
        balance.balanceSui,
      coinBalance:
        balance.coinBalance,
      addressBalance:
        balance.addressBalance,
      coinType:
        balance.coinType,
      referenceGasPrice:
        String(
          referenceGasPrice?.referenceGasPrice ??
          referenceGasPrice?.gasPrice ??
          referenceGasPrice?.price ??
          referenceGasPrice?.value ??
          referenceGasPrice ??
          '',
        ),
      checkedAt,
    };
  } catch (error) {
    return {
      ok: false,
      online: false,
      service:
        'tobmate-blockchain-hub',
      transport: 'grpc',
      network:
        process.env.SUI_NETWORK ||
        'testnet',
      error:
        error instanceof Error
          ? error.message
          : String(error),
      checkedAt,
    };
  }
}

if (
  import.meta.url ===
  `file://${process.argv[1]}`
) {
  const result =
    await getBlockchainStatus();

  console.log(
    JSON.stringify(
      result,
      null,
      2,
    ),
  );

  if (!result.ok) {
    process.exitCode = 1;
  }
}
