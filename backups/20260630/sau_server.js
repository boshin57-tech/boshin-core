'use strict';
const http = require('http');
const mongoose = require('mongoose');
const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/tob';
mongoose.connect(mongoUrl, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('[SAU-SERVER] MongoDB 연결 완료 db:', mongoUrl))
  .catch(e => console.error('[SAU-SERVER] MongoDB 오류:', e.message));

const userSchema = new mongoose.Schema({}, { strict: false, collection: 'users' });
const User = mongoose.model('SauUser', userSchema);

// 게임별 시간당 최대 SAU 한도 (부정조작 방지 — 서버가 검증)
const MAX_SAU_PER_SEC = {
  mine: 8,       // 채굴: 초당 최대 8 SAU
  solar: 6,      // 태양풍: 초당 최대 6 SAU
  signal: 5,     // 신호해독: 초당 최대 5 SAU (보상이 라운드 단위로 큼)
  nav: 4,        // 항법: 초당 최대 4 SAU
  gravity: 3,    // 슬링샷: 초당 최대 3 SAU
};
const DAILY_CAP = 5000; // 일일 SAU 획득 한도 (인플레 방지)

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
