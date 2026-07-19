'use strict';

const express = require('express');
const cors = require('cors');
const http = require('http');
const https = require('https');
const { Server } = require('socket.io');

const PORT = Number(process.env.PORT || 8112);
const HOST = process.env.HOST || '127.0.0.1';

const GLOBE_GATEWAY_URL =
  process.env.GLOBE_GATEWAY_URL || 'http://127.0.0.1:8110';

const REQUIRE_ENTRY_TICKET =
  String(process.env.REQUIRE_ENTRY_TICKET || 'true').toLowerCase() !==
  'false';

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const presences = new Map();

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));

function nowIso() {
  return new Date().toISOString();
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
              data = { raw };
            }
          }

          resolve({
            status: response.statusCode || 500,
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

async function consumeEntryTicket(payload) {
  const ticketId = String(payload?.ticketId || '').trim();
  const userId = String(payload?.userId || '').trim();
  const spaceId = String(payload?.spaceId || '').trim();

  if (!ticketId) {
    return {
      ok: false,
      error: 'ENTRY_TICKET_REQUIRED'
    };
  }

  if (!userId) {
    return {
      ok: false,
      error: 'USER_ID_REQUIRED'
    };
  }

  if (!spaceId) {
    return {
      ok: false,
      error: 'SPACE_ID_REQUIRED'
    };
  }

  try {
    const response = await requestJson(
      `${GLOBE_GATEWAY_URL}/api/entry-tickets/${encodeURIComponent(
        ticketId
      )}/consume`,
      {
        method: 'POST',
        body: {
          userId,
          spaceId
        },
        timeoutMs: 5000
      }
    );

    if (response.status < 200 || response.status >= 300) {
      return {
        ok: false,
        error:
          response.data?.error ||
          'ENTRY_TICKET_VALIDATION_FAILED',
        status: response.status
      };
    }

    return {
      ok: true,
      ticket: response.data?.ticket
    };
  } catch (error) {
    console.error(
      '[Presence Hub] Entry ticket validation error:',
      error
    );

    return {
      ok: false,
      error: 'GLOBE_GATEWAY_UNAVAILABLE'
    };
  }
}

function getSpacePresences(spaceId) {
  return Array.from(presences.values()).filter(
    item => item.spaceId === spaceId
  );
}

function removeSocketFromPreviousSpace(socket, previousSpaceId) {
  if (!previousSpaceId) return;

  socket.leave(previousSpaceId);
}

app.get('/', (req, res) => {
  res.json({
    service: 'Presence Hub',
    status: 'online',
    connectedUsers: presences.size,
    entryTicketRequired: REQUIRE_ENTRY_TICKET
  });
});

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'presence-hub',
    connectedUsers: presences.size,
    entryTicketRequired: REQUIRE_ENTRY_TICKET,
    globeGateway: GLOBE_GATEWAY_URL,
    timestamp: nowIso()
  });
});

app.get('/presence', (req, res) => {
  const spaceId = String(req.query.spaceId || '').trim();

  if (spaceId) {
    return res.json(getSpacePresences(spaceId));
  }

  res.json(Array.from(presences.values()));
});

