'use strict';
const http = require('http');
const Server = require('socket.io');
const { MongoClient } = require('mongodb');

const PORT = 8018;
const MONGO_URL = 'mongodb://localhost:27017';
const DB_NAME = 'tob';
let db;

MongoClient.connect(MONGO_URL).then(client => {
  db = client.db(DB_NAME);
  console.log('[lecture-server] MongoDB 연결 완료');
});

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  if (req.url === '/health') {
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify({status:'ok',port:PORT}));
  }

  // 강의 이력 조회
  if (req.url.startsWith('/lecture-history') && req.method === 'GET') {
    const u = new URL(req.url, 'http://x');
    const userId = u.searchParams.get('user_id');
    try {
      const history = await db.collection('lectures').find({user_id:userId}).sort({created_at:-1}).limit(20).toArray();
      res.writeHead(200, {'Content-Type':'application/json'});
      return res.end(JSON.stringify(history));
    } catch(e) { res.writeHead(500); return res.end('{}'); }
  }

  // 녹화 목록 조회
  if (req.url.startsWith('/recordings') && req.method === 'GET') {
    const u = new URL(req.url, 'http://x');
    const roomId = u.searchParams.get('room_id');
    try {
      const recs = await db.collection('lecture_recordings').find({room_id:roomId}).sort({created_at:-1}).limit(10).toArray();
      res.writeHead(200, {'Content-Type':'application/json'});
      return res.end(JSON.stringify(recs));
    } catch(e) { res.writeHead(500); return res.end('[]'); }
  }

  res.writeHead(404); res.end();
});

const io = new Server(server, {
  cors: { origin:'*', methods:['GET','POST'] },
  path: '/lecture/socket.io'
});

const rooms = {};

async function saveToMongo(collection, data) {
  try { await db.collection(collection).insertOne({...data, created_at: new Date()}); }
  catch(e) { console.error('[mongo]', e.message); }
}

const { uploadBuffer, listFiles, getSignedUrl } = require('./gcs-upload');
const RECORDINGS_DIR = '/home/boshin57/Tobmate_Live/recordings';
const fs = require('fs');
if(!fs.existsSync(RECORDINGS_DIR)) fs.mkdirSync(RECORDINGS_DIR, {recursive:true});

const raisedHands = new Map(); // socketId → { name, time }

