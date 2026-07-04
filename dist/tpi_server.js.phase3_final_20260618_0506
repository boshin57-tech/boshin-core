'use strict';
const http = require('http');
const mongoose = require('mongoose');
const { updateTPI, detectAI } = require('./tpi_engine');
const { grantPlayerAU, getAUBalance, settlePariMutuel } = require('./au_engine');

const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/tob';
mongoose.connect(mongoUrl, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('[TPI-SERVER] MongoDB 연결 완료 db:', mongoUrl))
  .catch(e => console.error('[TPI-SERVER] MongoDB 오류:', e.message));

const userSchema = new mongoose.Schema({}, { strict: false, collection: 'users' });
const User = mongoose.model('TpiUser', userSchema);

http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json');

  // POST /tpi — 대국 결과 처리
  if (req.method === 'POST' && req.url === '/tpi') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { winner_id, loser_id, move_count, move_times, is_au_game, room_betting } = JSON.parse(body);
        console.log('[TPI-SERVER] 대국결과:', winner_id, 'vs', loser_id, '수:', move_count);
        const _w = await User.findOne({ user_id: winner_id }).lean();
        const prevWinnerTPI = _w ? (_w.go||{}).tpi||0 : 0;
        const result = await updateTPI(User, winner_id, loser_id, move_count || 50);
        if (result) {
          // AI 탐지 실행
          const aiResult = await detectAI(User, winner_id, move_times||[], result.winnerNewTPI, prevWinnerTPI);
          const aiLoser  = await detectAI(User, loser_id,  move_times||[], result.loserNewTPI,  0);
          const auResult = await grantPlayerAU(User, winner_id, loser_id, is_au_game || false);
          const poolResult = await settlePariMutuel(User, room_betting || [], winner_id, loser_id);
          res.writeHead(200);
          res.end(JSON.stringify({ ok: true, ...result,
            au_result: auResult,
            pool_result: poolResult,
            ai_warning: aiResult.suspicious ? aiResult : null,
            ai_frozen: aiResult.frozen || false
          }));
        } else {
          res.writeHead(200);
          res.end(JSON.stringify({ ok: false, reason: 'user not found' }));
        }
      } catch(e) {
        console.error('[TPI-SERVER] POST 오류:', e.message);
        res.writeHead(500);
        res.end(JSON.stringify({ ok: false, error: e.message }));
      }
    });

  // GET /tpi/user/:id — 유저 TPI 조회
  } else if (req.method === 'GET' && req.url.startsWith('/tpi/user/')) {
    try {
      const userId = decodeURIComponent(req.url.replace('/tpi/user/', ''));
      const user = await User.findOne({ user_id: userId }).lean();
      if (!user) {
        res.writeHead(404);
        res.end(JSON.stringify({ ok: false, reason: 'user not found' }));
        return;
      }
      const go = user.go || {};
      res.writeHead(200);
      res.end(JSON.stringify({
        ok:          true,
        user_id:     userId,
        tpi:         go.tpi         || 0,
        tpi_tier:    go.tpi_tier    || 'bronze',
        tpi_history: (go.tpi_history || []).slice(-10),
        level:       go.level       || 1,
        win:         go.win         || 0,
        lose:        go.lose        || 0,
        total:       go.total       || 0,
        recent_games:(go.recent_games|| []).slice(-20)
      }));
    } catch(e) {
      res.writeHead(500);
      res.end(JSON.stringify({ ok: false, error: e.message }));
    }

  // GET /health
  } else if (req.method === 'GET' && req.url === '/au/goldprice') {
    try {
      const https = require('https');
      // Swissquote 금시세 + 환율 동시 조회
      const getJSON = (url) => new Promise((resolve, reject) => {
        https.get(url, (res) => {
          let d = '';
          res.on('data', c => d += c);
          res.on('end', () => { try { resolve(JSON.parse(d)); } catch(e) { reject(e); } });
        }).on('error', reject);
      });
      const [gold, fx] = await Promise.all([
        getJSON('https://forex-data-feed.swissquote.com/public-quotes/bboquotes/instrument/XAU/USD'),
        getJSON('https://api.exchangerate-api.com/v4/latest/USD')
      ]);
      const usdPerOz = (gold[0].spreadProfilePrices[0].bid + gold[0].spreadProfilePrices[0].ask) / 2;
      const audRate  = fx.rates.AUD || 1.55;
      const audPerOz = Math.round(usdPerOz * audRate);
      res.writeHead(200);
      res.end(JSON.stringify({ ok: true, usd: Math.round(usdPerOz), aud: audPerOz, rate: audRate, ts: new Date() }));
    } catch(e) {
      res.writeHead(200);
      res.end(JSON.stringify({ ok: false, usd: 4300, aud: 6700, rate: 1.55 }));
    }

  } else if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ ok: true, service: 'tpi-server', port: 8097 }));

  } else if (req.method === 'POST' && req.url === '/tpi/admin/reset-all') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { secret } = JSON.parse(body);
        if (secret !== 'tobmate_admin_2026') {
          res.writeHead(403); res.end(JSON.stringify({ ok: false, reason: 'unauthorized' })); return;
        }
        const result = await User.updateMany({}, {
          $set: { 'go.tpi': 0, 'go.tpi_tier': 'bronze', 'go.tpi_history': [], 'go.recent_games': [] }
        });
        console.log('[TPI-ADMIN] 전체 초기화 완료:', result.modifiedCount, '명');
        res.writeHead(200);
        res.end(JSON.stringify({ ok: true, reset_count: result.modifiedCount, message: '전체 TPI 초기화 완료' }));
      } catch(e) {
        res.writeHead(500); res.end(JSON.stringify({ ok: false, error: e.message }));
      }
    });

  } else if (req.method === 'POST' && req.url === '/au/deduct') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { user_id, amount, reason } = JSON.parse(body);
        if (!user_id || !amount || amount <= 0) {
          res.writeHead(400); res.end(JSON.stringify({ ok: false, reason: 'invalid params' })); return;
        }
        const user = await User.findOne({ user_id }).lean();
        if (!user) { res.writeHead(404); res.end(JSON.stringify({ ok: false, reason: 'user not found' })); return; }
        const auBal = (user.au || {}).balance || 0;
        if (auBal < amount) {
          res.writeHead(200); res.end(JSON.stringify({ ok: false, reason: 'insufficient_au', balance: auBal })); return;
        }
        const now = new Date();
        await User.updateOne({ user_id }, {
          $inc: { 'au.balance': -amount, 'au.total_spent': amount },
          $push: {
            'au.history': {
              $each: [{ date: now, type: 'spend', amount, reason: reason || 'AU BET 차감' }],
              $slice: -100
            }
          }
        });
        const newBal = Math.round((auBal - amount) * 100) / 100;
        console.log('[AU-DEDUCT] ' + user_id + ' -' + amount + ' mgAU → 잔액:' + newBal);
        res.writeHead(200);
        res.end(JSON.stringify({ ok: true, user_id, deducted: amount, new_balance: newBal }));
      } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok: false, error: e.message })); }
    });

  } else if (req.method === 'POST' && req.url === '/au/grant') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { user_id, amount, reason } = JSON.parse(body);
        if (!user_id || !amount || amount <= 0) {
          res.writeHead(400); res.end(JSON.stringify({ ok: false, reason: 'invalid params' })); return;
        }
        const now = new Date();
        await User.updateOne({ user_id }, {
          $inc: { 'au.balance': amount, 'au.total_earned': amount },
          $push: {
            'au.history': {
              $each: [{ date: now, type: 'earn', amount, reason: reason || 'AU 지급' }],
              $slice: -100
            }
          }
        });
        console.log('[AU-GRANT] ' + user_id + ' +' + amount + ' mgAU');
        res.writeHead(200);
        res.end(JSON.stringify({ ok: true, user_id, granted: amount }));
      } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok: false, error: e.message })); }
    });

  } else if (req.method === 'GET' && req.url.startsWith('/au/user/')) {
    try {
      const userId = decodeURIComponent(req.url.replace('/au/user/', ''));
      const balance = await getAUBalance(User, userId);
      if (!balance) { res.writeHead(404); res.end(JSON.stringify({ ok: false })); return; }
      res.writeHead(200);
      res.end(JSON.stringify({ ok: true, ...balance }));
    } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok: false, error: e.message })); }

  } else if (req.method === 'GET' && req.url === '/au/ranking') {
    try {
      const users = await User.find(
        { 'au.total_earned': { $gt: 0 } },
        { user_id:1, 'au.balance':1, 'au.total_earned':1, 'au.streak':1, 'go.tpi':1, 'go.tpi_tier':1 }
      ).sort({ 'au.total_earned': -1 }).limit(20).lean();
      res.writeHead(200);
      res.end(JSON.stringify({ ok: true, items: users.map(u => ({
        user_id:      u.user_id,
        balance:      Math.round(((u.au||{}).balance||0)*100)/100,
        total_earned: Math.round(((u.au||{}).total_earned||0)*100)/100,
        streak:       (u.au||{}).streak||0,
        tpi:          (u.go||{}).tpi||0,
        tpi_tier:     (u.go||{}).tpi_tier||'bronze'
      }))}));
    } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok: false, error: e.message })); }

  } else if (req.method === 'GET' && req.url === '/tpi/ranking') {
    try {
      const users = await User.find(
        { 'go.level': { $gt: 0 } },
        { user_id:1, 'go.tpi':1, 'go.tpi_tier':1, 'go.recent_games':1, 'go.total':1, 'go.tpi_frozen':1, 'go.ai_warn_count':1 }
      ).sort({ 'go.tpi': -1 }).limit(20).lean();
      const total = await User.countDocuments({ 'go.tpi': { $gte: 0 } });
      res.writeHead(200);
      res.end(JSON.stringify({ ok: true, total, items: users.map(u => ({
        user_id: u.user_id, tpi: (u.go||{}).tpi||0,
        tpi_tier: (u.go||{}).tpi_tier||'bronze',
        recent_games: (u.go||{}).recent_games||[],
        total: (u.go||{}).total||0,
        tpi_frozen: (u.go||{}).tpi_frozen||false,
        ai_warn_count: (u.go||{}).ai_warn_count||0
      }))}));
    } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok:false, error:e.message })); }

  } else if (req.method === 'GET' && req.url.startsWith('/tpi/admin/ai-suspects')) {
    try {
      const suspects = await User.find({ 'go.ai_warn_count': { $gt: 0 } },
        { user_id:1, 'go.tpi':1, 'go.ai_warn_count':1, 'go.ai_flags':1, 'go.tpi_frozen':1, 'go.ai_last_detected':1 }).lean();
      res.writeHead(200);
      res.end(JSON.stringify({ ok: true, count: suspects.length, suspects: suspects.map(u => ({
        user_id: u.user_id, tpi: (u.go||{}).tpi||0,
        warn_count: (u.go||{}).ai_warn_count||0,
        frozen: (u.go||{}).tpi_frozen||false,
        flags: (u.go||{}).ai_flags||[],
        last_detected: (u.go||{}).ai_last_detected
      }))}));
    } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok:false, error:e.message })); }

  } else if (req.method === 'POST' && req.url === '/tpi/admin/unfreeze') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { secret, user_id } = JSON.parse(body);
        if (secret !== 'tobmate_admin_2026') { res.writeHead(403); res.end(JSON.stringify({ok:false})); return; }
        await User.updateOne({ user_id }, { $set: { 'go.tpi_frozen': false, 'go.ai_warn_count': 0, 'go.ai_flags': [] } });
        console.log('[AI-ADMIN] 동결해제:', user_id);
        res.writeHead(200); res.end(JSON.stringify({ ok: true, message: user_id + ' 동결 해제 완료' }));
      } catch(e) { res.writeHead(500); res.end(JSON.stringify({ ok:false, error:e.message })); }
    });

  } else if (req.method === 'POST' && req.url === '/tpi/admin/reset-user') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { secret, user_id } = JSON.parse(body);
        if (secret !== 'tobmate_admin_2026') {
          res.writeHead(403); res.end(JSON.stringify({ ok: false, reason: 'unauthorized' })); return;
        }
        await User.updateOne({ user_id }, {
          $set: { 'go.tpi': 0, 'go.tpi_tier': 'bronze', 'go.tpi_history': [], 'go.recent_games': [] }
        });
        console.log('[TPI-ADMIN] 개인 초기화:', user_id);
        res.writeHead(200);
        res.end(JSON.stringify({ ok: true, user_id, message: user_id + ' TPI 초기화 완료' }));
      } catch(e) {
        res.writeHead(500); res.end(JSON.stringify({ ok: false, error: e.message }));
      }
    });

  } else {
    res.writeHead(404);
    res.end(JSON.stringify({ ok: false, reason: 'not found' }));
  }

}).listen(8097, () => console.log('[TPI-SERVER] 포트 8097 시작'));

// 관리자 TPI 전체 초기화 API
// POST /tpi/admin/reset-all  { secret: "tobmate_admin_2026" }
// POST /tpi/admin/reset-user { secret: "...", user_id: "AAA" }
