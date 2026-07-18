'use strict';

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const { MongoClient } = require('mongodb');

const PORT = Number(process.env.PORT || 8111);
const HOST = process.env.HOST || '127.0.0.1';

const MONGODB_URL =
  process.env.MONGODB_URL ||
  process.env.MONGO_URI ||
  'mongodb://localhost:27017/tob';

const DATABASE_NAME = process.env.GSOS_DATABASE || 'tob';
const COLLECTION_NAME =
  process.env.GSOS_SPACES_COLLECTION || 'gsos_spaces';

const app = express();

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));

let client;
let database;
let spaces;

function slugify(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9가-힣._-]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function createGsapAddress(data, spaceId) {
  const country = slugify(data.country || 'global');
  const region = slugify(data.region || 'global');
  const city = slugify(data.city || 'global');
  const name = slugify(data.slug || data.name || spaceId);

  return `gsap://earth/${country}/${region}/${city}/${name}`;
}

function serialize(document) {
  if (!document) return null;

  const { _id, ...result } = document;

  return {
    ...result,
    mongoId: String(_id)
  };
}

async function connectDatabase() {
  client = new MongoClient(MONGODB_URL, {
    maxPoolSize: 20,
    serverSelectionTimeoutMS: 10000
  });

  await client.connect();

  database = client.db(DATABASE_NAME);
  spaces = database.collection(COLLECTION_NAME);

  await spaces.createIndex(
    { spaceId: 1 },
    { unique: true, name: 'spaceId_unique' }
  );

  await spaces.createIndex(
    { gsapAddress: 1 },
    { unique: true, name: 'gsapAddress_unique' }
  );

  await spaces.createIndex(
    { location: '2dsphere' },
    { sparse: true, name: 'location_2dsphere' }
  );

  await spaces.createIndex(
    { status: 1, visibility: 1, updatedAt: -1 },
    { name: 'space_discovery' }
  );

  console.log(
    `[Spatial Registry] MongoDB connected: ${DATABASE_NAME}.${COLLECTION_NAME}`
  );
}

app.get('/', async (req, res, next) => {
  try {
    const count = await spaces.countDocuments({
      status: { $ne: 'deleted' }
    });

    res.json({
      service: 'Spatial Registry',
      status: 'online',
      storage: 'mongodb',
      database: DATABASE_NAME,
      collection: COLLECTION_NAME,
      spaces: count
    });
  } catch (error) {
    next(error);
  }
});

