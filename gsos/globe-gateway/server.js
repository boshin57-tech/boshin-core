'use strict';

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const http = require('http');
const https = require('https');

const PORT = Number(process.env.PORT || 8110);
const HOST = process.env.HOST || '127.0.0.1';

const SPATIAL_REGISTRY_URL =
  process.env.SPATIAL_REGISTRY_URL || 'http://127.0.0.1:8111';

const PRESENCE_HUB_URL =
  process.env.PRESENCE_HUB_URL || 'http://127.0.0.1:8112';

const AGENT_GATEWAY_URL =
  process.env.AGENT_GATEWAY_URL || 'http://127.0.0.1:8113';

const LOBBY_WEB_URL =
  process.env.LOBBY_WEB_URL || 'http://127.0.0.1:8002';

const LOBBY_SOCKET_URL =
  process.env.LOBBY_SOCKET_URL || 'http://127.0.0.1:8003';

const ENTRY_TICKET_TTL_MS = Math.max(
  Number(process.env.ENTRY_TICKET_TTL_MS) || 5 * 60 * 1000,
  30 * 1000
);

const app = express();
const entryTickets = new Map();

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));

function nowIso() {
  return new Date().toISOString();
}

function createError(status, code, message, detail) {
  const error = new Error(message || code);
  error.status = status;
  error.code = code;
  error.detail = detail;
  return error;
}

function requestJson(urlString, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlString);
    const transport = url.protocol === 'https:' ? https : http;

    const body =
      options.body === undefined
        ? null
        : JSON.stringify(options.body);

    const request = transport.request(
      url,
      {
        method: options.method || 'GET',
        headers: {
          accept: 'application/json',
          ...(body
            ? {
                'content-type': 'application/json',
                'content-length': Buffer.byteLength(body)
              }
            : {}),
          ...(options.headers || {})
        },
        timeout: Number(options.timeoutMs || 5000)
      },
      response => {
        let raw = '';

        response.setEncoding('utf8');

        response.on('data', chunk => {
          raw += chunk;
        });

        response.on('end', () => {
          let data = null;

          if (raw) {
            try {
              data = JSON.parse(raw);
            } catch {
              data = {
                raw
              };
            }
          }

          resolve({
            status: response.statusCode || 500,
            headers: response.headers,
            data
          });
        });
      }
    );

    request.on('timeout', () => {
      request.destroy(
        new Error(`Request timeout: ${urlString}`)
      );
    });

    request.on('error', reject);

    if (body) {
      request.write(body);
    }

    request.end();
  });
}

function cleanupExpiredTickets() {
  const currentTime = Date.now();

  for (const [ticketId, ticket] of entryTickets.entries()) {
    if (
      ticket.expiresAtMs <= currentTime ||
      ticket.consumed === true
    ) {
      entryTickets.delete(ticketId);
    }
  }
}

function serializeTicket(ticket) {
  return {
    ticketId: ticket.ticketId,
    userId: ticket.userId,
    avatarId: ticket.avatarId,
    spaceId: ticket.spaceId,
    issuedAt: ticket.issuedAt,
    expiresAt: ticket.expiresAt,
    consumed: ticket.consumed
  };
}

function extractConnectionInfo(space) {
  const metadata =
    space.metadata &&
    typeof space.metadata === 'object'
      ? space.metadata
      : {};

  return {
    targetUrl: space.targetUrl || '/',
    webUrl:
      metadata.webUrl ||
      metadata.webServer ||
      LOBBY_WEB_URL,
    socketUrl:
      metadata.socketUrl ||
      metadata.socketServer ||
      LOBBY_SOCKET_URL,
    presenceUrl:
      metadata.presenceUrl ||
      PRESENCE_HUB_URL,
    roomType:
      metadata.roomType ||
      space.type ||
      'globe-grid'
  };
}

app.get('/', (req, res) => {
  cleanupExpiredTickets();

  res.json({
    service: 'Globe Gateway',
    status: 'online',
    port: PORT,
    version: '0.2.0',
    activeEntryTickets: entryTickets.size
  });
});

app.get('/health', (req, res) => {
  cleanupExpiredTickets();

  res.json({
    ok: true,
    service: 'globe-gateway',
    activeEntryTickets: entryTickets.size,
    timestamp: nowIso()
  });
});

app.get('/api/gsos/services', (req, res) => {
  res.json({
    globeGateway: `http://${HOST}:${PORT}`,
    spatialRegistry: SPATIAL_REGISTRY_URL,
    presenceHub: PRESENCE_HUB_URL,
    agentGateway: AGENT_GATEWAY_URL,
    lobbyWeb: LOBBY_WEB_URL,
    lobbySocket: LOBBY_SOCKET_URL
  });
});

/*
 * Phase 3.2 World Entry API
 *
 * POST /api/worlds/:spaceId/enter
 *
 * Request body:
 * {
 *   "userId": "guest-001",
 *   "avatarId": "avatar-001"
 * }
 */
