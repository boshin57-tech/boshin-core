'use strict';
const http = require('http');
const mongoose = require('mongoose');
const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/tob';
mongoose.connect(mongoUrl, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('[SAU-SERVER] MongoDB 연결 완료 db:', mongoUrl))
  .catch(e => console.error('[SAU-SERVER] MongoDB 오류:', e.message));

const userSchema = new mongoose.Schema({}, { strict: false, collection: 'users' });
const User = mongoose.model('SauUser', userSchema);
const cellSchema = new mongoose.Schema({}, { strict: false, collection: 'cells' });
const Cell = mongoose.model('Cell', cellSchema);
// EDGE_RESERVED: A열 전체 + 1행 전체 = Tobmate 긴급 사용 예약 (전 레이어 공통)
function isEdgeReserved(cell) {
  return /^A(1[0-8]|[1-9])$/.test(cell) || /^[A-S]1$/.test(cell);
}
function isReserved(layer, cell) {
  return isEdgeReserved(cell) || (RESERVED_CELLS[String(layer)] || []).includes(cell);
}
function sanitizeText(s, maxLen) { return String(s || '').replace(/[<>&"']/g, '').trim().slice(0, maxLen); }
async function sweepExpiredCells() {
  const cutoff = Date.now() - CELL_ACTIVATION_DAYS * 86400000;
  const expired = await Cell.find({ activated: false, purchased_at: { $lt: cutoff } });
  for (const cell of expired) {
    const refund = Math.floor(cell.paid_sau * CELL_REFUND_RATE);
    await User.updateOne({ user_id: cell.owner }, { $inc: { 'sau.total': refund } });
    console.log('[CELL] 회수: ' + cell.cell_id + ' (소유:' + cell.owner + ', 환급:' + refund + ')');
    await Cell.deleteOne({ _id: cell._id });
  }
  return expired.length;
}
async function getOpenLayers() {
  let openL = 1;
  while (openL <= 10000) {
    const edgeCells = 35; // A1~A18 + B1~S1
    const listed = (RESERVED_CELLS[String(openL)] || []).filter(x => !isEdgeReserved(x)).length;
    const sellable = CELLS_PER_LAYER - edgeCells - listed;
    const sold = await Cell.countDocuments({ layer: openL, activated: true });
    if (sold >= sellable) openL++; else break;
  }
  return openL;
}

// 게임별 시간당 최대 SAU 한도 (부정조작 방지 — 서버가 검증)
const MAX_SAU_PER_SEC = {
  mine: 8,       // 채굴: 초당 최대 8 SAU
  solar: 6,      // 태양풍: 초당 최대 6 SAU
  signal: 5,     // 신호해독: 초당 최대 5 SAU (보상이 라운드 단위로 큼)
  nav: 4,        // 항법: 초당 최대 4 SAU
  gravity: 3,    // 슬링샷: 초당 최대 3 SAU
};
const DAILY_CAP = 10000; // 일일 SAU 획득 한도 (인플레 방지)
const MIN_SESSION_SEC = 3; // 최소 세션 시간 (쪼개기 신고 방지) — 복구
// === 셀 분양 정책 ===
const CELL_PRICE_SAU = 50000;      // 50 mAU
const CELL_ACTIVATION_DAYS = 30;   // 활성화 기한
const CELL_REFUND_RATE = 0.5;      // 미활성 회수 환급률
const CELLS_PER_LAYER = 324;
const RESERVED_CELLS = {"1": ["A1", "A18", "B4", "C15", "C3", "D16", "D3", "E8", "F16", "F6", "G6", "G7", "H1", "H11", "J9", "K5", "L12", "M13", "N14", "N3", "N6", "P15", "P8", "Q2", "S1", "S18"], "2": ["A1", "C3", "F6", "J9", "L12", "M13", "P8", "S18"], "3": ["A1", "F6", "S18"]};

function todayKey(){
  const d = new Date();
  return d.getFullYear()+'-'+(d.getMonth()+1)+'-'+d.getDate();
}

async function getOrCreateSauUser(user_id){
  let u = await User.findOne({ user_id }).lean();
  if(!u) return null;
  const curTotal = (u.sau && typeof u.sau.total === 'number') ? u.sau.total : 0;
  const curDailyOk = u.sau && u.sau.daily && u.sau.daily.date === todayKey();
  const curDailyEarned = curDailyOk ? (u.sau.daily.earned || 0) : 0;
  const needsFix = !u.sau || typeof u.sau.total !== 'number' || !curDailyOk;
  if(needsFix){
    const updated = await User.findOneAndUpdate(
      { user_id },
      { $set: { 'sau.total': curTotal, 'sau.daily': { date: todayKey(), earned: curDailyEarned } } },
      { new: true }
    ).lean();
    return updated;
  }
  return u;
}

async function applySauGrant(user_id, amount){
  const updated = await User.findOneAndUpdate(
    { user_id },
    { $inc: { 'sau.total': amount, 'sau.daily.earned': amount } },
    { new: true }
  ).lean();
  return updated;
}

http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }

  // GET /sau/health
  if (req.method === 'GET' && req.url === '/sau/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ ok: true, service: 'sau-server', port: 8100 }));
    return;
  }

  // GET /sau/balance/:user_id — 잔액 조회
  if (req.method === 'GET' && req.url.startsWith('/sau/balance/')) {
    const user_id = decodeURIComponent(req.url.split('/sau/balance/')[1]);
    try {
      const u = await getOrCreateSauUser(user_id);
      if (!u) { res.writeHead(404); res.end(JSON.stringify({ ok:false, reason:'user not found' })); return; }
      res.writeHead(200);
      res.end(JSON.stringify({ ok:true, user_id, total: u.sau.total, daily_earned: u.sau.daily.earned }));
    } catch(e) {
      res.writeHead(500); res.end(JSON.stringify({ ok:false, error: e.message }));
    }
    return;
  }

  // POST /sau/session — 게임 세션 종료 시 SAU 적립 요청 (서버 검증 포함)
  if (req.method === 'POST' && req.url === '/sau/session') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { user_id, game, session_sau, session_seconds, planet_id } = JSON.parse(body);
        if (!user_id || !game || typeof session_sau !== 'number' || !session_seconds) {
          res.writeHead(400); res.end(JSON.stringify({ ok:false, reason:'invalid params' })); return;
        }
        const maxRate = MAX_SAU_PER_SEC[game];
        if (!maxRate) {
          res.writeHead(400); res.end(JSON.stringify({ ok:false, reason:'unknown game type: '+game })); return;
        }

        const u = await getOrCreateSauUser(user_id);
        if (!u) { res.writeHead(404); res.end(JSON.stringify({ ok:false, reason:'user not found' })); return; }

        if (session_seconds < MIN_SESSION_SEC) {
          console.log('[SAU-GUARD] '+user_id+' ['+game+'] 세션 '+session_seconds+'s < '+MIN_SESSION_SEC+'s — 거부');
          res.writeHead(200); res.end(JSON.stringify({ ok:true, requested: session_sau, granted: 0, reason:'session_too_short' })); return;
        }
        // 서버측 검증 — 클라이언트가 보낸 SAU가 물리적으로 가능한 범위인지 확인
        const maxPossible = maxRate * session_seconds;
        const grantedSAU = Math.min(session_sau, maxPossible);
        const wasCapped = grantedSAU < session_sau;

        // 일일 한도 체크
        const remaining = Math.max(0, DAILY_CAP - u.sau.daily.earned);
        const finalSAU = Math.min(grantedSAU, remaining);
        const dailyCapped = finalSAU < grantedSAU;

        const updated = await applySauGrant(user_id, finalSAU);

        console.log('[SAU-SERVER] '+user_id+' ['+game+'] 요청:'+session_sau.toFixed(1)+' 승인:'+finalSAU.toFixed(1)+(wasCapped?' (속도제한)':'')+(dailyCapped?' (일일한도)':''));

        res.writeHead(200);
        res.end(JSON.stringify({
          ok: true,
          requested: session_sau,
          granted: finalSAU,
          rate_capped: wasCapped,
          daily_capped: dailyCapped,
          total: updated.sau.total,
          daily_earned: updated.sau.daily.earned,
          daily_remaining: Math.max(0, DAILY_CAP - updated.sau.daily.earned)
        }));
      } catch(e) {
        console.error('[SAU-SERVER] POST /sau/session 오류:', e.message);
        res.writeHead(500); res.end(JSON.stringify({ ok:false, error: e.message }));
      }
    });
    return;
  }

  // GET /sau/cell-page/L{n}/{cell} — 셀 소유자 페이지 (템플릿 렌더)
  if (req.method === 'GET' && req.url.startsWith('/sau/cell-page/')) {
    try {
      const raw = decodeURIComponent(req.url.split('/sau/cell-page/')[1] || '');
      const pm = raw.match(/^L(\d+)\/([A-S](?:1[0-8]|[1-9]))$/);
      const esc = s => String(s || '').replace(/[<>&"']/g, m => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;'}[m]));
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      if (!pm) { res.writeHead(400); res.end('<h1>잘못된 셀 주소</h1>'); return; }
      const cell_id = 'L' + pm[1] + '/' + pm[2];
      const doc = await Cell.findOne({ cell_id }).lean();
      if (!doc || !doc.activated) {
        res.writeHead(200);
        res.end('<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + esc(cell_id) + '</title></head><body style="background:#0a0e1a;color:#8899aa;font-family:monospace;display:flex;align-items:center;justify-content:center;height:100vh;margin:0"><div style="text-align:center"><div style="font-size:40px">🏗️</div><h2>' + esc(cell_id) + '</h2><p>' + (doc ? '입주 준비 중입니다' : '미분양 셀입니다') + '</p><a href="/dot.html" style="color:#F5A623">← Dot Metaverse</a></div></body></html>');
        return;
      }
      const col = /^#[0-9a-fA-F]{6}$/.test(doc.color || '') ? doc.color : '#F5A623';
      res.writeHead(200);
      res.end('<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + esc(doc.name) + ' — ' + esc(cell_id) + '</title></head>' +
        '<body style="background:#0a0e1a;color:#dde;font-family:monospace;margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center">' +
        '<div style="max-width:560px;width:90%;border:2px solid ' + col + ';border-radius:16px;padding:32px;background:rgba(255,255,255,0.03);box-shadow:0 0 40px ' + col + '33">' +
        '<div style="font-size:56px;text-align:center">' + esc(doc.icon || '🏠') + '</div>' +
        '<h1 style="text-align:center;color:' + col + ';margin:12px 0 4px">' + esc(doc.name) + '</h1>' +
        '<div style="text-align:center;color:#8899aa;font-size:13px">' + esc(cell_id) + ' · 소유자: ' + esc(doc.owner) + '</div>' +
        '<hr style="border:none;border-top:1px solid ' + col + '44;margin:20px 0">' +
        '<p style="line-height:1.7;white-space:pre-wrap">' + esc(doc.intro) + '</p>' +
        '<div style="text-align:center;margin-top:24px"><a href="/dot.html" style="color:' + col + ';text-decoration:none">← Dot Metaverse</a></div>' +
        '</div></body></html>');
    } catch(e) { res.writeHead(500); res.end('<h1>오류</h1>'); }
    return;
  }
  // GET /sau/cells/:layer — 소유 현황 (조회 시 만료 스윕)
  if (req.method === 'GET' && req.url.startsWith('/sau/cells/')) {
    try {
      const layer = parseInt(req.url.split('/sau/cells/')[1], 10);
      if (!layer || layer < 1) { res.writeHead(400); res.end(JSON.stringify({ ok:false, reason:'invalid layer' })); return; }
      await sweepExpiredCells();
      const openLayers = await getOpenLayers();
      const list = await Cell.find({ layer }).lean();
      const cells = list.map(x => ({ cell_id: x.cell_id, owner: x.owner, activated: !!x.activated,
        icon: x.icon || '', color: x.color || '', name: x.name || '', intro: x.intro || '',
        deadline: x.activated ? null : x.purchased_at + CELL_ACTIVATION_DAYS * 86400000 }));
      res.writeHead(200);
      res.end(JSON.stringify({ ok:true, layer, open_layers: openLayers, price_sau: CELL_PRICE_SAU,
        reserved: (function(){
          const edge = [];
          for (let i = 1; i <= 18; i++) edge.push('A' + i);
          'BCDEFGHJKLMNOPQRS'.split('').forEach(col => edge.push(col + '1'));
          return Array.from(new Set(edge.concat(RESERVED_CELLS[String(layer)] || [])));
        })(), cells }));
    } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok:false, error:e.message })); }
    return;
  }
  // POST /sau/cell/buy — 분양
  if (req.method === 'POST' && req.url === '/sau/cell/buy') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { user_id, layer, cell } = JSON.parse(body);
        const L = parseInt(layer, 10);
        if (!user_id || !L || !/^[A-S](1[0-8]|[1-9])$/.test(cell || '')) {
          res.writeHead(400); res.end(JSON.stringify({ ok:false, reason:'invalid params' })); return;
        }
        if (isReserved(L, cell)) { res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'reserved' })); return; }
        const openLayers = await getOpenLayers();
        if (L > openLayers) { res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'layer_not_open', open_layers: openLayers })); return; }
        await sweepExpiredCells();
        const cell_id = 'L' + L + '/' + cell;
        if (await Cell.findOne({ cell_id })) { res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'already_owned' })); return; }
        const u = await User.findOne({ user_id }).lean();
        if (!u || !u.sau || (u.sau.total || 0) < CELL_PRICE_SAU) {
          res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'insufficient_balance', required: CELL_PRICE_SAU, balance: u && u.sau ? u.sau.total : 0 })); return;
        }
        await User.updateOne({ user_id }, { $inc: { 'sau.total': -CELL_PRICE_SAU } });
        await Cell.create({ cell_id, layer: L, cell, owner: user_id, paid_sau: CELL_PRICE_SAU, purchased_at: Date.now(), activated: false });
        console.log('[CELL] 분양: ' + cell_id + ' → ' + user_id);
        res.writeHead(200);
        res.end(JSON.stringify({ ok:true, cell_id, paid: CELL_PRICE_SAU, activation_deadline: Date.now() + CELL_ACTIVATION_DAYS * 86400000 }));
      } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok:false, error:e.message })); }
    });
    return;
  }
  // POST /sau/cell/customize — 꾸미기 = 활성화
  if (req.method === 'POST' && req.url === '/sau/cell/customize') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { user_id, cell_id, icon, color, name, intro } = JSON.parse(body);
        const doc = await Cell.findOne({ cell_id });
        if (!doc) { res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'not_found' })); return; }
        if (doc.owner !== user_id) { res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'not_owner' })); return; }
        const upd = { icon: sanitizeText(icon, 8),
          color: /^#[0-9a-fA-F]{6}$/.test(color || '') ? color : '',
          name: sanitizeText(name, 30), intro: sanitizeText(intro, 200) };
        if (!upd.name || !upd.intro) { res.writeHead(200); res.end(JSON.stringify({ ok:false, reason:'name_and_intro_required' })); return; }
        upd.activated = true; upd.activated_at = Date.now();
        await Cell.updateOne({ cell_id }, { $set: upd });
        console.log('[CELL] 활성화: ' + cell_id + ' (' + upd.name + ')');
        res.writeHead(200); res.end(JSON.stringify({ ok:true, cell_id, activated: true }));
      } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok:false, error:e.message })); }
    });
    return;
  }
  // GET /sau/leaderboard — 전체 SAU 랭킹 (상위 20명)
  if (req.method === 'GET' && req.url === '/sau/leaderboard') {
    try {
      const top = await User.aggregate([
        { $match: { 'sau.total': { $gt: 0 } } },
        { $project: { _id:0, user_id:1, total: '$sau.total' } },
        { $sort: { total: -1 } },
        { $limit: 20 }
      ]);
      res.writeHead(200);
      res.end(JSON.stringify({ ok:true, items: top }));
    } catch(e) {
      res.writeHead(500); res.end(JSON.stringify({ ok:false, error: e.message }));
    }
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ ok:false, reason:'not found' }));

}).listen(8100, () => console.log('[SAU-SERVER] 포트 8100 시작'));