app.get('/health', async (req, res) => {
  try {
    await database.command({ ping: 1 });

    const count = await spaces.countDocuments({
      status: { $ne: 'deleted' }
    });

    res.json({
      ok: true,
      service: 'spatial-registry',
      storage: 'mongodb',
      databaseConnected: true,
      spaces: count,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      ok: false,
      service: 'spatial-registry',
      storage: 'mongodb',
      databaseConnected: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

app.get('/spaces', async (req, res, next) => {
  try {
    const filter = {
      status: { $ne: 'deleted' }
    };

    if (req.query.type) {
      filter.type = req.query.type;
    }

    if (req.query.visibility) {
      filter.visibility = req.query.visibility;
    }

    const limit = Math.min(
      Math.max(Number(req.query.limit) || 100, 1),
      500
    );

    const documents = await spaces
      .find(filter)
      .sort({ createdAt: -1 })
      .limit(limit)
      .toArray();

    res.json(documents.map(serialize));
  } catch (error) {
    next(error);
  }
});

app.get('/spaces/:spaceId', async (req, res, next) => {
  try {
    const document = await spaces.findOne({
      spaceId: req.params.spaceId,
      status: { $ne: 'deleted' }
    });

    if (!document) {
      return res.status(404).json({
        ok: false,
        error: 'SPACE_NOT_FOUND'
      });
    }

    res.json(serialize(document));
  } catch (error) {
    next(error);
  }
});

app.get('/resolve', async (req, res, next) => {
  try {
    const address = String(req.query.address || '').trim();

    if (!address) {
      return res.status(400).json({
        ok: false,
        error: 'GSAP_ADDRESS_REQUIRED'
      });
    }

    const document = await spaces.findOne({
      gsapAddress: address,
      status: { $ne: 'deleted' }
    });

    if (!document) {
      return res.status(404).json({
        ok: false,
        error: 'GSAP_ADDRESS_NOT_FOUND'
      });
    }

    res.json(serialize(document));
  } catch (error) {
    next(error);
  }
});

app.post('/spaces', async (req, res, next) => {
  try {
    const data = req.body || {};

    if (!data.name || !String(data.name).trim()) {
      return res.status(400).json({
        ok: false,
        error: 'NAME_REQUIRED'
      });
    }

    const spaceId =
      slugify(data.spaceId) ||
      `space-${crypto.randomUUID()}`;

    const latitude =
      data.latitude === null || data.latitude === undefined
        ? null
        : Number(data.latitude);

    const longitude =
      data.longitude === null || data.longitude === undefined
        ? null
        : Number(data.longitude);

    if (
      latitude !== null &&
      (!Number.isFinite(latitude) ||
        latitude < -90 ||
        latitude > 90)
    ) {
      return res.status(400).json({
        ok: false,
        error: 'INVALID_LATITUDE'
      });
    }

    if (
      longitude !== null &&
      (!Number.isFinite(longitude) ||
        longitude < -180 ||
        longitude > 180)
    ) {
      return res.status(400).json({
        ok: false,
        error: 'INVALID_LONGITUDE'
      });
    }

    const createdAt = new Date();

    const document = {
      spaceId,
      name: String(data.name).trim(),
      type: data.type || 'globe-grid',
      gsapAddress:
        data.gsapAddress ||
        createGsapAddress(data, spaceId),

      country: data.country || 'global',
      region: data.region || 'global',
      city: data.city || 'global',

      latitude,
      longitude,

      location:
        latitude !== null && longitude !== null
          ? {
              type: 'Point',
              coordinates: [longitude, latitude]
            }
          : undefined,

      grid: {
        x: Number(data.gridX ?? data.grid?.x ?? 0),
        y: Number(data.gridY ?? data.grid?.y ?? 0),
        z: Number(data.gridZ ?? data.grid?.z ?? 0),
        level: Number(data.gridLevel ?? data.grid?.level ?? 1)
      },

      ownerId: data.ownerId || 'system',
      targetUrl: data.targetUrl || '/',
      visibility: data.visibility || 'public',
      status: 'active',
      metadata: data.metadata || {},

      createdAt,
      updatedAt: createdAt
    };

    const result = await spaces.insertOne(document);

    res.status(201).json({
      ok: true,
      space: serialize({
        ...document,
        _id: result.insertedId
      })
    });
  } catch (error) {
    if (error && error.code === 11000) {
      return res.status(409).json({
        ok: false,
        error: 'SPACE_OR_GSAP_ALREADY_EXISTS',
        detail: error.keyValue
      });
    }

    next(error);
  }
});

app.put('/spaces/:spaceId', async (req, res, next) => {
  try {
    const data = req.body || {};
    const update = {
      updatedAt: new Date()
    };

    const allowedFields = [
      'name',
      'type',
      'gsapAddress',
      'country',
      'region',
      'city',
      'ownerId',
      'targetUrl',
      'visibility',
      'status',
      'metadata'
    ];

    for (const field of allowedFields) {
      if (data[field] !== undefined) {
        update[field] = data[field];
      }
    }

    if (
      data.latitude !== undefined ||
      data.longitude !== undefined
    ) {
      const existing = await spaces.findOne({
        spaceId: req.params.spaceId
      });

      if (!existing) {
        return res.status(404).json({
          ok: false,
          error: 'SPACE_NOT_FOUND'
        });
      }

      const latitude = Number(
        data.latitude ?? existing.latitude
      );

      const longitude = Number(
        data.longitude ?? existing.longitude
      );

      update.latitude = latitude;
      update.longitude = longitude;
      update.location = {
        type: 'Point',
        coordinates: [longitude, latitude]
      };
    }

    if (
      data.grid ||
      data.gridX !== undefined ||
      data.gridY !== undefined ||
      data.gridZ !== undefined ||
      data.gridLevel !== undefined
    ) {
      const existing = await spaces.findOne({
        spaceId: req.params.spaceId
      });

      if (!existing) {
        return res.status(404).json({
          ok: false,
          error: 'SPACE_NOT_FOUND'
        });
      }

      update.grid = {
        x: Number(
          data.gridX ?? data.grid?.x ?? existing.grid?.x ?? 0
        ),
        y: Number(
          data.gridY ?? data.grid?.y ?? existing.grid?.y ?? 0
        ),
        z: Number(
          data.gridZ ?? data.grid?.z ?? existing.grid?.z ?? 0
        ),
        level: Number(
          data.gridLevel ??
          data.grid?.level ??
          existing.grid?.level ??
          1
        )
      };
    }

    const result = await spaces.findOneAndUpdate(
      {
        spaceId: req.params.spaceId,
        status: { $ne: 'deleted' }
      },
      {
        $set: update
      },
      {
        returnDocument: 'after'
      }
    );

    if (!result) {
      return res.status(404).json({
        ok: false,
        error: 'SPACE_NOT_FOUND'
      });
    }

    res.json({
      ok: true,
      space: serialize(result)
    });
  } catch (error) {
    if (error && error.code === 11000) {
      return res.status(409).json({
        ok: false,
        error: 'GSAP_ADDRESS_ALREADY_EXISTS'
      });
    }

    next(error);
  }
});

app.delete('/spaces/:spaceId', async (req, res, next) => {
  try {
    const result = await spaces.updateOne(
      {
        spaceId: req.params.spaceId,
        status: { $ne: 'deleted' }
      },
      {
        $set: {
          status: 'deleted',
          deletedAt: new Date(),
          updatedAt: new Date()
        }
      }
    );

    if (!result.matchedCount) {
      return res.status(404).json({
        ok: false,
        error: 'SPACE_NOT_FOUND'
      });
    }

    res.json({
      ok: true,
      deleted: req.params.spaceId
    });
  } catch (error) {
    next(error);
  }
});

app.use((error, req, res, next) => {
  console.error('[Spatial Registry]', error);

  res.status(500).json({
    ok: false,
    error: 'INTERNAL_SERVER_ERROR',
    message:
      process.env.NODE_ENV === 'production'
        ? undefined
        : error.message
  });
});

async function shutdown(signal) {
  console.log(`[Spatial Registry] ${signal} received`);

  try {
    if (client) {
      await client.close();
    }
  } finally {
    process.exit(0);
  }
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

connectDatabase()
  .then(() => {
    app.listen(PORT, HOST, () => {
      console.log(
        `[Spatial Registry] http://${HOST}:${PORT}`
      );
    });
  })
  .catch(error => {
    console.error(
      '[Spatial Registry] MongoDB connection failed:',
      error
    );
    process.exit(1);
  });
