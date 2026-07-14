const { io } = require('socket.io-client');

const socket = io('http://localhost:8024', { transports: ['websocket'] });

function emitAsync(event, payload) {
  return new Promise((resolve, reject) => {
    socket.emit(event, payload, (res) => {
      if (res && res.ok === false) reject(new Error(res.error));
      else resolve(res);
    });
  });
}

socket.on('connect', async () => {
  try {
    console.log('✅ 소켓 연결 성공');

    const joinRes = await emitAsync('ms_join_room', { room_id: 'test_room_1', user_id: 'student_A' });
    console.log('✅ ms_join_room 성공, rtpCapabilities 코덱 수:', joinRes.rtpCapabilities.codecs.length);
    console.log('   기존 참가자 수:', joinRes.existingProducers.length);

    const sendTransport = await emitAsync('ms_create_transport', { direction: 'send' });
    console.log('✅ send transport 생성 성공, id:', sendTransport.transportId);
    console.log('   iceCandidates 수:', sendTransport.iceCandidates.length);
    console.log('   dtlsParameters 존재:', !!sendTransport.dtlsParameters);

    const recvTransport = await emitAsync('ms_create_transport', { direction: 'recv' });
    console.log('✅ recv transport 생성 성공, id:', recvTransport.transportId);

    console.log('');
    console.log('🎉 전체 시그널링 흐름 정상 동작 확인');
    process.exit(0);
  } catch (err) {
    console.error('❌ 테스트 실패:', err.message);
    process.exit(1);
  }
});

socket.on('connect_error', (err) => {
  console.error('❌ 연결 실패:', err.message);
  process.exit(1);
});

setTimeout(() => {
  console.error('❌ 타임아웃');
  process.exit(1);
}, 8000);
