// ═══════════════════════════════════════════
// TPI AI 자동 모니터 — 24시간 백그라운드 실행
// ═══════════════════════════════════════════
'use strict';
const mongoose = require('mongoose');
const { detectAI } = require('./tpi_engine');

const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/tob';
mongoose.connect(mongoUrl, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('[MONITOR] MongoDB 연결 완료'))
  .catch(e => console.error('[MONITOR] MongoDB 오류:', e.message));

const userSchema = new mongoose.Schema({}, { strict: false, collection: 'users' });
const User = mongoose.model('MonitorUser', userSchema);

// 검사 주기 설정
const CHECK_INTERVAL  = 5  * 60 * 1000; // 5분마다 전체 검사
const DEEP_INTERVAL   = 30 * 60 * 1000; // 30분마다 심층 검사
const REPORT_INTERVAL = 60 * 60 * 1000; // 1시간마다 리포트

var checkCount = 0;

// ── 1. 빠른 검사 (5분) — TPI 급등 + 승률 이상 ──
async function quickScan() {
  try {
    checkCount++;
    console.log('[MONITOR] 빠른 검사 #' + checkCount + ' 시작...');

    // 최근 1시간 내 TPI 변화가 있는 유저만 검사
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const activeUsers = await User.find({
      'go.tpi_history': { $elemMatch: { date: { $gte: oneHourAgo } } }
    }).lean();

    console.log('[MONITOR] 활성 유저 ' + activeUsers.length + '명 검사 중...');

    let suspectCount = 0;
    for (const user of activeUsers) {
      const go = user.go || {};
      const hist = go.tpi_history || [];
      if (hist.length < 2) continue;

      // 최근 2개 TPI 변화 확인
      const last  = hist[hist.length - 1].value;
      const prev  = hist[hist.length - 2].value;
      const delta = last - prev;

      // TPI 급등 즉시 탐지
      if (delta > 150) {
        const result = await detectAI(User, user.user_id, [], last, prev);
        if (result.suspicious) {
          suspectCount++;
          console.log('[MONITOR] 급등 탐지! ' + user.user_id + ' +' + delta + ' TPI');
          await logAlert(user.user_id, 'TPI_SPIKE', { delta, last, prev });
          sendTelegram(
            '🚨 [Tobmate AI 탐지]\n' +
            '━━━━━━━━━━━━━━\n' +
            '유저: ' + user.user_id + '\n' +
            '탐지: TPI 급등 +' + delta + '\n' +
            '현재 TPI: ' + last + '\n' +
            '이전 TPI: ' + prev + '\n' +
            '경고: ' + ((user.go||{}).ai_warn_count||0) + '회\n' +
            '시간: ' + new Date().toLocaleString('ko-KR') + '\n' +
            '━━━━━━━━━━━━━━\n' +
            '관리자: tobmate.com/tpi-admin'
          );
        }
      }
    }

    console.log('[MONITOR] 빠른 검사 완료 — 의심 ' + suspectCount + '명');
  } catch(e) {
    console.error('[MONITOR] 빠른 검사 오류:', e.message);
  }
}

// ── 2. 심층 검사 (30분) — 패턴 분석 ──
async function deepScan() {
  try {
    console.log('[MONITOR] 심층 검사 시작...');

    // TPI가 있는 모든 유저 검사
    const users = await User.find({ 'go.total': { $gte: 10 } }).lean();
    let suspectCount = 0;

    for (const user of users) {
      const go = user.go || {};
      if (go.tpi_frozen) continue; // 이미 동결된 유저 스킵

      // 승률 패턴 심층 분석
      const recent = go.recent_games || [];
      if (recent.length >= 10) {
        const last10 = recent.slice(-10);
        const wr = last10.filter(r => r === 1).length / 10;

        // 90% 이상 + TPI 800 이하 = 의심 (고수가 아닌데 너무 이김)
        if (wr >= 0.9 && (go.tpi || 0) < 800) {
          const result = await detectAI(User, user.user_id, [], go.tpi || 0, 0);
          if (result.suspicious) {
            suspectCount++;
            await logAlert(user.user_id, 'WIN_RATE_PATTERN', { wr: Math.round(wr*100), tpi: go.tpi });
            sendTelegram(
              '⚠️ [Tobmate 승률 이상]\n' +
              '━━━━━━━━━━━━━━\n' +
              '유저: ' + user.user_id + '\n' +
              '승률: ' + Math.round(wr*100) + '% (최근 10국)\n' +
              '현재 TPI: ' + (go.tpi||0) + '\n' +
              '경고: ' + (result.warnCount||0) + '회\n' +
              (result.frozen ? '🔒 TPI 자동 동결됨!\n' : '') +
              '시간: ' + new Date().toLocaleString('ko-KR') + '\n' +
              '━━━━━━━━━━━━━━\n' +
              '관리자: tobmate.com/tpi-admin'
            );
          }
        }
      }
    }

    console.log('[MONITOR] 심층 검사 완료 — 의심 ' + suspectCount + '명');
  } catch(e) {
    console.error('[MONITOR] 심층 검사 오류:', e.message);
  }
}

