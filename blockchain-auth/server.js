const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const fs = require('fs');

const app = express();

const PORT = 8120;
const HOST = '127.0.0.1';

const MONGO_URL =
  process.env.MONGODB_URL || 'mongodb://localhost:27017/tob';

const JWT_SECRET = fs
  .readFileSync('/home/boshin57/Tobmate_Live/.blockchain_jwt_secret', 'utf8')
  .trim();

app.use(express.json({ limit: '20kb' }));

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'tobmate-blockchain-auth'
  });
});

app.post('/auth/login', async (req, res) => {
  try {
    const userId = String(req.body.user_id || '').trim();
    const password = String(req.body.password || '');

    if (!userId || !password) {
      return res.status(400).json({
        ok: false,
        error: 'MISSING_CREDENTIALS'
      });
    }

    const users = mongoose.connection.collection('users');

    const user = await users.findOne(
      { user_id: userId },
      {
        projection: {
          user_id: 1,
          password: 1,
          role: 1
        }
      }
    );

    if (!user || !user.password) {
      return res.status(401).json({
        ok: false,
        error: 'INVALID_CREDENTIALS'
      });
    }

    const valid = await bcrypt.compare(
      password,
      user.password
    );

    if (!valid) {
      return res.status(401).json({
        ok: false,
        error: 'INVALID_CREDENTIALS'
      });
    }

    const token = jwt.sign(
      {
        sub: user.user_id,
        type: 'blockchain-auth'
      },
      JWT_SECRET,
      {
        algorithm: 'HS256',
        expiresIn: '15m',
        issuer: 'tobmate.com',
        audience: 'tobmate-blockchain'
      }
    );

    return res.json({
      ok: true,
      user_id: user.user_id,
      token,
      expires_in: 900
    });

  } catch (err) {
    console.error(
      '[BLOCKCHAIN_AUTH_ERROR]',
      err.message
    );

    return res.status(500).json({
      ok: false,
      error: 'INTERNAL_ERROR'
    });
  }
});
const walletChallenges = new Map();

function requireBlockchainAuth(req, res, next) {
  try {
    const header = String(req.headers.authorization || '');

    if (!header.startsWith('Bearer ')) {
      return res.status(401).json({
        ok: false,
        error: 'AUTH_REQUIRED'
      });
    }

    const token = header.slice(7);

    const payload = jwt.verify(token, JWT_SECRET, {
      algorithms: ['HS256'],
      issuer: 'tobmate.com',
      audience: 'tobmate-blockchain'
    });

    if (payload.type !== 'blockchain-auth') {
      throw new Error('INVALID_TOKEN_TYPE');
    }

    req.blockchainUser = payload.sub;
    next();

  } catch (err) {
    return res.status(401).json({
      ok: false,
      error: 'INVALID_OR_EXPIRED_TOKEN'
    });
  }
}

app.post(
  '/wallet/challenge',
  requireBlockchainAuth,
  (req, res) => {

    const crypto = require('crypto');
    const userId = req.blockchainUser;

    const nonce = crypto.randomBytes(32).toString('hex');
    const expiresAt = Date.now() + 5 * 60 * 1000;

    const message =
      'TOBMATE Wallet Binding\n' +
      'TMID: ' + userId + '\n' +
      'Nonce: ' + nonce + '\n' +
      'Expires: ' + expiresAt;

    walletChallenges.set(userId, {
      message,
      expiresAt,
      used: false
    });

    res.json({
      ok: true,
      message,
      expires_at: expiresAt
    });
  }
);
app.post(
  '/wallet/bind',
  requireBlockchainAuth,
  async (req, res) => {
    try {
      const userId = req.blockchainUser;
      const address = String(req.body.address || '').trim();
      const signature = String(req.body.signature || '').trim();

      if (!address || !signature) {
        return res.status(400).json({
          ok: false,
          error: 'MISSING_WALLET_PROOF'
        });
      }

      const challenge = walletChallenges.get(userId);

      if (!challenge) {
        return res.status(400).json({
          ok: false,
          error: 'CHALLENGE_NOT_FOUND'
        });
      }

      if (challenge.used) {
        return res.status(400).json({
          ok: false,
          error: 'CHALLENGE_ALREADY_USED'
        });
      }

      if (Date.now() > challenge.expiresAt) {
        walletChallenges.delete(userId);

        return res.status(400).json({
          ok: false,
          error: 'CHALLENGE_EXPIRED'
        });
      }

      const {
        verifyPersonalMessageSignature
      } = await import('@mysten/sui/verify');

      const publicKey =
        await verifyPersonalMessageSignature(
          new TextEncoder().encode(challenge.message),
          signature
        );

      const verifiedAddress = publicKey.toSuiAddress();

      if (
        verifiedAddress.toLowerCase() !==
        address.toLowerCase()
      ) {
        return res.status(401).json({
          ok: false,
          error: 'WALLET_SIGNATURE_MISMATCH'
        });
      }

      const bindings =
        mongoose.connection.collection('wallet_bindings');

      const existing = await bindings.findOne({
        address: verifiedAddress
      });

      if (existing && existing.user_id !== userId) {
        return res.status(409).json({
          ok: false,
          error: 'WALLET_ALREADY_BOUND'
        });
      }

      await bindings.updateOne(
        { user_id: userId },
        {
          $set: {
            user_id: userId,
            address: verifiedAddress,
            network: 'sui',
            status: 'active',
            verified_at: new Date(),
            updated_at: new Date()
          },
          $setOnInsert: {
            created_at: new Date()
          }
        },
        { upsert: true }
      );

      challenge.used = true;

      return res.json({
        ok: true,
        user_id: userId,
        address: verifiedAddress,
        status: 'BOUND'
      });

    } catch (err) {
      console.error(
        '[WALLET_BIND_ERROR]',
        err.message
      );

      return res.status(401).json({
        ok: false,
        error: 'WALLET_SIGNATURE_INVALID'
      });
    }
  }
);
async function start() {
  await mongoose.connect(MONGO_URL);

  app.listen(PORT, HOST, () => {
    console.log(
      `TOBMATE Blockchain Auth listening on ${HOST}:${PORT}`
    );
  });
}

start().catch((err) => {
  console.error(
    'Blockchain Auth startup failed:',
    err.message
  );
  process.exit(1);
});
