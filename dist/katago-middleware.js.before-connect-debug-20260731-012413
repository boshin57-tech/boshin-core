const { spawn } = require('child_process');
require('dns').setDefaultResultOrder('ipv4first');
const http = require('http');
const io = require('/home/boshin57/Tobmate_Live/node_modules/socket.io-client');

const KATAGO = '/home/boshin57/katago_opencl/katago';
const MODEL = '/home/boshin57/katago_cuda/kata1-b18c384nbt-s9996604416-d4316597426.bin.gz';
const CFG = '/home/boshin57/katago_cuda/default_gtp.cfg';
const GOROOM_URL = 'http://localhost';
const GOROOM_PATH = '/go_room/socket.io/';
const BOT_TOKEN = 'tob_bot';
const COLS = 'ABCDEFGHJKLMNOPQRST';
const PASS_MOVE = 8224;

// 순장바둑 초기 배치
const SJ_BLACK = ['D4','D7','D13','K4','K16','Q7','Q13','Q16'];
const SJ_WHITE = ['D10','D16','G4','G16','N4','N16','Q4','Q10'];
const HANDICAP_STONES = ['K10','N7','G13','N13','G7','K13','K7','N10','G10'];

function wpos2coord(wpos) {
    if(wpos === PASS_MOVE) return 'pass';
    const x = wpos & 255; const y = (wpos >> 8) & 255;
    return COLS[x] + (19 - y);
}
function coord2wpos(coord) {
    if(!coord || coord.toLowerCase() === 'pass' || coord.toLowerCase() === 'resign') return PASS_MOVE;
    const x = COLS.indexOf(coord[0].toUpperCase());
    const y = 19 - parseInt(coord.slice(1));
    return (y << 8) | x;
}

const roomStates = {};

function createKataGoGTP() {
    const gtp = spawn(KATAGO, ['gtp', '-config', CFG, '-model', MODEL], { env: Object.assign({}, process.env, { HOME: '/home/boshin57', OCL_ICD_VENDORS: '/etc/OpenCL/vendors', LD_LIBRARY_PATH: '/usr/lib/x86_64-linux-gnu:' + (process.env.LD_LIBRARY_PATH||'') }) });
    let buf = '';
    const pending = [];
    gtp.stdout.on('data', function(d) {
        buf += d.toString();
        while(true) {
            const idx = buf.indexOf('\n\n');
            if(idx < 0) break;
            const resp = buf.substring(0, idx).trim();
            buf = buf.substring(idx+2);
            if(pending.length > 0) { const cb = pending.shift(); cb(resp); }
        }
    });
    gtp.stderr.on('data', function(d) { const m=d.toString().trim(); if(m) console.log('[GTP]',m); });
    gtp.on('exit', function() { console.log('[GTP] 종료'); });
    gtp.cmd = function(cmd, cb) { pending.push(cb||function(){}); gtp.stdin.write(cmd+'\n'); };
    return gtp;
}

function initBoard(state, data, callback) {
    const gtp = state.gtp;
    gtp.cmd('boardsize '+state.boardsize, function() {
        gtp.cmd('clear_board', function() {
            gtp.cmd('komi 6.5', function() {
                if(state.rule === 2) {
                    // 순장바둑 초기 배치 (접바둑 포함)
                    const cmds = [];
                    SJ_BLACK.forEach(function(c){ cmds.push(['play B '+c]); });
                    SJ_WHITE.forEach(function(c){ cmds.push(['play W '+c]); });
                    if(data.handicap && data.handicap > 0) {
                        HANDICAP_STONES.slice(0, data.handicap).forEach(function(c){ cmds.push(['play B '+c]); });
                    }
                    var runCmd = function(idx) {
                        if(idx >= cmds.length) {
                            // 흑8+백8=16수 후 다음은 흑차례, first_turn===1(백먼저)이면 흑패스로 턴조정
                            console.log('[GTP] 순장바둑 초기화 완료');
                            callback();
                            return;
                        }
                        gtp.cmd(cmds[idx][0], function(r){ console.log('[GTP] SJ배석:', cmds[idx][0], '->', r); runCmd(idx+1); });
                    };
                    runCmd(0);
                } else if(data.handicap && data.handicap > 1) {
                    // 일반 접바둑: 화점 접바둑 배석만 (순장 배석 없음)
                    const cmds = [];
                    HANDICAP_STONES.slice(0, data.handicap).forEach(function(c){ cmds.push('play B '+c); });
                    var runCmd = function(idx) {
                        if(idx >= cmds.length) {
                            console.log('[GTP] 접바둑 초기화 완료 handicap='+data.handicap);
                            callback();
                            return;
                        }
                        gtp.cmd(cmds[idx], function(){ runCmd(idx+1); });
                    };
                    runCmd(0);
                } else {
                    console.log('[GTP] 보드 초기화 완료');
                    callback();
                }
            });
        });
    });
}

