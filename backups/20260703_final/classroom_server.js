// classroom3d 멀티 아바타 위치 동기화 서버 (포트 8030)
const http = require('http');
const server = http.createServer();
const io = require('socket.io')(server, {
  path: '/classroom/socket.io',
  cors: { origin: '*' }
});

// room -> { socketId: {id, name, gender, x, y, z, ry} }
const rooms = {};
// room -> [{c,r}] 공유 수순
const moves = {};

io.on('connection', (socket) => {
  let myRoom = null;

  socket.on('c3d_join', (data) => {
    myRoom = data.room || 'main';
    socket.join(myRoom);
    if (!rooms[myRoom]) rooms[myRoom] = {};
    rooms[myRoom][socket.id] = {
      id: socket.id,
      name: (data.name || '학생').slice(0, 12),
      gender: data.gender || 'm',
      x: data.x || 0, y: data.y || 0, z: data.z || 8, ry: data.ry || 0
    };
    // 새 학생에게 기존 인원 전체 전달
    socket.emit('c3d_roster', Object.values(rooms[myRoom]).filter(p => p.id !== socket.id));
    if (moves[myRoom] && moves[myRoom].length) socket.emit('c3d_sync', moves[myRoom]);
    // 기존 인원에게 새 학생 알림
    socket.to(myRoom).emit('c3d_enter', rooms[myRoom][socket.id]);
    console.log(`[C3D] 입장: ${rooms[myRoom][socket.id].name} (${myRoom}, 총 ${Object.keys(rooms[myRoom]).length}명)`);
  });

  socket.on('c3d_pos', (data) => {
    if (!myRoom || !rooms[myRoom] || !rooms[myRoom][socket.id]) return;
    const p = rooms[myRoom][socket.id];
    p.x = data.x; p.y = data.y; p.z = data.z; p.ry = data.ry;
    socket.to(myRoom).emit('c3d_pos', { id: socket.id, x: p.x, y: p.y, z: p.z, ry: p.ry });
  });

  socket.on('c3d_move', (d) => {
    if (!myRoom) return;
    if (!moves[myRoom]) moves[myRoom] = [];
    moves[myRoom].push({ c: d.c, r: d.r });
    socket.to(myRoom).emit('c3d_move', { c: d.c, r: d.r });
  });

  socket.on('c3d_ctrl', (d) => {
    if (!myRoom) return;
    if (!moves[myRoom]) moves[myRoom] = [];
    if (d.act === 'undo') moves[myRoom].pop();
    else if (d.act === 'reset') moves[myRoom] = [];
    socket.to(myRoom).emit('c3d_ctrl', { act: d.act });
  });

  socket.on('c3d_chat', (d) => {
    if (!myRoom || !rooms[myRoom] || !rooms[myRoom][socket.id]) return;
    const msg = String(d.msg || '').slice(0, 120).trim();
    if (!msg) return;
    const name = rooms[myRoom][socket.id].name;
    io.to(myRoom).emit('c3d_chat', { id: socket.id, name: name, msg: msg });
    console.log('[C3D-CHAT] ' + name + ': ' + msg.slice(0, 40));
  });

  socket.on('disconnect', () => {
    if (myRoom && rooms[myRoom] && rooms[myRoom][socket.id]) {
      const name = rooms[myRoom][socket.id].name;
      delete rooms[myRoom][socket.id];
      socket.to(myRoom).emit('c3d_leave', { id: socket.id });
      if (Object.keys(rooms[myRoom]).length === 0) delete rooms[myRoom];
      console.log(`[C3D] 퇴장: ${name}`);
    }
  });
});

server.listen(8030, () => console.log('[C3D] classroom3d 소켓 서버 :8030 (path=/classroom/socket.io)'));