app.post('/api/worlds/:spaceId/enter', async (req, res, next) => {
  try {
    cleanupExpiredTickets();

    const spaceId = String(req.params.spaceId || '').trim();
    const body = req.body || {};

    if (!spaceId) {
      throw createError(
        400,
        'SPACE_ID_REQUIRED',
        'spaceId is required'
      );
    }

    const registryResponse = await requestJson(
      `${SPATIAL_REGISTRY_URL}/spaces/${encodeURIComponent(spaceId)}`,
      {
        timeoutMs: 5000
      }
    );

    if (registryResponse.status === 404) {
      throw createError(
        404,
        'WORLD_NOT_FOUND',
        `World not found: ${spaceId}`
      );
    }

    if (
      registryResponse.status < 200 ||
      registryResponse.status >= 300
    ) {
      throw createError(
        502,
        'SPATIAL_REGISTRY_ERROR',
        'Spatial Registry did not return a valid world',
        registryResponse.data
      );
    }

    const space = registryResponse.data;

    if (!space || space.status !== 'active') {
      throw createError(
        403,
        'WORLD_NOT_ACTIVE',
        'The requested world is not active'
      );
    }

    const userId =
      String(body.userId || '').trim() ||
      `guest-${crypto.randomUUID()}`;

    const avatarId =
      body.avatarId === undefined ||
      body.avatarId === null
        ? null
        : String(body.avatarId).trim() || null;

    if (
      space.visibility === 'private' &&
      space.ownerId !== userId
    ) {
      throw createError(
        403,
        'WORLD_ACCESS_DENIED',
        'The requested world is private'
      );
    }

    const issuedAtMs = Date.now();
    const expiresAtMs = issuedAtMs + ENTRY_TICKET_TTL_MS;
    const ticketId = crypto.randomUUID();

    const ticket = {
      ticketId,
      userId,
      avatarId,
      spaceId: space.spaceId,
      issuedAt: new Date(issuedAtMs).toISOString(),
      expiresAt: new Date(expiresAtMs).toISOString(),
      issuedAtMs,
      expiresAtMs,
      consumed: false
    };

    entryTickets.set(ticketId, ticket);

    res.status(201).json({
      ok: true,
      entry: {
        ticket: serializeTicket(ticket),

        world: {
          spaceId: space.spaceId,
          name: space.name,
          type: space.type,
          gsapAddress: space.gsapAddress,
          visibility: space.visibility,
          ownerId: space.ownerId,
          grid: space.grid || null,
          location: space.location || null
        },

        connection: extractConnectionInfo(space),

        presence: {
          serverUrl: PRESENCE_HUB_URL,
          transport: 'socket.io',
          joinEvent: 'presence:join',
          joinPayload: {
            ticketId,
            userId,
            avatarId,
            spaceId: space.spaceId
          }
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/*
 * Ticket inspection endpoint.
 * Later this can be restricted to internal services only.
 */
app.get('/api/entry-tickets/:ticketId', (req, res) => {
  cleanupExpiredTickets();

  const ticket = entryTickets.get(req.params.ticketId);

  if (!ticket) {
    return res.status(404).json({
      ok: false,
      error: 'ENTRY_TICKET_NOT_FOUND'
    });
  }

  res.json({
    ok: true,
    ticket: serializeTicket(ticket)
  });
});

/*
 * One-time ticket consumption endpoint.
 * Presence Hub will use this in the next implementation stage.
 */
app.post('/api/entry-tickets/:ticketId/consume', (req, res) => {
  cleanupExpiredTickets();

  const ticket = entryTickets.get(req.params.ticketId);

  if (!ticket) {
    return res.status(404).json({
      ok: false,
      error: 'ENTRY_TICKET_NOT_FOUND'
    });
  }

  if (ticket.expiresAtMs <= Date.now()) {
    entryTickets.delete(ticket.ticketId);

    return res.status(410).json({
      ok: false,
      error: 'ENTRY_TICKET_EXPIRED'
    });
  }

  if (ticket.consumed) {
    return res.status(409).json({
      ok: false,
      error: 'ENTRY_TICKET_ALREADY_CONSUMED'
    });
  }

  const body = req.body || {};

  if (
    body.userId &&
    String(body.userId) !== ticket.userId
  ) {
    return res.status(403).json({
      ok: false,
      error: 'ENTRY_TICKET_USER_MISMATCH'
    });
  }

  if (
    body.spaceId &&
    String(body.spaceId) !== ticket.spaceId
  ) {
    return res.status(403).json({
      ok: false,
      error: 'ENTRY_TICKET_SPACE_MISMATCH'
    });
  }

  ticket.consumed = true;
  ticket.consumedAt = nowIso();

  res.json({
    ok: true,
    ticket: {
      ...serializeTicket(ticket),
      consumedAt: ticket.consumedAt
    }
  });
});

app.use((req, res) => {
  res.status(404).json({
    ok: false,
    error: 'ROUTE_NOT_FOUND',
    path: req.originalUrl
  });
});

app.use((error, req, res, next) => {
  console.error('[Globe Gateway]', error);

  res.status(Number(error.status) || 500).json({
    ok: false,
    error: error.code || 'INTERNAL_SERVER_ERROR',
    message:
      error.status && error.status < 500
        ? error.message
        : 'Globe Gateway request failed',
    ...(error.detail ? { detail: error.detail } : {})
  });
});

const cleanupTimer = setInterval(
  cleanupExpiredTickets,
  60 * 1000
);

cleanupTimer.unref();

app.listen(PORT, HOST, () => {
  console.log(`[Globe Gateway] http://${HOST}:${PORT}`);
  console.log(
    `[Globe Gateway] Spatial Registry: ${SPATIAL_REGISTRY_URL}`
  );
  console.log(
    `[Globe Gateway] Entry ticket TTL: ${ENTRY_TICKET_TTL_MS}ms`
  );
});