function connectBotToRoom(roomId) {
    console.log('[BOT] 방에 연결:', roomId);
    const botSocket = io(GOROOM_URL, {path: GOROOM_PATH, reconnection: true, reconnectionAttempts: 5, reconnectionDelay: 1000});
    const gtp = createKataGoGTP();
    roomStates[roomId] = {botSocket, gtp, colors:[1,2], botColor:null, boardsize:19, _lastBotMove:null, _gameStarted:false, _genMoving:false, _boardReady:false};

    botSocket.on('connect', function() {
        console.log('[BOT] 소켓 연결됨');
        setTimeout(function() {
            botSocket.emit('cs_message', 788, {token:BOT_TOKEN, room_id:roomId});
        }, 500);
    });

    botSocket.on('sc_message', function(protocol, err, data) {
        const state = roomStates[roomId];
        if(!state) return;
        if(protocol === 800) console.log('[BOT] 입장 성공!');
        if(protocol === 817) {
            console.log('[BOT] SC_START_PREPARE - 준비 완료!');
            setTimeout(function() {
                botSocket.emit('cs_message', 818, {token:BOT_TOKEN, room_id:roomId});
            }, 500);
        }
        if(protocol === 832) {
            if(state._gameStarted) return; // 중복 처리 방지
            state._gameStarted = true; state._boardReady = false; state._genMoving = false; state._lastBotMove = null;
            console.log('[BOT] SC_GAME_START! colors:', data.colors, 'first_turn:', data.first_turn);
            state.colors = data.colors || [1,2];
            state.boardsize = data.board_size || 19;
            state.rule = (data.rule !== undefined && data.rule !== null) ? data.rule : 0;  // goRoom이 보낸 rule 존중 (0=일본식,1=중국식,2=순장)
            state.botColor = state.colors[1] === 1 ? "B" : "W";
            console.log('[BOT] 봇 색상:', state.botColor);
            initBoard(state, data, function() { state._boardReady = true;
                if(state._pendingMove) {
                    var pm = state._pendingMove;
                    state._pendingMove = null;
                    console.log('[BOT] pendingMove 처리:', pm.coord);
                    if(pm.moverColor !== state.botColor) {
                        state.gtp.cmd('play '+pm.moverColor+' '+pm.coord, function(resp){
                            console.log('[GTP] pending play:', resp);
                            setTimeout(function(){ genMove(roomId); }, 300);
                        });
                    }
                    return;
                }
                if(data.first_turn === 1) {
                    setTimeout(function() { genMove(roomId); }, 300);
                }
            });
        }
        if(protocol === 835) {
            if(!data) return;
            const moverColor = state.colors[data.turn] === 1 ? 'B' : 'W';
            const coord = wpos2coord(data.move);
            console.log('[BOT] 835: turn='+data.turn+' moverColor='+moverColor+' coord='+coord+' botColor='+state.botColor+' lastMove='+state._lastBotMove+' genMoving='+state._genMoving);
            if(!state._boardReady) {
                console.log('[BOT] 보드준비중 835큐저장');
                state._pendingMove = {moverColor, coord, data};
                return;
            }
            if(moverColor === state.botColor) {
                console.log('[BOT] 자기수 무시');
                state._lastBotMove = null;
                state._genMoving = false;
                return;
            }
            if(state._genMoving) { console.log('[BOT] genMoving 중 무시'); return; }
            if(coord === 'pass') {
                console.log('[BOT] 상대 통과 - 봇도 통과');
                state._lastBotMove = PASS_MOVE;
                state._genMoving = false;
                state.botSocket.emit('cs_message', 834, {token:BOT_TOKEN, room_id:roomId, move:PASS_MOVE});
                return;
            }
            state.gtp.cmd('play '+moverColor+' '+coord, function(resp) {
                console.log('[GTP] play:', resp);
                setTimeout(function() { genMove(roomId); }, 300);
            });
        }
        if(protocol === 833 || protocol === 785) {
            console.log('[BOT] 게임 종료/퇴장');
            state._gameStarted = false;
            if(protocol === 785) {
                delete roomStates[roomId];
                gtp.stdin.write('quit\n');
                botSocket.disconnect();
            }
        }
    });

    botSocket.on('disconnect', function(reason) {
        console.log('[BOT] 소켓 끊김 이유:', reason);
    });
}

