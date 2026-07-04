const http = require('http');
const { spawn } = require('child_process');

const KATAGO_BIN = '/home/boshin57/katago_opencl/katago';
const MODEL = '/home/boshin57/katago_cuda/kata1-b18c384nbt-s9996604416-d4316597426.bin.gz';
const CONFIG = '/home/boshin57/katago_cuda/default_gtp.cfg';

let katagoProcess = null;
let pendingCallback = null;
let buffer = '';

function startKatago() {
  katagoProcess = spawn(KATAGO_BIN, ['gtp', '-model', MODEL, '-config', CONFIG]);
  katagoProcess.stdout.on('data', (data) => {
    buffer += data.toString();
    if (buffer.includes('\n')) {
      const lines = buffer.split('\n');
      buffer = lines.pop();
      lines.forEach(line => {
        line = line.trim();
        if (line.startsWith('=') && pendingCallback) {
          const cb = pendingCallback;
          pendingCallback = null;
          cb(null, line.slice(1).trim());
        }
      });
    }
  });
  katagoProcess.stderr.on('data', (d) => console.log('[KATAGO]', d.toString().slice(0,100)));
  katagoProcess.on('exit', (code) => {
    console.log('[KATAGO] 종료:', code);
    setTimeout(startKatago, 3000);
  });
  console.log('[KATAGO] 시작됨');
}

function sendCommand(cmd, cb) {
  if (!katagoProcess) return cb('katago not ready');
  pendingCallback = cb;
  katagoProcess.stdin.write(cmd + '\n');
}

function posToGTP(pos, boardsize) {
  if (pos === -1 || pos === 65535) return 'pass';
  const cols = 'ABCDEFGHJKLMNOPQRST';
  const x = pos % boardsize;
  const y = Math.floor(pos / boardsize);
  return cols[x] + (boardsize - y);
}

function gtpToPos(gtp, boardsize) {
  if (!gtp || gtp.toLowerCase() === 'pass') return -1;
  const cols = 'ABCDEFGHJKLMNOPQRST';
  const x = cols.indexOf(gtp[0].toUpperCase());
  const y = boardsize - parseInt(gtp.slice(1));
  return y * boardsize + x;
}

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/event') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const { protocol, data } = JSON.parse(body);
        if (protocol === 832 && data) {
          // 게임 시작 - katago 초기화
          const boardsize = data.setting ? (data.setting.boardsize || 19) : 19;
          const komi = data.setting ? (data.setting.komi || 6.5) : 6.5;
          sendCommand('boardsize ' + boardsize, () => {
            sendCommand('komi ' + komi, () => {
              sendCommand('clear_board', () => {
                console.log('[KATAGO] 게임 준비 완료');
              });
            });
          });
        }
        res.writeHead(200);
        res.end('ok');
      } catch(e) {
        res.writeHead(400);
        res.end('err');
      }
    });
  } else if (req.method === 'POST' && req.url === '/genmove') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      try {
        const { color, moves, boardsize, komi } = JSON.parse(body);
        const bs = boardsize || 19;
        // 기보 재구성
        sendCommand('boardsize ' + bs, () => {
          sendCommand('komi ' + (komi || 6.5), () => {
            sendCommand('clear_board', () => {
              const playMoves = (idx) => {
                if (idx >= moves.length) {
                  const c = color === 1 ? 'b' : 'w';
                  sendCommand('genmove ' + c, (err, move) => {
                    const pos = gtpToPos(move, bs);
                    res.writeHead(200, {'Content-Type':'application/json'});
                    res.end(JSON.stringify({move: pos, gtp: move}));
                  });
                  return;
                }
                const m = moves[idx];
                const mc = m.color === 1 ? 'b' : 'w';
                const gtp = posToGTP(m.pos, bs);
                sendCommand('play ' + mc + ' ' + gtp, () => playMoves(idx+1));
              };
              playMoves(0);
            });
          });
        });
      } catch(e) {
        res.writeHead(400);
        res.end('err');
      }
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(8016, () => console.log('[KATAGO SERVER] 포트 8016 시작'));
startKatago();
