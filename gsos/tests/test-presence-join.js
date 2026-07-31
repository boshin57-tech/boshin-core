'use strict';

const { io } = require('socket.io-client');

const API_URL =
  'https://tobmate.com/gsos/api/worlds/tobmate-main-world/enter';

const SOCKET_URL = 'https://tobmate.com';

const SOCKET_PATH = '/gsos/presence/socket.io';

const avatarId = `avatar-presence-test-${Date.now()}`;

async function main() {
  console.log('[1] Requesting World Entry Ticket');

  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      userId: 'guest',
      avatarId
    })
  });

  const body = await response.json();

  if (!response.ok || !body.ok || !body.entry) {
    throw new Error(
      `World Entry failed: ${response.status} ${JSON.stringify(body)}`
    );
  }

  const payload = body.entry.presence.joinPayload;

  console.log('[2] Ticket issued', {
    ticketId: payload.ticketId,
    userId: payload.userId,
    avatarId: payload.avatarId,
    spaceId: payload.spaceId
  });

  const socket = io(SOCKET_URL, {
    path: SOCKET_PATH,
    transports: ['websocket', 'polling'],
    reconnection: false,
    timeout: 10000
  });

  socket.on('connect', () => {
    console.log('[3] Socket connected', socket.id);

    socket.emit('presence:join', payload, (result) => {
      console.log('[4] presence:join callback');
      console.dir(result, { depth: null });

      if (!result?.ok) {
        console.error('FAIL: presence join rejected');
        socket.disconnect();
        process.exitCode = 1;
        return;
      }

      console.log('SUCCESS: Presence Join completed');
      socket.disconnect();
    });
  });

  socket.on('presence:join-success', (result) => {
    console.log('[event] presence:join-success');
    console.dir(result, { depth: null });
  });

  socket.on('presence:join-error', (result) => {
    console.error('[event] presence:join-error');
    console.dir(result, { depth: null });
  });

  socket.on('connect_error', (error) => {
    console.error('[connect_error]', error.message);
    process.exitCode = 1;
  });

  socket.on('disconnect', (reason) => {
    console.log('[disconnect]', reason);
  });

  setTimeout(() => {
    if (socket.connected) {
      console.error('TIMEOUT: disconnecting test socket');
      socket.disconnect();
      process.exitCode = 1;
    }
  }, 15000);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