function genMove(roomId) {
    const state = roomStates[roomId];
    if(!state) return;
    console.log('[GTP] genmove', state.botColor);
    state._genMoving = true;
    state.gtp.cmd('genmove '+state.botColor, function(resp) {
        console.log('[GTP] genmove 응답:', resp);
        const parts = resp.split(' ');
        const moveStr = parts[parts.length-1].trim();
        const wpos = coord2wpos(moveStr);
        console.log('[BOT] 봇 착수:', moveStr, '->', wpos);
        state._lastBotMove = wpos;
        state.botSocket.emit('cs_message', 834, {token:BOT_TOKEN, room_id:roomId, move:wpos});
    });
}

const server = http.createServer(function(req, res) {
    if(req.method === 'POST' && req.url === '/bot/join') {
        let body = '';
        req.on('data', function(chunk) { body += chunk; });
        req.on('end', function() {
            try {
                const parsed = JSON.parse(body);
                const roomId = parsed.room_id;
                if(!roomStates[roomId]) { connectBotToRoom(roomId); }
                res.end('ok');
            } catch(e) { res.end('error'); }
        });
    } else { res.end('ok'); }
});
server.on('error', function(e) { console.log('[HTTP] 에러:', e.code); process.exit(1); });
server.listen(8099, '0.0.0.0', function() { console.log('[KataGo GTP] HTTP 포트 8099 시작'); });

