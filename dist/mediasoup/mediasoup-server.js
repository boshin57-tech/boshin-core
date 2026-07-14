// mediasoup-server.js
// 3D 교실용 SFU 시그널링 서버
// 기존 goRoom / katago-middleware와 같은 스타일: 별도 pm2 프로세스로 구동
//
// 실행: pm2 start mediasoup-server.js --name mediasoup-classroom

const mediasoup = require('mediasoup');
const http = require('http');
const { Server } = require('socket.io');
const config = require('./mediasoup-config');

// ─────────────────────────────────────────────
// 1. Worker 풀 생성 (CPU 코어 수만큼, round-robin으로 분배)
// ─────────────────────────────────────────────
let workers = [];
let nextWorkerIdx = 0;

async function createWorkers() {
  for (let i = 0; i < config.worker.numWorkers; i++) {
    const worker = await mediasoup.createWorker({
      logLevel: config.worker.logLevel,
      logTags: config.worker.logTags,
      rtcMinPort: config.worker.rtcMinPort,
      rtcMaxPort: config.worker.rtcMaxPort,
    });

    worker.on('died', () => {
      console.error('[mediasoup] worker %d 죽음, 2초 후 프로세스 종료 (pm2가 재시작)', worker.pid);
      setTimeout(() => process.exit(1), 2000);
    });

    workers.push(worker);
    console.log('[mediasoup] worker 생성 완료 pid=' + worker.pid);
  }
}

function getNextWorker() {
  const worker = workers[nextWorkerIdx];
  nextWorkerIdx = (nextWorkerIdx + 1) % workers.length;
  return worker;
}

// ─────────────────────────────────────────────
// 2. Room 관리 — room_id 별로 Router 하나씩
// ─────────────────────────────────────────────
const rooms = {}; // room_id -> { router, peers: { peerId -> Peer } }

class Peer {
  constructor(peerId, socket) {
    this.peerId = peerId;
    this.socket = socket;
    this.transports = new Map(); // transportId -> WebRtcTransport
    this.producers = new Map();  // producerId -> Producer
    this.consumers = new Map();  // consumerId -> Consumer
  }

  addTransport(transport) { this.transports.set(transport.id, transport); }
  addProducer(producer) { this.producers.set(producer.id, producer); }
  addConsumer(consumer) { this.consumers.set(consumer.id, consumer); }

  close() {
    this.transports.forEach(t => t.close());
    this.transports.clear();
    this.producers.clear();
    this.consumers.clear();
  }
}

async function getOrCreateRoom(roomId) {
  if (rooms[roomId]) return rooms[roomId];

  const worker = getNextWorker();
  const router = await worker.createRouter({ mediaCodecs: config.mediaCodecs });
  rooms[roomId] = { router, peers: {} };
  console.log('[mediasoup] 방 생성:', roomId);
  return rooms[roomId];
}

function removeRoomIfEmpty(roomId) {
  const room = rooms[roomId];
  if (room && Object.keys(room.peers).length === 0) {
    room.router.close();
    delete rooms[roomId];
    console.log('[mediasoup] 빈 방 제거:', roomId);
  }
}

// ─────────────────────────────────────────────
// 3. WebRtcTransport 생성 헬퍼
// ─────────────────────────────────────────────
async function createWebRtcTransport(router) {
  const transport = await router.createWebRtcTransport({
    listenIps: config.webRtcTransport.listenIps,
    enableUdp: true,
    enableTcp: true,
    preferUdp: true,
    initialAvailableOutgoingBitrate: config.webRtcTransport.initialAvailableOutgoingBitrate,
  });

  if (config.webRtcTransport.maxIncomingBitrate) {
    try {
      await transport.setMaxIncomingBitrate(config.webRtcTransport.maxIncomingBitrate);
    } catch (e) { /* 무시 가능 */ }
  }

  transport.on('dtlsstatechange', (state) => {
    if (state === 'closed') transport.close();
  });

  return transport;
}

