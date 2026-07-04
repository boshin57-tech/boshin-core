const http = require('http');
const io = require('./node_modules/socket.io-client');

// HTTP 서버 - /bot/join 수신
const httpServer = http.createServer((req, res) => {
  if(req.method === 'POST' && req.url === '/bot/join') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const {room_id} = JSON.parse(body);
        console.log('[BRIDGE] /bot/join 수신! room_id:', room_id);
        if(room_id && !activeRooms.has(room_id)) {
          activeRooms.add(room_id);
          connectBotToRoom(room_id);
        }
        res.writeHead(200); res.end('ok');
      } catch(e) { res.writeHead(400); res.end('err'); }
    });
  } else { res.writeHead(404); res.end(); }
});
httpServer.listen(8099, () => console.log('[BRIDGE] 포트 8099 시작'));

const BOT_TOKEN = 'tob_bot';
const GOROOM_URL = 'http://localhost:8005';

const monitor = io(GOROOM_URL, {reconnection: true});
const activeRooms = new Set();
const activeBots = {};

monitor.on('connect', () => {
  console.log('[BRIDGE] goRoom 모니터 연결됨');
});

monitor.on('sc_message', (protocol, err, data) => {
  if(protocol === 530 && data && data.items) {
    data.items.forEach(room => {
      if(room.setting && room.setting.opponent === 'pva' && !activeRooms.has(room.room_id)) {
        activeRooms.add(room.room_id);
        connectBotToRoom(room.room_id);
      }
    });
  }
});

monitor.on('disconnect', () => console.log('[BRIDGE] 모니터 연결 끊김'));

function connectBotToRoom(roomId) {
  console.log('[BRIDGE] 봇을 방에 연결:', roomId);
  const botSocket = io(GOROOM_URL, {reconnection: false});

  botSocket.on('connect', () => {
    console.log('[BRIDGE] 봇 소켓 연결됨');
    activeBots[roomId] = botSocket;
    botSocket.emit('cs_message', 788, {token: BOT_TOKEN, room_id: roomId});
  });

  botSocket.on('sc_message', (protocol, err, data) => {
    if(protocol === 800) console.log('[BRIDGE] SC_ADD_USER 봇 입장 성공!');
    if(protocol === 817) {
      console.log('[BRIDGE] SC_START_PREPARE - CS_CONFIRM_PREPARED 전송!');
      botSocket.emit('cs_message', 818, {token: BOT_TOKEN, room_id: roomId});
    }
    if(protocol === 832) {
      console.log('[BRIDGE] SC_GAME_START - 게임 시작!');
      const body2 = JSON.stringify({protocol: 832, data: data});
      const req2 = http.request({hostname:'localhost',port:8016,path:'/event',method:'POST',
        headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(body2)}},()=>{});
      req2.write(body2); req2.end();
    }
    if(protocol === 835) {
      console.log('[BRIDGE] SC_GAME_MOVE 착수!', data.move);
      if(activeBots[data.room_id] && data.move === activeBots[data.room_id]._lastMove) return;
      const body3 = JSON.stringify({protocol: 835, data: data});
      const req3 = http.request({hostname:'localhost',port:8016,path:'/event',method:'POST',
        headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(body3)}},()=>{});
      req3.write(body3); req3.end();
    }
    if(protocol === 785) {
      activeRooms.delete(roomId);
      delete activeBots[roomId];
      botSocket.disconnect();
    }
  });

  botSocket.on('disconnect', () => {
    console.log('[BRIDGE] 봇 소켓 끊김');
    activeRooms.delete(roomId);
    delete activeBots[roomId];
  });
}

const server = http.createServer((req, res) => {
  if(req.method === 'POST' && req.url === '/bot/join') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const {room_id} = JSON.parse(body);
        if(!activeRooms.has(room_id)) {
          activeRooms.add(room_id);
          connectBotToRoom(room_id);
        }
        res.end('ok');
      } catch(e) { res.end('error'); }
    });
  } else if(req.method === 'POST' && req.url === '/bot/move') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const {room_id, move} = JSON.parse(body);
        const botSocket = activeBots[room_id];
        if(botSocket && botSocket.connected) {
          botSocket._lastMove = move;
          botSocket.emit('cs_message', 834, {token: BOT_TOKEN, room_id: room_id, move: move});
          console.log('[BRIDGE] 봇 착수 전송! room:', room_id, 'move:', move);
        } else {
          console.log('[BRIDGE] 봇 소켓 없음! room:', room_id);
        }
      } catch(e) { console.log('[BRIDGE] /bot/move 에러:', e.message); }
      res.end('ok');
    });
  } else { res.end('bot bridge running'); }
});