io.on('connection', (socket) => {
  console.log('[lecture] 연결:', socket.id);

  socket.on('join-room', async ({ roomId, userId, role, boardSize, mode }) => {
    socket.join(roomId);
    if (!rooms[roomId]) rooms[roomId] = { students:{}, pro:null, board:{size:boardSize||9,stones:[],move:0}, mode:mode||'ai', recording:false, startTime:new Date() };
    if (role==='pro') rooms[roomId].pro = { socketId:socket.id, userId };
    else rooms[roomId].students[socket.id] = { userId, role };
    const memberCount = Object.keys(rooms[roomId].students).length;
    io.to(roomId).emit('room-update', { memberCount, pro:rooms[roomId].pro, boardSize:rooms[roomId].board.size, mode:rooms[roomId].mode, students:rooms[roomId].students });

    // 입장 이력 저장
    await saveToMongo('lectures', { room_id:roomId, user_id:userId, role, mode:mode||'ai', action:'join', board_size:boardSize||9 });
    console.log(`[lecture] ${userId}(${role}) → ${roomId}`);
  });

  // WebRTC 시그널링
  socket.on('webrtc-offer',  d => socket.to(d.roomId).emit('webrtc-offer',  {...d, from:socket.id}));
  socket.on('webrtc-answer', d => socket.to(d.roomId).emit('webrtc-answer', {...d, from:socket.id}));
  socket.on('webrtc-ice',    d => socket.to(d.roomId).emit('webrtc-ice',    {...d, from:socket.id}));

  // P2P
  socket.on('p2p-join',   ({ roomId, userId, role }) => { socket.join(roomId); socket.to(roomId).emit('p2p-user-joined', { userId, socketId:socket.id, role }); });
  socket.on('p2p-offer',  d => io.to(d.to).emit('p2p-offer',  {...d, from:socket.id}));
  socket.on('p2p-answer', d => io.to(d.to).emit('p2p-answer', {...d, from:socket.id}));
  socket.on('p2p-ice',    d => io.to(d.to).emit('p2p-ice',    {...d, from:socket.id}));
  socket.on('p2p-leave',  d => socket.to(d.roomId).emit('p2p-user-left', { socketId:socket.id }));

  // 바둑판
  socket.on('board-move', async ({ roomId, stone, move, boardSize }) => {
    if (!rooms[roomId]) return;
    rooms[roomId].board.stones.push(stone);
    rooms[roomId].board.move = move;
    rooms[roomId].board.size = boardSize;
    socket.to(roomId).emit('board-move', { stone, move, boardSize });
    await saveToMongo('lectures', { room_id:roomId, action:'move', stone, move, board_size:boardSize });
  });

  socket.on('board-reset', async ({ roomId, boardSize }) => {
    if (!rooms[roomId]) return;
    rooms[roomId].board = { size:boardSize||9, stones:[], move:0 };
    io.to(roomId).emit('board-reset', { boardSize });
  });

  socket.on('board-sync-request', ({ roomId }) => {
    if (!rooms[roomId]) return;
    socket.emit('board-sync', rooms[roomId].board);
  });

  // 채팅
  socket.on('chat', async ({ roomId, userId, text, role }) => {
    io.to(roomId).emit('chat', { userId, text, role, ts:Date.now() });
    await saveToMongo('lectures', { room_id:roomId, action:'chat', user_id:userId, text, role });
  });

  // 녹화 시작/종료
  socket.on('recording-start', async ({ roomId, userId }) => {
    if (!rooms[roomId]) return;
    rooms[roomId].recording = true;
    rooms[roomId].recordStart = new Date();
    io.to(roomId).emit('recording-status', { recording:true });
    await saveToMongo('lecture_recordings', { room_id:roomId, user_id:userId, status:'started' });
    console.log(`[recording] ${roomId} 녹화 시작`);
  });

  socket.on('recording-stop', async ({ roomId, userId, duration }) => {
    if (!rooms[roomId]) return;
    rooms[roomId].recording = false;
    io.to(roomId).emit('recording-status', { recording:false });
    await saveToMongo('lecture_recordings', { room_id:roomId, user_id:userId, status:'stopped', duration, stones:rooms[roomId].board.stones });
    console.log(`[recording] ${roomId} 녹화 종료 ${duration}초`);
  });

  // D-ID 아바타 요청
  socket.on('avatar-speak', async ({ roomId, text, lang }) => {
    io.to(roomId).emit('avatar-speaking', { text, lang });
  });

  // 치팅 감지
  socket.on('cheat-alert', ({ roomId, userId, type, elapsed, deviation }) => {
    const room = rooms[roomId];
    if(!room) return;
    // 강사에게만 전송
    if(room.pro) io.to(room.pro.socketId).emit('cheat-detected',{ userId, type, elapsed, deviation, ts: Date.now() });
    console.log('[치팅]', userId, type, elapsed+'ms');
  });

  // 바둑판 제어권
  socket.on('board-control', ({ roomId, targetUserId }) => {
    if (!rooms[roomId]) return;
    rooms[roomId].boardController = targetUserId || null;
    io.to(roomId).emit('board-control-update', { targetUserId: targetUserId || null });
    console.log('[제어권]', roomId, '->', targetUserId || '회수');
  });

  // 손들기
  socket.on('raise-hand', ({ name }) => {
    raisedHands.set(socket.id, { name: name || '수강생', time: Date.now() });
    io.to(Object.keys(socket.rooms||{}).find(r=>r!==socket.id)||'').emit('hand-update', Array.from(raisedHands.entries()).map(([id,v])=>({id,...v})));
    io.emit('hand-update', Array.from(raisedHands.entries()).map(([id,v])=>({id,...v})));
    console.log('[손들기]', name, socket.id);
  });
  socket.on('lower-hand', ({ targetId } = {}) => {
    const tid = targetId || socket.id;
    raisedHands.delete(tid);
    io.emit('hand-update', Array.from(raisedHands.entries()).map(([id,v])=>({id,...v})));
  });

  socket.on('disconnecting', () => {
    for (const roomId of Object.keys(socket.rooms||{})) {
      if (!rooms[roomId]) continue;
      delete rooms[roomId].students[socket.id];
      if (rooms[roomId].pro?.socketId === socket.id) rooms[roomId].pro = null;
      const memberCount = Object.keys(rooms[roomId].students).length;
      socket.to(roomId).emit('room-update', { memberCount, pro:rooms[roomId].pro });
      socket.to(roomId).emit('p2p-user-left', { socketId:socket.id });
    }
  });
});