// /score 엔드포인트 - goRoom auto_scoring 처리
const http2 = require('http');
const scoreServer = http2.createServer(function(req, res) {
    if(req.method === 'POST' && req.url === '/score2') {
        let body='';
        req.on('data', function(d){ body+=d; });
        req.on('end', function(){
            try{
                const j=JSON.parse(body);
                const brd=j.board||'';
                const bs=j.boardsize||19;
                if(!global._deadGtp){ global._deadGtp=createKataGoGTP(); global._deadBusy=false; console.log('[SCORE2] 전용 GTP 생성'); }
                if(global._deadBusy){ res.writeHead(200,{'Content-Type':'application/json'}); res.end(JSON.stringify({result:'',busy:true})); return; }
                global._deadBusy=true;
                const g=global._deadGtp;
                const COLS2='ABCDEFGHJKLMNOPQRST';
                let done=false;
                const timer=setTimeout(function(){ if(!done){done=true; global._deadBusy=false; res.writeHead(200,{'Content-Type':'application/json'}); res.end(JSON.stringify({result:'',timeout:true}));} },25000);
                g.cmd('boardsize '+bs, function(){
                g.cmd('clear_board', function(){
                    const plays=[];
                    for(let r=0;r<bs;r++)for(let c=0;c<bs;c++){
                        const ch=brd[r*bs+c];
                        if(ch==='b')plays.push('play B '+COLS2[c]+(r+1));
                        else if(ch==='w')plays.push('play W '+COLS2[c]+(r+1));
                    }
                    let pi=0;
                    (function next(){
                        if(pi>=plays.length){
                            g.cmd('final_score', function(resp){
                                if(done)return; done=true; clearTimeout(timer); global._deadBusy=false;
                                var s=resp.replace(/^[=?]\s*/,'').trim();
                                var m=s.match(/([BW])[+]([0-9.]+)/);
                                var bsum=0,wsum=0,result=s;
                                if(m){ var pts=Math.round(parseFloat(m[2])); if(m[1]==='B'){bsum=pts;} else {wsum=pts;} }
                                console.log('[SCORE2] final_score:', s, '→ bsum', bsum, 'wsum', wsum);
                                res.writeHead(200,{'Content-Type':'application/json'});
                                res.end(JSON.stringify({result:result, bsum:bsum, wsum:wsum}));
                            });
                            return;
                        }
                        g.cmd(plays[pi++], function(){ next(); });
                    })();
                });
                });
            }catch(e){ res.writeHead(200); res.end(JSON.stringify({result:'',error:e.message})); }
        });
    } else     if(req.method === 'POST' && req.url === '/eval') {
        let body='';
        req.on('data', function(d){ body+=d; });
        req.on('end', function(){
            try{
                const j=JSON.parse(body);
                const brd=j.board||''; const bs=j.boardsize||19;
                const komi=(j.komi!==undefined)?j.komi:0;
                if(!global._evalProc){
                    const cp=require('child_process'); const path2=require('path');
                    const exe=path2.join(process.cwd(),'dist/ai/go/bin/Final_Train/go_train.exe');
                    global._evalProc=cp.spawn(exe);
                    global._evalCbs={}; global._evalBuf='';
                    global._evalProc.stdout.on('data', function(d){
                        global._evalBuf+=d.toString();
                        let lines=global._evalBuf.split('\n'); global._evalBuf=lines.pop();
                        lines.forEach(function(line){
                            var t=line.trim().split(/\s+/);
                            if(t[0]==='eval_territory'&&t.length>=4){
                                var id=t[1],bsum=parseInt(t[2]),wsum=parseInt(t[3]);
                                if(global._evalCbs[id]){global._evalCbs[id](bsum,wsum);delete global._evalCbs[id];}
                            }
                        });
                    });
                    global._evalProc.stderr.on('data',function(d){console.log('[EVAL stderr]',d.toString().slice(0,200));});
                    global._evalProc.on('exit',function(code){console.log('[EVAL] 프로세스 종료',code);global._evalProc=null;});
                    console.log('[EVAL] go_train 프로세스 생성');
                }
                var id='r'+Date.now(); var done=false;
                var timer=setTimeout(function(){if(!done){done=true;delete global._evalCbs[id];res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({bsum:0,wsum:0,timeout:true}));}},20000);
                global._evalCbs[id]=function(bsum,wsum){
                    if(done)return;done=true;clearTimeout(timer);
                    console.log('[EVAL]',id,'bsum',bsum,'wsum',wsum);
                    res.writeHead(200,{'Content-Type':'application/json'});
                    res.end(JSON.stringify({bsum:bsum,wsum:wsum}));
                };
                global._evalProc.stdin.write('eval_territory '+id+' '+bs+' '+komi+' '+brd+'\n');
            }catch(e){res.writeHead(200);res.end(JSON.stringify({bsum:0,wsum:0,error:e.message}));}
        });
    } else     if(req.method === 'POST' && req.url === '/dead') {
        let body='';
        req.on('data', function(d){ body+=d; });
        req.on('end', function(){
            try{
                const j=JSON.parse(body);
                const brd=j.board||'';
                const bs=j.boardsize||19;
                if(!global._deadGtp){
                    global._deadGtp=createKataGoGTP();
                    global._deadBusy=false;
                    console.log('[DEAD] 계가전용 GTP 생성');
                }
                if(global._deadBusy){
                    res.writeHead(200,{'Content-Type':'application/json'});
                    res.end(JSON.stringify({dead:[],busy:true}));
                    return;
                }
                global._deadBusy=true;
                const g=global._deadGtp;
                const COLS2='ABCDEFGHJKLMNOPQRST';
                let done=false;
                const timer=setTimeout(function(){ if(!done){done=true; global._deadBusy=false; res.writeHead(200,{'Content-Type':'application/json'}); res.end(JSON.stringify({dead:[],timeout:true}));} },25000);
                g.cmd('boardsize '+bs, function(){
                g.cmd('clear_board', function(){
                    const plays=[];
                    for(let r=0;r<bs;r++)for(let c=0;c<bs;c++){
                        const ch=brd[r*bs+c];
                        if(ch==='b')plays.push('play B '+COLS2[c]+(r+1));
                        else if(ch==='w')plays.push('play W '+COLS2[c]+(r+1));
                    }
                    let pi=0;
                    (function next(){
                        if(pi>=plays.length){
                            g.cmd('final_status_list dead', function(resp){
                                if(done)return; done=true; clearTimeout(timer); global._deadBusy=false;
                                const dead=[];
                                resp.replace(/^[=?]\s*/,'').trim().split(/\s+/).forEach(function(p){
                                    if(!p||p.length<2)return;
                                    const x=COLS2.indexOf(p[0].toUpperCase());
                                    const y=parseInt(p.slice(1))-1;
                                    if(x>=0&&y>=0)dead.push({r:y,c:x});
                                });
                                console.log('[DEAD] 사석',dead.length,'개');
                                res.writeHead(200,{'Content-Type':'application/json'});
                                res.end(JSON.stringify({dead:dead}));
                            });
                            return;
                        }
                        g.cmd(plays[pi++], function(){ next(); });
                    })();
                });
                });
            }catch(e){ res.writeHead(200); res.end(JSON.stringify({dead:[],error:e.message})); }
        });
    } else if(req.method === 'POST' && req.url === '/score') {
        let body = '';
        req.on('data', function(d){ body += d; });
        req.on('end', function(){
            try {
                const j = JSON.parse(body);
                const roomId = j.room_id;
                const brd = j.board || '';
                const bs = j.boardsize || 19;
                const state = roomStates[roomId] || Object.values(roomStates)[0];
                console.log('[SCORE] room:', roomId, 'state:', !!state);
                if(!state || !state.gtp) {
                    res.writeHead(200); res.end(JSON.stringify({bsum:0,wsum:0,tboard:[]})); return;
                }
                const gtp = state.gtp;
                const MX = 19;
                function parseCoords(resp){
                    var coords=[];
                    var COLS2='ABCDEFGHJKLMNOPQRST';
                    var parts=resp.replace(/^[=?]\s*/,'').trim().split(/\s+/);
                    parts.forEach(function(p){
                        p=p.trim();
                        if(!p||p.length<2) return;
                        var x=COLS2.indexOf(p[0].toUpperCase());
                        var y=parseInt(p.slice(1))-1;
                        if(x>=0&&y>=0) coords.push({r:y,c:x});
                    });
                    return coords;
                }
                function calcTerritory(brd2, bs, dead){
                    var tboard=new Uint8Array(MX*MX);
                    var bsum=0,wsum=0;
                    var board2=brd2.split('');
                    dead.forEach(function(p){
                        var idx=p.r*bs+p.c;
                        if(board2[idx]==='b'){ wsum++; tboard[p.r*MX+p.c]=87; board2[idx]='e'; }
                        else if(board2[idx]==='w'){ bsum++; tboard[p.r*MX+p.c]=66; board2[idx]='e'; }
                    });
                    var brd3=board2.join('');
                    function gs(r,c){ var ch=brd3[r*bs+c]; return ch==='b'?'b':ch==='w'?'w':'e'; }
                    var visited=new Array(bs*bs).fill(false);
                    for(var r=0;r<bs;r++){
                        for(var c=0;c<bs;c++){
                            if(gs(r,c)==='e'&&!visited[r*bs+c]){
                                var queue=[{r:r,c:c}];
                                var cells=[];
                                var borders=new Set();
                                visited[r*bs+c]=true;
                                while(queue.length>0){
                                    var cur=queue.shift();
                                    cells.push(cur);
                                    var dirs=[[0,1],[0,-1],[1,0],[-1,0]];
                                    for(var di=0;di<dirs.length;di++){
                                        var nr=cur.r+dirs[di][0],nc=cur.c+dirs[di][1];
                                        if(nr<0||nr>=bs||nc<0||nc>=bs) continue;
                                        var ns=gs(nr,nc);
                                        if(ns==='e'&&!visited[nr*bs+nc]){visited[nr*bs+nc]=true;queue.push({r:nr,c:nc});}
                                        else if(ns!=='e'){borders.add(ns);}
                                    }
                                }
                                if(borders.size===1){
                                    var owner=borders.has('b')?'B':'W';
                                    cells.forEach(function(p){
                                        tboard[p.r*MX+p.c]=owner==='B'?66:87;
                                        if(owner==='B')bsum++;else wsum++;
                                    });
                                }
                            }
                        }
                    }
                    return {bsum:bsum,wsum:wsum,tboard:tboard};
                }
                gtp.cmd('final_score', function(scoreResp){
                    console.log('[SCORE] final_score:', scoreResp);
                    // 순장바둑: final_score만 파싱, dead stones 불필요
                    // B+32.5 또는 W+12.5 형식 파싱
                    var bsum=0, wsum=0;
                    var m = scoreResp.match(/([BW])[+]([0-9.]+)/);
                    if(m){
                        var pts = Math.round(parseFloat(m[2])); // 접바둑=정수, 호선=반올림
                        if(m[1]==='B'){ bsum=pts; wsum=0; }
                        else { wsum=pts; bsum=0; }
                    }
                    console.log('[SCORE] bsum:',bsum,'wsum:',wsum);
                    // tboard는 floodFill로 계산 (집 영역 표시용)
                    var tboard = calcTerritory(brd, bs, []).tboard;
                    res.writeHead(200,{'Content-Type':'application/json'});
                    res.end(JSON.stringify({bsum:bsum,wsum:wsum,tboard:Array.from(tboard)}));
                });
            } catch(e2){
                console.log('[SCORE] 예외:',e2);
                res.writeHead(200); res.end(JSON.stringify({bsum:0,wsum:0,tboard:[]}));
            }
        });
    } else { res.writeHead(200); res.end(JSON.stringify({bsum:0,wsum:0,tboard:[]})); }
});
scoreServer.listen(8098, '0.0.0.0', function(){ console.log('[SCORE] HTTP 포트 8098 시작'); });

