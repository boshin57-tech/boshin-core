const pty = require('/home/boshin57/Tobmate_Live/node_modules/node-pty');

const p = pty.spawn('wine', ['go_real.exe'], {
  name: 'xterm',
  cols: 200,
  rows: 50,
  cwd: '/home/boshin57/Tobmate_Live/dist/ai/go/bin/Final',
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
    if (line && !line.startsWith('Initializing') && !line.startsWith('Setting') && !line.startsWith('----') && !line.startsWith('###') && !line.startsWith('patt')) {
      process.stdout.write(line + '\n');
    }
  });
});

p.on('exit', code => process.exit(code || 0));

process.stdin.on('data', d => {
  p.write(d.toString().replace(/\n/g, '\r\n'));
});

process.stdin.resume();
