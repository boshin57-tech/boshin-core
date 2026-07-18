'use strict';

const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const PORT = Number(process.env.PORT || 8112);
const HOST = process.env.HOST || '127.0.0.1';

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const presences = new Map();

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    service: 'Presence Hub',
    status: 'online',
    connectedUsers: presences.size
  });
});

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'presence-hub',
    connectedUsers: presences.size,
    timestamp: new Date().toISOString()
  });
});

app.get('/presence', (req, res) => {
  res.json(Array.from(presences.values()));
});

io.on('connection', socket => {
  const initialPresence = {
    socketId: socket.id,
    userId: null,
    spaceId: null,
    position: null,
    connectedAt: new Date().toISOString()
  };

  presences.set(socket.id, initialPresence);

  socket.on('presence:join', payload => {
    const current = presences.get(socket.id) || initialPresence;

    const updated = {
      ...current,
      userId: payload?.userId || current.userId,
      spaceId: payload?.spaceId || current.spaceId,
      avatarId: payload?.avatarId || null,
      updatedAt: new Date().toISOString()
    };

    presences.set(socket.id, updated);

    if (updated.spaceId) {
      socket.join(updated.spaceId);
      io.to(updated.spaceId).emit('presence:list',
        Array.from(presences.values()).filter(
          item => item.spaceId === updated.spaceId
        )
      );
    }
  });

  socket.on('presence:move', payload => {
    const current = presences.get(socket.id);

    if (!current) return;

    const updated = {
      ...current,
      position: {
        x: Number(payload?.x || 0),
        y: Number(payload?.y || 0),
        z: Number(payload?.z || 0)
      },
      updatedAt: new Date().toISOString()
    };

    presences.set(socket.id, updated);

    if (updated.spaceId) {
      socket.to(updated.spaceId).emit('presence:moved', updated);
    }
  });

  socket.on('disconnect', () => {
    const current = presences.get(socket.id);
    presences.delete(socket.id);

    if (current?.spaceId) {
      io.to(current.spaceId).emit('presence:left', {
        socketId: socket.id,
        userId: current.userId
      });
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log(`[Presence Hub] http://${HOST}:${PORT}`);
});
