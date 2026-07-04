const fs = require('fs');
const path = '/home/boshin57/Tobmate_Live/dist/goRoom.js';

// 백업
fs.copyFileSync(path, path + '.bak_lecture_' + Date.now());

let code = fs.readFileSync(path, 'utf8');
let ok = 0;

// 패치 1: doMoveAfter 내부 SC_GAME_MOVE emit 직후 훅 삽입
// 기존: this.broadcastInRoom(o.SC_GAME_MOVE,a.SUCCESS,{move:t,turn:r,countdown:this.getCountdown()})
const MOVE_ANCHOR = 'this.broadcastInRoom(o.SC_GAME_MOVE,a.SUCCESS,{move:t,turn:r,countdown:this.getCountdown()})';
const MOVE_PATCH  = MOVE_ANCHOR + ';try{const _lurl="http://localhost:8016/lecture?lastMove="+t+"&playerTPI="+(this.players[r]&&this.players[r].tpi||0)+"&winrate=0.5&bestMove=";this.broadcastInRoom&&this.users&&this.users.forEach(function(u){if(u&&u.websocket)u.websocket.emit("sc_message",9999,0,{lectureUrl:_lurl});});}catch(_le){}';

if (code.includes(MOVE_ANCHOR)) {
  code = code.replace(MOVE_ANCHOR, MOVE_PATCH);
  ok++;
  console.log('OK: CS_GAME_MOVE 훅 삽입');
} else {
  console.log('WARN: MOVE anchor 없음 — 대안 패치 시도');
  // 대안: sendToLobby 직전에 훅 삽입
  const ALT_ANCHOR = 'this.sendToLobby("ss_updated_room_info",this.getRoomInfo(n.ROOM_INFO_SCOPE.ABSTRACT))}';
  if (code.includes(ALT_ANCHOR)) {
    code = code.replace(ALT_ANCHOR, 
      'try{const _lurl="http://localhost:8016/lecture";global._lastLectureUrl=_lurl;}catch(_e){}\n' + ALT_ANCHOR);
    ok++;
    console.log('OK: 대안 훅 삽입');
  }
}

if (ok > 0) {
  fs.writeFileSync(path, code);
  console.log('=== goRoom.js 패치 완료! ok=' + ok + ' ===');
} else {
  console.log('=== 패치 없음 — 수동 확인 필요 ===');
}
