import { WebCryptoSigner } from '@mysten/webcrypto-signer';
import { get, set } from 'idb-keyval';

const KEY = 'tobmate-sui-wallet-v1';

async function loadSigner() {
  const saved = await get(KEY);

  if (!saved) return null;

  return await WebCryptoSigner.import(saved);
}

async function createSigner() {
  const signer = await WebCryptoSigner.generate();

  // 비밀키 자체가 아니라 WebCrypto key reference를 IndexedDB에 저장
  await set(KEY, signer.export());

  return signer;
}

async function getOrCreateSigner() {
  return (await loadSigner()) || (await createSigner());
}

window.TobmateWallet = {

  async create() {
    const signer = await getOrCreateSigner();
    const address = signer.toSuiAddress();

    return {
      address,
      scheme: signer.getKeyScheme()
    };
  },

  async signMessage(message) {
    const signer = await loadSigner();

    if (!signer) {
      throw new Error('Wallet not created');
    }

    const bytes = new TextEncoder().encode(message);

    return await signer.signPersonalMessage(bytes);
  },

  async getAddress() {
    const signer = await loadSigner();

    return signer ? signer.toSuiAddress() : null;
  }

};