server.listen(PORT, () => console.log(`[lecture-server] 포트 ${PORT} 시작`));

// 녹화 업로드 API
const http2 = require('http');
const recApi = http2.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if(req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  if(req.method === 'POST' && req.url === '/upload-recording') {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', async () => {
      try {
        const body = JSON.parse(Buffer.concat(chunks).toString());
        const { roomId, userId, data, duration } = body;
        const ts = new Date().toISOString().replace(/[:.]/g,'-');
        const remotePath = 'recordings/'+roomId+'/'+ts+'_'+userId+'.webm';
        const buf = Buffer.from(data, 'base64');
        const url = await uploadBuffer(buf, remotePath, 'video/webm');
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ ok: true, url, duration }));
        console.log('[녹화업로드]', roomId, userId, url);
      } catch(e) {
        res.writeHead(500); res.end(JSON.stringify({ok:false, error:e.message}));
      }
    });
  }
  else if(req.method === 'GET' && req.url.startsWith('/recordings')) {
    const room = new URL(req.url, 'http://localhost').searchParams.get('room') || '';
    const files = await listFiles(room ? 'recordings/'+room+'/' : 'recordings/');
    res.writeHead(200, {'Content-Type':'application/json'});
    res.end(JSON.stringify(files));
  }
  else { res.writeHead(404); res.end(); }
});
recApi.listen(8021, () => console.log('[recApi] 포트 8021 시작'));

// 강의 스케줄 API (포트 8022)
const schedApi = require('http').createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if(req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  const { MongoClient } = require('mongodb');
  const client = await MongoClient.connect('mongodb://localhost:27017', {useUnifiedTopology:true});
  const col = client.db('tob').collection('lecture_schedules');

  try {
    // GET /schedules?room=xxx — 목록 조회
    if(req.method === 'GET' && req.url.startsWith('/schedules')) {
      const room = new URL(req.url, 'http://localhost').searchParams.get('room') || '';
      const query = room ? {room_id: room} : {};
      const list = await col.find(query).sort({start_time: 1}).toArray();
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify(list));
    }
    // POST /schedules — 등록
    else if(req.method === 'POST' && req.url === '/schedules') {
      const chunks = [];
      req.on('data', c => chunks.push(c));
      req.on('end', async () => {
        const body = JSON.parse(Buffer.concat(chunks).toString());
        const doc = {
          room_id: body.roomId,
          title: body.title,
          instructor: body.instructor || '강사',
          start_time: new Date(body.startTime),
          duration_min: body.durationMin || 60,
          description: body.description || '',
          created_at: new Date()
        };
        const result = await col.insertOne(doc);
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:true, id: result.insertedId}));
        console.log('[스케줄] 등록:', doc.title, doc.start_time);
      });
    }
    // DELETE /schedules/:id — 삭제
    else if(req.method === 'DELETE' && req.url.startsWith('/schedules/')) {
      const { ObjectId } = require('mongodb');
      const id = req.url.split('/')[2];
      await col.deleteOne({_id: new ObjectId(id)});
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify({ok:true}));
    }
    else { res.writeHead(404); res.end(); }
  } catch(e) {
    res.writeHead(500); res.end(JSON.stringify({ok:false, error:e.message}));
  } finally {
    await client.close();
  }
});
schedApi.listen(8022, () => console.log('[schedApi] 포트 8022 시작'));