// ── 3. 시간별 리포트 ──
async function hourlyReport() {
  try {
    const suspects = await User.find({ 'go.ai_warn_count': { $gt: 0 } }).lean();
    const frozen   = suspects.filter(u => (u.go||{}).tpi_frozen);

    console.log('');
    console.log('══════════════════════════════════');
    console.log('[MONITOR] 시간별 리포트');
    console.log('  의심 유저: ' + suspects.length + '명');
    console.log('  동결 유저: ' + frozen.length + '명');
    suspects.forEach(u => {
      const go = u.go || {};
      console.log('  - ' + u.user_id + ' TPI:' + (go.tpi||0) + ' 경고:' + (go.ai_warn_count||0) + '회' + (go.tpi_frozen?' [동결]':''));
    });
    console.log('══════════════════════════════════');
    console.log('');
    // 텔레그램 리포트
    sendTelegram(
      '📊 [Tobmate 시간 리포트]\n' +
      '━━━━━━━━━━━━━━\n' +
      '의심 유저: ' + suspects.length + '명\n' +
      '동결 유저: ' + frozen.length + '명\n' +
      '━━━━━━━━━━━━━━\n' +
      (suspects.length > 0 ? suspects.map(u => '⚠️ ' + u.user_id + ' TPI:' + ((u.go||{}).tpi||0) + ' 경고:' + ((u.go||{}).ai_warn_count||0) + '회' + ((u.go||{}).tpi_frozen?' 🔒':'') ).join('\n') + '\n' : '✅ 의심 유저 없음\n') +
      '🕐 ' + new Date().toLocaleString('ko-KR')
    );
  } catch(e) {
    console.error('[MONITOR] 리포트 오류:', e.message);
  }
}

// ── 텔레그램 알림 ──
const https = require('https');
const TELEGRAM_TOKEN   = '8833883942:AAF4G-H7yQieGT4EAkXFPULPyNG3CHTC9A8';
const TELEGRAM_CHAT_ID = '8662817806';

function sendTelegram(msg) {
  try {
    const text = encodeURIComponent(msg);
    const url  = 'https://api.telegram.org/bot' + TELEGRAM_TOKEN + '/sendMessage?chat_id=' + TELEGRAM_CHAT_ID + '&text=' + text + '&parse_mode=HTML';
    https.get(url, (res) => {
      console.log('[TELEGRAM] 전송완료 status:', res.statusCode);
    }).on('error', (e) => {
      console.error('[TELEGRAM] 전송오류:', e.message);
    });
  } catch(e) {
    console.error('[TELEGRAM] 오류:', e.message);
  }
}

// ── 알림 로그 저장 ──
async function logAlert(userId, type, data) {
  try {
    await User.updateOne({ user_id: userId }, {
      $push: { 'go.monitor_log': { date: new Date(), type, data } }
    });
  } catch(e) {}
}

// ── 스케줄러 시작 ──
console.log('[MONITOR] AI 자동 모니터 시작');
console.log('[MONITOR] 빠른검사: 5분 | 심층검사: 30분 | 리포트: 1시간');

// 시작 즉시 한번 실행
setTimeout(quickScan, 5000);
setTimeout(deepScan,  10000);

// 주기 실행
setInterval(quickScan,    CHECK_INTERVAL);
setInterval(deepScan,     DEEP_INTERVAL);
setInterval(hourlyReport, REPORT_INTERVAL);
