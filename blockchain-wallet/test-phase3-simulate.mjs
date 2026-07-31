import {
  simulateTransaction,
} from './blockchain-transaction.mjs';

console.log(
  '===== PHASE 3A GRPC SIMULATION =====',
);

try {
  const result =
    await simulateTransaction({
      kind: 'self-transfer',
      amountMist: '1',
      gasBudget: '10000000',
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
    'PHASE 3A SIMULATION FAILED',
  );

  console.error(
    error?.stack ??
    error?.message ??
    error,
  );

  process.exitCode = 1;
}
