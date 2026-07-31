import {
  getWalletSummary,
  listWalletCoins,
  listWalletObjects,
  loadExecutorKeypair,
} from './blockchain-client.mjs';

const {
  executorAddress,
} = loadExecutorKeypair();

console.log(
  '===== WALLET SUMMARY =====',
);

console.log(
  JSON.stringify(
    await getWalletSummary(),
    null,
    2,
  ),
);

console.log(
  '===== COINS =====',
);

const coins =
  await listWalletCoins(
    executorAddress,
    {
      limit: 10,
    },
  );

console.log(
  JSON.stringify(
    {
      ...coins,
      raw: undefined,
    },
    null,
    2,
  ),
);

console.log(
  '===== OWNED OBJECTS =====',
);

const objects =
  await listWalletObjects(
    executorAddress,
    {
      limit: 10,
    },
  );

console.log(
  JSON.stringify(
    {
      ...objects,
      raw: undefined,
    },
    null,
    2,
  ),
);
