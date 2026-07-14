// mediasoup-config.js
// 환경변수로 서버마다 다른 값(공인 IP 등)을 주입할 수 있게 설계
// 사용 예: MEDIASOUP_ANNOUNCED_IP=1.2.3.4 pm2 start mediasoup-server.js

const os = require('os');

module.exports = {
  // ── Socket.io 시그널링 서버 포트 (기존 goRoom 등과 겹치지 않는 대역) ──
  signalPort: process.env.MEDIASOUP_SIGNAL_PORT || 8020,

  // ── mediasoup Worker 설정 ──
  worker: {
    // CPU 코어 수만큼 워커를 띄워 부하 분산 (최소 1개)
    numWorkers: Math.max(1, parseInt(process.env.MEDIASOUP_NUM_WORKERS) || os.cpus().length),
    rtcMinPort: parseInt(process.env.MEDIASOUP_RTC_MIN_PORT) || 40000,
    rtcMaxPort: parseInt(process.env.MEDIASOUP_RTC_MAX_PORT) || 49999,
    logLevel: 'warn',
    logTags: ['info', 'ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
  },

  // ── WebRtcTransport 설정 ──
  webRtcTransport: {
    listenIps: [
      {
        ip: process.env.MEDIASOUP_LISTEN_IP || '0.0.0.0',
        // announcedIp: 클라이언트에게 알려줄 "공인 IP". 반드시 실제 서버의 공인 IP로 설정해야
        // 방화벽 뒤에서도 클라이언트가 정상적으로 접속할 수 있음.
        announcedIp: process.env.MEDIASOUP_ANNOUNCED_IP || null,
      },
    ],
    initialAvailableOutgoingBitrate: 800000,
    maxIncomingBitrate: 1500000,
  },

  // ── 지원 코덱 (오디오 Opus + 비디오 VP8 — 브라우저 호환성 가장 넓음) ──
  mediaCodecs: [
    {
      kind: 'audio',
      mimeType: 'audio/opus',
      clockRate: 48000,
      channels: 2,
    },
    {
      kind: 'video',
      mimeType: 'video/VP8',
      clockRate: 90000,
      parameters: {
        'x-google-start-bitrate': 1000,
      },
    },
    {
      kind: 'video',
      mimeType: 'video/H264',
      clockRate: 90000,
      parameters: {
        'packetization-mode': 1,
        'profile-level-id': '42e01f',
        'level-asymmetry-allowed': 1,
      },
    },
  ],
};
