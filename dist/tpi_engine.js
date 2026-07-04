'use strict';
const W1 = 0.40, W2 = 0.35, W3 = 0.25;
const RECENT_N = 50;

function getTier(tpi) {
  if (tpi >= 800) return 'platinum';
  if (tpi >= 600) return 'gold';
  if (tpi >= 400) return 'silver';
  return 'bronze';
}

function computeOneTPI(userData, isWinner, opponentData, moveCount) {
  const go     = userData.go || {};
  const oppGo  = opponentData.go || {};

  // S1: 승률 점수
  const recentGames = (go.recent_games || []).slice(-RECENT_N);
  const recentWins  = recentGames.filter(g => g === 1).length;
  const recentTotal = recentGames.length;
  const winRate = recentTotal >= 5 ? (recentWins / recentTotal) * 100 : 50;
  const S1 = Math.min(winRate * 10, 1000);

  // S2: 상대 기력 보정
  const myTPI  = go.tpi    || 0;
  const oppTPI = oppGo.tpi || 0;
  const myLv   = go.level  || 1;
  const oppLv  = oppGo.level || 1;
  let oppFactor = oppTPI > 0
    ? Math.min(oppTPI / Math.max(myTPI, 100), 1.5)
    : Math.min(oppLv  / Math.max(myLv, 1), 1.5);
  oppFactor = Math.max(0.3, oppFactor);
  const S2 = Math.min(isWinner ? oppFactor * 600 : oppFactor * 200, 1000);

  // S3: 수 정확도
  const baseAcc = Math.min((moveCount || 50) / 200, 1.0);
  const S3 = Math.min(baseAcc * 800 + (isWinner ? 100 : 0), 1000);

  const rawTPI  = Math.round(W1 * S1 + W2 * S2 + W3 * S3);
  const prevTPI = go.tpi || 0;
  const newTPI  = prevTPI === 0
    ? rawTPI
    : Math.round(prevTPI * 0.7 + rawTPI * 0.3);

  return Math.min(Math.max(newTPI, 0), 1000);
}

async function updateTPI(db, winnerId, loserId, moveCount) {
  try {
    const winner = await db.findOne({ user_id: winnerId }).lean();
    const loser  = await db.findOne({ user_id: loserId  }).lean();
    if (!winner || !loser) {
      console.log('[TPI] 유저 없음:', winnerId, loserId);
      return null;
    }

    const winnerNewTPI = computeOneTPI(winner, true,  loser,  moveCount);
    const loserNewTPI  = computeOneTPI(loser,  false, winner, moveCount);
    const winnerTier   = getTier(winnerNewTPI);
    const loserTier    = getTier(loserNewTPI);
    const now          = new Date();

    const wrWin  = ((winner.go || {}).recent_games || []).slice(-49).concat([1]);
    const wrLose = ((loser.go  || {}).recent_games || []).slice(-49).concat([0]);

    await db.updateOne(
      { user_id: winnerId },
      {
        $set:  { 'go.tpi': winnerNewTPI, 'go.tpi_tier': winnerTier, 'go.recent_games': wrWin },
        $push: { 'go.tpi_history': { date: now, value: winnerNewTPI } }
      }
    );
    await db.updateOne(
      { user_id: loserId },
      {
        $set:  { 'go.tpi': loserNewTPI, 'go.tpi_tier': loserTier, 'go.recent_games': wrLose },
        $push: { 'go.tpi_history': { date: now, value: loserNewTPI } }
      }
    );

    console.log('[TPI]', winnerId, ':', (winner.go||{}).tpi||0, '→', winnerNewTPI, '('+winnerTier+')');
    console.log('[TPI]', loserId,  ':', (loser.go ||{}).tpi||0, '→', loserNewTPI,  '('+loserTier+')');

    return { winnerId, loserId, winnerNewTPI, loserNewTPI, winnerTier, loserTier };
  } catch(e) {
    console.error('[TPI] 오류:', e.message);
    return null;
  }
}

module.exports = { updateTPI, getTier, computeOneTPI };

// ═══════════════════════════════════════
// AI 탐지 엔진 v1.0
// ═══════════════════════════════════════

async function detectAI(db, userId, moveTimeData, newTPI, prevTPI) {
  try {
    const user = await db.findOne({ user_id: userId }).lean();
    if (!user) return { suspicious: false };

    const go = user.go || {};
    const flags = [];

    // 1. TPI 급등 감지 (한 대국에서 +150 이상)
    const tpiDelta = newTPI - (prevTPI || 0);
    if (tpiDelta > 150) {
      flags.push({ type: 'TPI_SPIKE', value: tpiDelta, threshold: 150 });
    }

    // 2. 착수 시간 패턴 (평균 착수 시간이 너무 일정)
    if (moveTimeData && moveTimeData.length >= 10) {
      const avg = moveTimeData.reduce((a,b) => a+b, 0) / moveTimeData.length;
      const variance = moveTimeData.reduce((s,t) => s + Math.pow(t-avg,2), 0) / moveTimeData.length;
      const stdDev = Math.sqrt(variance);
      // 표준편차가 3초 미만 = 너무 일정 = AI 의심
      if (stdDev < 3 && avg < 20) {
        flags.push({ type: 'MOVE_TIME_UNIFORM', stdDev: stdDev.toFixed(2), avg: avg.toFixed(1) });
      }
    }

    // 3. 승률 급등 (최근 10국 90% 이상)
    const recent = go.recent_games || [];
    if (recent.length >= 10) {
      const last10 = recent.slice(-10);
      const wr = last10.filter(r => r === 1).length / 10;
      if (wr >= 0.9) {
        flags.push({ type: 'WIN_RATE_SPIKE', rate: Math.round(wr*100) });
      }
    }

    const suspicious = flags.length >= 1;

    if (suspicious) {
      // 경고 카운트 증가
      const warnCount = (go.ai_warn_count || 0) + 1;
      const frozen    = warnCount >= 3;

      await db.updateOne({ user_id: userId }, {
        $set: {
          'go.ai_warn_count': warnCount,
          'go.ai_flags': flags,
          'go.tpi_frozen': frozen,
          'go.ai_last_detected': new Date()
        }
      });

      console.log('[AI-DETECT] ' + userId + ' 경고' + warnCount + '회 flags:', JSON.stringify(flags));
      if (frozen) console.log('[AI-DETECT] ' + userId + ' TPI 동결!');

      return { suspicious: true, flags, warnCount, frozen };
    }

    return { suspicious: false };
  } catch(e) {
    console.error('[AI-DETECT] 오류:', e.message);
    return { suspicious: false };
  }
}

module.exports.detectAI = detectAI;
