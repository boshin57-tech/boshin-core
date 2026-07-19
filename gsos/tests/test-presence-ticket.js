'use strict';

const socketIoClient = require('socket.io-client');

const io =
  typeof socketIoClient === 'function'
    ? socketIoClient
    : socketIoClient.io;

const ticketId = String(process.env.TICKET_ID || '').trim();
const spaceId = String(
  process.env.SPACE_ID || 'tobmate-main-world'
).trim();

const userId = String(
  process.env.USER_ID || 'guest-presence-test'
).trim();

const avatarId = String(
  process.env.AVATAR_ID || 'avatar-presence-001'
).trim();

if (!ticketId) {
  console.error('TICKET_ID is required');
  process.exit(1);
}

const socket = io('http://127.0.0.1:8112', {
  reconnection: false,
  timeout: 5000
});

let finished = false;

function finish(code) {
  if (finished) return;

  finished = true;
  socket.disconnect();

  setTimeout(() => {
    process.exit(code);
  }, 100);
}

socket.on('presence:connected', data => {
  console.log(
    'PRESENCE CONNECTED:',
    JSON.stringify(data, null, 2)
  );
});

socket.on('presence:join-success', data => {
  console.log(
    'JOIN SUCCESS EVENT:',
    JSON.stringify(data, null, 2)
  );
});

socket.on('presence:join-error', data => {
  console.error(
    'JOIN ERROR EVENT:',
    JSON.stringify(data, null, 2)
  );
});

socket.on('connect', () => {
  console.log('CONNECTED:', socket.id);

  socket.emit(
    'presence:join',
    {
      ticketId,
      userId,
      avatarId,
      spaceId
    },
    result => {
      console.log(
        'JOIN RESULT:',
        JSON.stringify(result, null, 2)
      );

      if (!result || result.ok !== true) {
        finish(1);
        return;
      }

      socket.emit(
        'presence:move',
        {
          x: 10,
          y: 0,
          z: 20
        },
        moveResult => {
          console.log(
            'MOVE RESULT:',
            JSON.stringify(moveResult, null, 2)
          );

          finish(moveResult?.ok === true ? 0 : 1);
        }
      );
    }
  );
});

socket.on('connect_error', error => {
  console.error('CONNECT ERROR:', error.message);
  console.error('DESCRIPTION:', error.description || null);
  console.error('CONTEXT:', error.context || null);
  console.error('TYPE:', error.type || null);
  console.error('STACK:', error.stack || null);
  finish(1);
});

setTimeout(() => {
  console.error('TEST TIMEOUT');
  finish(1);
}, 10000);