io.on('connection', socket => {
  const initialPresence = {
    socketId: socket.id,
    userId: null,
    avatarId: null,
    spaceId: null,
    position: null,
    authenticated: false,
    connectedAt: nowIso()
  };

  presences.set(socket.id, initialPresence);

  socket.emit('presence:connected', {
    ok: true,
    socketId: socket.id,
    entryTicketRequired: REQUIRE_ENTRY_TICKET
  });

  socket.on('presence:join', async (payload, callback) => {
    const respond =
      typeof callback === 'function'
        ? callback
        : () => {};

    try {
      const current =
        presences.get(socket.id) || initialPresence;

      const requestedUserId =
        String(payload?.userId || '').trim();

      const requestedSpaceId =
        String(payload?.spaceId || '').trim();

      const requestedAvatarId =
        payload?.avatarId === undefined ||
        payload?.avatarId === null
          ? null
          : String(payload.avatarId).trim() || null;

      if (!requestedUserId) {
        const result = {
          ok: false,
          error: 'USER_ID_REQUIRED'
        };

        socket.emit('presence:join-error', result);
        return respond(result);
      }

      if (!requestedSpaceId) {
        const result = {
          ok: false,
          error: 'SPACE_ID_REQUIRED'
        };

        socket.emit('presence:join-error', result);
        return respond(result);
      }

      let ticket = null;

      if (REQUIRE_ENTRY_TICKET) {
        const validation = await consumeEntryTicket({
          ticketId: payload?.ticketId,
          userId: requestedUserId,
          spaceId: requestedSpaceId
        });

        if (!validation.ok) {
          const result = {
            ok: false,
            error: validation.error,
            status: validation.status || 403
          };

          socket.emit('presence:join-error', result);
          return respond(result);
        }

        ticket = validation.ticket;
      }

      if (
        current.spaceId &&
        current.spaceId !== requestedSpaceId
      ) {
        removeSocketFromPreviousSpace(
          socket,
          current.spaceId
        );

        socket.to(current.spaceId).emit('presence:left', {
          socketId: socket.id,
          userId: current.userId,
          spaceId: current.spaceId
        });
      }

      const updated = {
        ...current,
        userId: requestedUserId,
        avatarId: requestedAvatarId,
        spaceId: requestedSpaceId,
        ticketId: ticket?.ticketId || null,
        authenticated: REQUIRE_ENTRY_TICKET
          ? true
          : Boolean(payload?.ticketId),
        joinedAt: nowIso(),
        updatedAt: nowIso()
      };

      presences.set(socket.id, updated);
      socket.join(requestedSpaceId);

      const list = getSpacePresences(requestedSpaceId);

      io.to(requestedSpaceId).emit(
        'presence:list',
        list
      );

      socket.to(requestedSpaceId).emit(
        'presence:joined',
        updated
      );

      const result = {
        ok: true,
        presence: updated,
        users: list
      };

      socket.emit('presence:join-success', result);
      respond(result);
    } catch (error) {
      console.error(
        '[Presence Hub] presence:join error:',
        error
      );

      const result = {
        ok: false,
        error: 'PRESENCE_JOIN_FAILED'
      };

      socket.emit('presence:join-error', result);
      respond(result);
    }
  });

  socket.on('presence:move', (payload, callback) => {
    const respond =
      typeof callback === 'function'
        ? callback
        : () => {};

    const current = presences.get(socket.id);

    if (
      !current ||
      !current.authenticated ||
      !current.spaceId
    ) {
      const result = {
        ok: false,
        error: 'PRESENCE_NOT_JOINED'
      };

      socket.emit('presence:move-error', result);
      return respond(result);
    }

    const x = Number(payload?.x ?? 0);
    const y = Number(payload?.y ?? 0);
    const z = Number(payload?.z ?? 0);

    if (
      !Number.isFinite(x) ||
      !Number.isFinite(y) ||
      !Number.isFinite(z)
    ) {
      const result = {
        ok: false,
        error: 'INVALID_POSITION'
      };

      socket.emit('presence:move-error', result);
      return respond(result);
    }

    const updated = {
      ...current,
      position: { x, y, z },
      updatedAt: nowIso()
    };

    presences.set(socket.id, updated);

    socket
      .to(updated.spaceId)
      .emit('presence:moved', updated);

    respond({
      ok: true,
      presence: updated
    });
  });

  socket.on('presence:leave', (payload, callback) => {
    const respond =
      typeof callback === 'function'
        ? callback
        : () => {};

    const current = presences.get(socket.id);

    if (!current?.spaceId) {
      return respond({
        ok: false,
        error: 'PRESENCE_NOT_JOINED'
      });
    }

    const previousSpaceId = current.spaceId;

    socket.leave(previousSpaceId);

    const updated = {
      ...current,
      spaceId: null,
      ticketId: null,
      authenticated: false,
      position: null,
      updatedAt: nowIso()
    };

    presences.set(socket.id, updated);

    socket.to(previousSpaceId).emit('presence:left', {
      socketId: socket.id,
      userId: current.userId,
      spaceId: previousSpaceId
    });

    respond({
      ok: true
    });
  });

  socket.on('disconnect', reason => {
    const current = presences.get(socket.id);

    presences.delete(socket.id);

    if (current?.spaceId) {
      io.to(current.spaceId).emit('presence:left', {
        socketId: socket.id,
        userId: current.userId,
        spaceId: current.spaceId,
        reason
      });
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log(`[Presence Hub] http://${HOST}:${PORT}`);
  console.log(
    `[Presence Hub] Globe Gateway: ${GLOBE_GATEWAY_URL}`
  );
  console.log(
    `[Presence Hub] Entry ticket required: ${REQUIRE_ENTRY_TICKET}`
  );
});