// 쇼핑몰 API (포트 8023)
const shopApi = require('http').createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if(req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  const { MongoClient, ObjectId } = require('mongodb');
  const client = await MongoClient.connect('mongodb://localhost:27017', {useUnifiedTopology:true});
  const db = client.db('tob');

  try {
    const url = new URL(req.url, 'http://localhost');

    // GET /balance?user=xxx
    if(req.method === 'GET' && url.pathname === '/balance') {
      const userId = url.searchParams.get('user');
      const user = await db.collection('users').findOne({user_id: userId}, {projection:{coin:1}});
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify({coin: user ? user.coin : 0}));
    }
    // GET /products?cat=xxx
    else if(req.method === 'GET' && url.pathname === '/products') {
      const cat = url.searchParams.get('cat');
      const query = cat ? {category: cat} : {};
      const list = await db.collection('shop_products').find(query).sort({created_at:-1}).toArray();
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify(list));
    }
    // POST /products — 상품 등록
    else if(req.method === 'POST' && url.pathname === '/products') {
      const chunks = []; req.on('data', c => chunks.push(c));
      req.on('end', async () => {
        const body = JSON.parse(Buffer.concat(chunks).toString());
        const doc = {
          name: body.name, category: body.category, emoji: body.emoji || '📦',
          price_grain: body.price_grain, description: body.description || '',
          stock: body.stock !== undefined ? body.stock : -1,
          is_new: true, is_hot: false, created_at: new Date()
        };
        const result = await db.collection('shop_products').insertOne(doc);
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:true, id: result.insertedId}));
        console.log('[shop] 상품 등록:', doc.name, doc.price_grain, 'grain');
      });
    }
    // POST /buy — 구매
    else if(req.method === 'POST' && url.pathname === '/buy') {
      const chunks = []; req.on('data', c => chunks.push(c));
      req.on('end', async () => {
        const { userId, productId } = JSON.parse(Buffer.concat(chunks).toString());
        const product = await db.collection('shop_products').findOne({_id: new ObjectId(productId)});
        if(!product) { res.writeHead(404); return res.end(JSON.stringify({ok:false,error:'상품 없음'})); }
        if(product.stock === 0) { res.writeHead(400); return res.end(JSON.stringify({ok:false,error:'품절'})); }
        const user = await db.collection('users').findOne({user_id: userId});
        if(!user || user.coin < product.price_grain) {
          res.writeHead(400); return res.end(JSON.stringify({ok:false,error:'AU 부족'}));
        }
        // 코인 차감
        await db.collection('users').updateOne({user_id: userId}, {$inc:{coin: -product.price_grain}});
        // 재고 감소
        if(product.stock > 0) await db.collection('shop_products').updateOne({_id: new ObjectId(productId)}, {$inc:{stock:-1}});
        // 주문 기록
        await db.collection('shop_orders').insertOne({
          user_id: userId, product_id: productId, product_name: product.name,
          price_grain: product.price_grain, status: 'paid', created_at: new Date()
        });
        const updated = await db.collection('users').findOne({user_id: userId}, {projection:{coin:1}});
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify({ok:true, balance: updated.coin}));
        console.log('[shop] 구매:', userId, product.name, product.price_grain, 'grain');
      });
    }
    else { res.writeHead(404); res.end(); }
  } catch(e) {
    res.writeHead(500); res.end(JSON.stringify({ok:false, error:e.message}));
  } finally { await client.close(); }
});
shopApi.listen(8023, () => console.log('[shopApi] 포트 8023 시작'));

// goRoom 실시간 대국 불러오기
