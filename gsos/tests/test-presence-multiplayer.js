'use strict';

const { io } = require('socket.io-client');

const API_BASE =
  'https://tobmate.com/gsos/api/worlds/tobmate-main-world/enter';

const SOCKET_URL = 'https://tobmate.com';
const SOCKET_PATH = '/gsos/presence/socket.io';

const SPACE_ID = 'tobmate-main-world';
const runId = Date.now();

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function issueTicket(userId, avatarId) {
  const response = await fetch(API_BASE, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      userId,
      avatarId
    })
  });

  const body = await response.json();

  if (!response.ok || !body?.ok) {
    throw new Error(
      `Ticket issue failed: ${response.status} ${JSON.stringify(body)}`
    );
  }

  return body.entry.presence.joinPayload;
}

function createClient(label) {
  const socket = io(SOCKET_URL, {
    path: SOCKET_PATH,
    transports: ['websocket', 'polling'],
    reconnection: false,
    timeout: 10000
  });

  socket.on('connect', () => {
    console.log(`[${label}] connected`, socket.id);
  });

  socket.on('presence:joined', (presence) => {
    console.log(`[${label}] event presence:joined`);
    console.dir(presence, { depth: null });
  });

  socket.on('presence:list', (users) => {
    console.log(`[${label}] event presence:list`);
    console.dir(users, { depth: null });
  });

  socket.on('presence:moved', (presence) => {
    console.log(`[${label}] event presence:moved`);
    console.dir(presence, { depth: null });
  });

  socket.on('presence:move', (presence) => {
    console.log(`[${label}] event presence:move`);
    console.dir(presence, { depth: null });
  });

  socket.on('presence:updated', (presence) => {
    console.log(`[${label}] event presence:updated`);
    console.dir(presence, { depth: null });
  });

  socket.on('presence:left', (presence) => {
    console.log(`[${label}] event presence:left`);
    console.dir(presence, { depth: null });
  });

  socket.on('presence:disconnected', (presence) => {
    console.log(`[${label}] event presence:disconnected`);
    console.dir(presence, { depth: null });
  });

  socket.on('presence:join-error', (result) => {
    console.error(`[${label}] join error`);
    console.dir(result, { depth: null });
  });

  socket.on('connect_error', (error) => {
    console.error(`[${label}] connect_error`, error.message);
  });

  socket.on('disconnect', (reason) => {
    console.log(`[${label}] disconnected`, reason);
  });

  return socket;
}

function waitForConnect(socket, label) {
  return new Promise((resolve, reject) => {
    if (socket.connected) {
      resolve();
      return;
    }

    const timer = setTimeout(() => {
      reject(new Error(`${label} connection timeout`));
    }, 10000);

    socket.once('connect', () => {
      clearTimeout(timer);
      resolve();
    });

    socket.once('connect_error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

function joinPresence(socket, payload, label) {
  return new Promise((resolve, reject) => {
    socket.emit('presence:join', payload, (result) => {
      console.log(`[${label}] join callback`);
      console.dir(result, { depth: null });

      if (!result?.ok) {
        reject(
          new Error(`${label} join rejected: ${JSON.stringify(result)}`)
        );
        return;
      }

      resolve(result);
    });
  });
}

function movePresence(socket, position, label) {
  return new Promise((resolve, reject) => {
    socket.emit(
      'presence:move',
      {
        spaceId: SPACE_ID,
        x: position.x,
        y: position.y,
        z: position.z,
        rotationY: position.rotationY,
        animation: position.animation,
        timestamp: position.timestamp
      },
      (result) => {
        console.log(`[${label}] move callback`);
        console.dir(result, { depth: null });

        if (!result?.ok) {
          reject(
            new Error(`${label} move rejected: ${JSON.stringify(result)}`)
          );
          return;
        }

        resolve(result);
      }
    );
  });
}

async function main() {
  const userA = `guest-a-${runId}`;
  const userB = `guest-b-${runId}`;

  const avatarA = `avatar-a-${runId}`;
  const avatarB = `avatar-b-${runId}`;

  console.log('[1] Issuing two entry tickets');

  const [ticketA, ticketB] = await Promise.all([
    issueTicket(userA, avatarA),
    issueTicket(userB, avatarB)
  ]);

  console.log('[2] Tickets issued', {
    ticketA: ticketA.ticketId,
    ticketB: ticketB.ticketId
  });

  const clientA = createClient('A');
  const clientB = createClient('B');

  try {
    await Promise.all([
      waitForConnect(clientA, 'A'),
      waitForConnect(clientB, 'B')
    ]);

    console.log('[3] Joining client A');

    const resultA = await joinPresence(
      clientA,
      ticketA,
      'A'
    );

    if (resultA.users.length !== 1) {
      console.warn(
        `[A] Expected 1 user, received ${resultA.users.length}`
      );
    }

    await delay(500);

    console.log('[4] Joining client B');

    const resultB = await joinPresence(
      clientB,
      ticketB,
      'B'
    );

    const hasA = resultB.users.some(
      (user) => user.avatarId === avatarA
    );

    const hasB = resultB.users.some(
      (user) => user.avatarId === avatarB
    );

    if (!hasA || !hasB) {
      throw new Error(
        `B user list incomplete: hasA=${hasA}, hasB=${hasB}`
      );
    }

    console.log('SUCCESS: Both avatars are in the same space');

    await delay(700);

    console.log('[5] Moving client A');

    const position = {
      x: 12.5,
      y: 0,
      z: -7.25,
      rotationY: 1.57,
      animation: 'walk',
      timestamp: Date.now()
    };

    await movePresence(clientA, position, 'A');

    console.log('SUCCESS: Client A movement accepted');

    await delay(1500);

    console.log('[6] Disconnecting client B');

    clientB.disconnect();

    await delay(1000);

    console.log('[7] Multiplayer Presence test completed');
  } finally {
    if (clientA.connected) {
      clientA.disconnect();
    }

    if (clientB.connected) {
      clientB.disconnect();
    }
  }
}

main().catch((error) => {
  console.error('FAIL:', error);
  process.exit(1);
});
