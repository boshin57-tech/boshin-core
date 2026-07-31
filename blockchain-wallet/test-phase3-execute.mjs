import {
  executeTransaction,
} from './blockchain-transaction.mjs';

console.log(
  '===== PHASE 3B GRPC EXECUTION =====',
);

try {
  const result =
    await executeTransaction({
      kind: 'self-transfer',
      amountMist: '1',
      gasBudget: '10000000',
      confirmation:
        'EXECUTE_TESTNET_SELF_TRANSFER',
    });

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
} catch (error) {
  console.error(
    'PHASE 3B EXECUTION FAILED',
  );

  console.error(
    error?.stack ??
    error?.message ??
    error,
  );

  process.exitCode = 1;
}
