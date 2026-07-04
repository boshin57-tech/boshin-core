const pty = require('/home/boshin57/Tobmate_Live/node_modules/node-pty');
const path = require('path');

const DIR = '/home/boshin57/Tobmate_Live/dist/ai/go/bin/Final';

const p = pty.spawn('wine', ['go_real.exe'], {
  name: 'xterm',
  cols: 200,
  rows: 50,
  cwd: DIR,
  env: Object.assign({}, process.env, {
    WINEARCH: 'win64',
    WINEPREFIX: '/home/boshin57/.wine64',
    WINEDEBUG: '-all'
  })
});

function clean(s) {
  return s.replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, '')
          .replace(/\r/g, '')
          .replace(/[^\x20-\x7E\n]/g, '');
}

let buf = '';
p.on('data', d => {
  buf += clean(d);
  const lines = buf.split('\n');
  buf = lines.pop();
  lines.forEach(line => {
    line = line.trim();
    if (line) process.stdout.write(line + '\n');
  });
});

p.on('exit', code => {
  process.stderr.write('go_real.exe exited: ' + code + '\n');
  process.exit(code);
});

process.stdin.on('data', d => {
  p.write(d.toString());
});

process.stdin.resume();
