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

const passkeyChallenges = new Map();

app.post(
  '/passkey/register/options',
  requireBlockchainAuth,
  async (req, res) => {
    try {
      const userId = req.blockchainUser;

      const { generateRegistrationOptions } =
        await import('@simplewebauthn/server');

      const helpers =
        await import('@simplewebauthn/server/helpers');

      const passkeys =
        mongoose.connection.collection('passkeys');

      const existing = await passkeys
        .find({ user_id: userId })
        .toArray();

      const options =
        await generateRegistrationOptions({
          rpName: 'TOBMATE',
          rpID: 'tobmate.com',
          userName: userId,

          userID:
            helpers.isoUint8Array.fromUTF8String(
              'tmid:' + userId
            ),

          attestationType: 'none',

          excludeCredentials:
            existing.map((p) => ({
              id: p.credential_id,
              transports: p.transports || []
            })),

          authenticatorSelection: {
            residentKey: 'preferred',
            userVerification: 'required'
          }
        });

      passkeyChallenges.set(userId, {
        challenge: options.challenge,
        expiresAt: Date.now() + 5 * 60 * 1000
      });

      return res.json({
        ok: true,
        options
      });

    } catch (err) {
      console.error(
        '[PASSKEY_OPTIONS_ERROR]',
        err.message
      );

      return res.status(500).json({
        ok: false,
        error: 'PASSKEY_OPTIONS_FAILED'
      });
    }
  }
);


app.post(
  '/passkey/register/verify',
  requireBlockchainAuth,
  async (req, res) => {
    try {
      const userId = req.blockchainUser;

      const pending = passkeyChallenges.get(userId);

      if (!pending) {
        return res.status(400).json({
          ok: false,
          error: 'PASSKEY_CHALLENGE_NOT_FOUND'
        });
      }

      if (Date.now() > pending.expiresAt) {
        passkeyChallenges.delete(userId);

        return res.status(400).json({
          ok: false,
          error: 'PASSKEY_CHALLENGE_EXPIRED'
        });
      }

      const {
        verifyRegistrationResponse
      } = await import('@simplewebauthn/server');

      const verification =
        await verifyRegistrationResponse({
          response: req.body,
          expectedChallenge: pending.challenge,
          expectedOrigin: 'https://tobmate.com',
          expectedRPID: 'tobmate.com',
          requireUserVerification: true
        });

      if (!verification.verified ||
          !verification.registrationInfo) {
        return res.status(400).json({
          ok: false,
          error: 'PASSKEY_REGISTRATION_NOT_VERIFIED'
        });
      }

      const {
        credential,
        credentialDeviceType,
        credentialBackedUp
      } = verification.registrationInfo;

      const passkeys =
        mongoose.connection.collection('passkeys');

      await passkeys.updateOne(
        {
          user_id: userId,
          credential_id: credential.id
        },
        {
          $set: {
            user_id: userId,
            credential_id: credential.id,
            public_key:
              Buffer.from(credential.publicKey),
            counter: credential.counter,
            transports:
              credential.transports || [],
            device_type:
              credentialDeviceType,
            backed_up:
              credentialBackedUp,
            status: 'active',
            updated_at: new Date()
          },
          $setOnInsert: {
            created_at: new Date()
          }
        },
        { upsert: true }
      );

      passkeyChallenges.delete(userId);

      return res.json({
        ok: true,
        status: 'PASSKEY_REGISTERED'
      });

    } catch (err) {
      console.error(
        '[PASSKEY_VERIFY_ERROR]',
        err.message
      );

      return res.status(400).json({
        ok: false,
        error: 'PASSKEY_VERIFY_FAILED'
      });
    }
  }
);


const transactionChallenges = new Map();