// ─────────────────────────────────────────────
// 4. Socket.io 시그널링 서버
// ─────────────────────────────────────────────
async function main() {
  await createWorkers();

  const httpServer = http.createServer();
  const io = new Server(httpServer, {
    cors: { origin: '*' },
    maxHttpBufferSize: 1e6,
  });

  io.on('connection', (socket) => {
    let currentRoomId = null;
    let currentPeerId = null;

    console.log('[mediasoup] 소켓 연결:', socket.id);

    // ── 방 입장: Router의 RTP Capabilities 반환 ──
    socket.on('ms_join_room', async ({ room_id, user_id }, cb) => {
      try {
        currentRoomId = room_id;
        currentPeerId = user_id || socket.id;

        const room = await getOrCreateRoom(room_id);
        room.peers[currentPeerId] = new Peer(currentPeerId, socket);
        socket.join(room_id);

        console.log('[mediasoup] 입장:', room_id, currentPeerId);

        // 이미 방에 있던 사람들의 producer 목록도 같이 알려줘서
        // 클라이언트가 입장하자마자 기존 참가자들을 consume 할 수 있게 함
        const existingProducers = [];
        Object.values(room.peers).forEach((peer) => {
          if (peer.peerId === currentPeerId) return;
          peer.producers.forEach((producer) => {
            existingProducers.push({ peerId: peer.peerId, producerId: producer.id, kind: producer.kind });
          });
        });

        cb({
          ok: true,
          rtpCapabilities: room.router.rtpCapabilities,
          existingProducers,
        });
      } catch (err) {
        console.error('[mediasoup] ms_join_room 에러:', err);
        cb({ ok: false, error: err.message });
      }
    });

    // ── Transport 생성 (send용, recv용 각각 따로 호출) ──
    socket.on('ms_create_transport', async ({ direction }, cb) => {
      try {
        const room = rooms[currentRoomId];
        const peer = room.peers[currentPeerId];
        const transport = await createWebRtcTransport(room.router);
        peer.addTransport(transport);

        cb({
          ok: true,
          transportId: transport.id,
          iceParameters: transport.iceParameters,
          iceCandidates: transport.iceCandidates,
          dtlsParameters: transport.dtlsParameters,
        });
      } catch (err) {
        console.error('[mediasoup] ms_create_transport 에러:', err);
        cb({ ok: false, error: err.message });
      }
    });

    // ── Transport DTLS 연결 ──
    socket.on('ms_connect_transport', async ({ transportId, dtlsParameters }, cb) => {
      try {
        const peer = rooms[currentRoomId].peers[currentPeerId];
        const transport = peer.transports.get(transportId);
        await transport.connect({ dtlsParameters });
        cb({ ok: true });
      } catch (err) {
        console.error('[mediasoup] ms_connect_transport 에러:', err);
        cb({ ok: false, error: err.message });
      }
    });

    // ── Produce: 내 오디오/비디오 송출 시작 ──
    socket.on('ms_produce', async ({ transportId, kind, rtpParameters }, cb) => {
      try {
        const room = rooms[currentRoomId];
        const peer = room.peers[currentPeerId];
        const transport = peer.transports.get(transportId);

        const producer = await transport.produce({ kind, rtpParameters });
        peer.addProducer(producer);

        producer.on('transportclose', () => { producer.close(); });

        // 같은 방의 다른 사람들에게 "새 producer 생겼다" 알림 → 각자 consume 하도록
        socket.to(currentRoomId).emit('ms_new_producer', {
          peerId: currentPeerId,
          producerId: producer.id,
          kind: producer.kind,
        });

        cb({ ok: true, producerId: producer.id });
      } catch (err) {
        console.error('[mediasoup] ms_produce 에러:', err);
        cb({ ok: false, error: err.message });
      }
    });

    // ── Consume: 다른 사람의 오디오/비디오 수신 시작 ──
    socket.on('ms_consume', async ({ transportId, producerId, rtpCapabilities }, cb) => {
      try {
        const room = rooms[currentRoomId];
        const peer = room.peers[currentPeerId];

        if (!room.router.canConsume({ producerId, rtpCapabilities })) {
          return cb({ ok: false, error: 'cannotConsume' });
        }

        const transport = peer.transports.get(transportId);
        const consumer = await transport.consume({
          producerId,
          rtpCapabilities,
          paused: true, // 클라이언트 준비 후 resume 호출로 시작 (초기 프레임 드랍 방지)
        });
        peer.addConsumer(consumer);

        consumer.on('transportclose', () => { consumer.close(); });
        consumer.on('producerclose', () => {
          consumer.close();
          socket.emit('ms_producer_closed', { consumerId: consumer.id });
        });

        cb({
          ok: true,
          consumerId: consumer.id,
          producerId,
          kind: consumer.kind,
          rtpParameters: consumer.rtpParameters,
        });
      } catch (err) {
        console.error('[mediasoup] ms_consume 에러:', err);
        cb({ ok: false, error: err.message });
      }
    });

    // ── Consumer resume (produce/consume 준비 끝난 후 실제 데이터 흐름 시작) ──
    socket.on('ms_resume_consumer', async ({ consumerId }, cb) => {
      try {
        const peer = rooms[currentRoomId].peers[currentPeerId];
        const consumer = peer.consumers.get(consumerId);
        await consumer.resume();
        cb({ ok: true });
      } catch (err) {
        cb({ ok: false, error: err.message });
      }
    });

    // ── Producer 닫기 (예: 카메라 끄기) ──
    socket.on('ms_close_producer', async ({ producerId }, cb) => {
      try {
        const peer = rooms[currentRoomId].peers[currentPeerId];
        const producer = peer.producers.get(producerId);
        if (producer) {
          producer.close();
          peer.producers.delete(producerId);
          socket.to(currentRoomId).emit('ms_producer_closed_by_peer', { peerId: currentPeerId, producerId });
        }
        cb({ ok: true });
      } catch (err) {
        cb({ ok: false, error: err.message });
      }
    });

    // ── 연결 종료 처리 ──
    socket.on('disconnect', () => {
      console.log('[mediasoup] 소켓 종료:', socket.id, 'room:', currentRoomId, 'peer:', currentPeerId);
      if (!currentRoomId || !rooms[currentRoomId]) return;

      const room = rooms[currentRoomId];
      const peer = room.peers[currentPeerId];
      if (peer) {
        peer.close();
        delete room.peers[currentPeerId];
        socket.to(currentRoomId).emit('ms_peer_left', { peerId: currentPeerId });
      }
      removeRoomIfEmpty(currentRoomId);
    });
  });

  httpServer.listen(config.signalPort, '0.0.0.0', () => {
    console.log('[mediasoup] 시그널링 서버 시작 - 포트 ' + config.signalPort);
    console.log('[mediasoup] worker 수:', config.worker.numWorkers);
    console.log('[mediasoup] announcedIp:', config.webRtcTransport.listenIps[0].announcedIp || '(미설정 - 반드시 설정 필요!)');
  });
}

main().catch((err) => {
  console.error('[mediasoup] 서버 시작 실패:', err);
  process.exit(1);
});