app.post(
  '/transaction/challenge',
  requireBlockchainAuth,
  async (req, res) => {
    try {
      const userId = req.blockchainUser;
      const action = String(req.body.action || '').trim();
      const payload = req.body.payload || {};

      if (!action) {
        return res.status(400).json({
          ok: false,
          error: 'ACTION_REQUIRED'
        });
      }

      const passkeys =
        mongoose.connection.collection('passkeys');

      const userPasskeys = await passkeys.find({
        user_id: userId,
        status: 'active'
      }).toArray();

      if (!userPasskeys.length) {
        return res.status(400).json({
          ok: false,
          error: 'PASSKEY_NOT_REGISTERED'
        });
      }

      const { generateAuthenticationOptions } =
        await import('@simplewebauthn/server');

      const options =
        await generateAuthenticationOptions({
          rpID: 'tobmate.com',
          userVerification: 'required',
          allowCredentials: userPasskeys.map((p) => ({
            id: p.credential_id,
            transports: p.transports || []
          }))
        });

      const crypto = require('crypto');
      const txId = crypto.randomUUID();

      const payloadHash =
        crypto.createHash('sha256')
          .update(JSON.stringify(payload))
          .digest('hex');

      const expiresAt =
        new Date(Date.now() + 5 * 60 * 1000);

      await mongoose.connection
        .collection('transaction_authorizations')
        .insertOne({
          user_id: userId,
          tx_id: txId,
          action,
          network: 'sui',
          payload_hash: payloadHash,
          challenge: options.challenge,
          status: 'PENDING',
          created_at: new Date(),
          expires_at: expiresAt
        });

      return res.json({
        ok: true,
        tx_id: txId,
        options
      });

    } catch (err) {
      console.error(
        '[TX_CHALLENGE_ERROR]',
        err.message
      );

      return res.status(500).json({
        ok: false,
        error: 'TX_CHALLENGE_FAILED'
      });
    }
  }
);

app.post(
  '/transaction/authorize',
  requireBlockchainAuth,
  async (req,res)=>{
    try {
      const userId=req.blockchainUser;
      const txId=String(req.body.tx_id||'').trim();
      const response=req.body.response;

      if(!txId || !response){
        return res.status(400).json({
          ok:false,
          error:'TX_ID_AND_RESPONSE_REQUIRED'
        });
      }

      const txs=mongoose.connection
        .collection('transaction_authorizations');

      const tx=await txs.findOne({
        tx_id:txId,
        user_id:userId
      });

      if(!tx){
        return res.status(404).json({
          ok:false,
          error:'TX_NOT_FOUND'
        });
      }

      if(tx.status!=='PENDING'){
        return res.status(400).json({
          ok:false,
          error:'TX_NOT_PENDING'
        });
      }

      if(new Date()>tx.expires_at){
        await txs.updateOne(
          {tx_id:txId,user_id:userId},
          {$set:{status:'EXPIRED'}}
        );

        return res.status(400).json({
          ok:false,
          error:'TX_EXPIRED'
        });
      }

      const passkeys=
        mongoose.connection.collection('passkeys');

      const passkey=await passkeys.findOne({
        user_id:userId,
        credential_id:response.id,
        status:'active'
      });

      if(!passkey){
        return res.status(401).json({
          ok:false,
          error:'PASSKEY_NOT_FOUND'
        });
      }

      const {verifyAuthenticationResponse}=
        await import('@simplewebauthn/server');

      const publicKey=
        new Uint8Array(passkey.public_key.buffer);

      const verification=
        await verifyAuthenticationResponse({
          response,
          expectedChallenge:tx.challenge,
          expectedOrigin:'https://tobmate.com',
          expectedRPID:'tobmate.com',
          requireUserVerification:true,
          credential:{
            id:passkey.credential_id,
            publicKey,
            counter:Number(passkey.counter||0),
            transports:passkey.transports||[]
          }
        });

      if(!verification.verified){
        return res.status(401).json({
          ok:false,
          error:'PASSKEY_AUTHENTICATION_FAILED'
        });
      }

      const newCounter=
        verification.authenticationInfo.newCounter;

      await passkeys.updateOne(
        {
          user_id:userId,
          credential_id:passkey.credential_id
        },
        {
          $set:{
            counter:newCounter,
            last_used_at:new Date()
          }
        }
      );

      const result=await txs.updateOne(
        {
          tx_id:txId,
          user_id:userId,
          status:'PENDING'
        },
        {
          $set:{
            status:'AUTHORIZED',
            authorized_at:new Date()
          }
        }
      );

      if(result.modifiedCount!==1){
        return res.status(409).json({
          ok:false,
          error:'TX_STATE_CHANGED'
        });
      }

      return res.json({
        ok:true,
        tx_id:txId,
        status:'AUTHORIZED'
      });

    }catch(err){
      console.error(
        '[TX_AUTHORIZE_ERROR]',
        err.message
      );

      return res.status(401).json({
        ok:false,
        error:'TX_PASSKEY_VERIFY_FAILED'
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
