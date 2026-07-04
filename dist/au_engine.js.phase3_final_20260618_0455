'use strict';
// ═══════════════════════════════════════════════════════
// AU Engine v2.0 — Tobmate 국제기준 파리뮤추얼 구조
// Takeout 15% | 배분 85% | 글로벌 스탠다드 준수
// ═══════════════════════════════════════════════════════

// ── TPI 등급별 플레이어 보상 배율 ──
function getTierMultiplier(tpi) {
  if (tpi >= 800) return 3.0; // 프로급
  if (tpi >= 600) return 2.0; // 고급
  if (tpi >= 400) return 1.5; // 중급
  return 1.0;                  // 초급
}

// ── 연승 보너스 ──
function getStreakBonus(streak) {
  if (streak >= 5) return 0.5;
  if (streak >= 3) return 0.3;
  if (streak >= 2) return 0.1;
  return 0;
}

// ══════════════════════════════════════════
// 핵심: 파리뮤추얼 풀 정산
// 스폰서 A+B 예치금 기준 배분
// ══════════════════════════════════════════
async function settlePariMutuel(db, roomBetting, winnerId, loserId) {
  try {
    if (!roomBetting || roomBetting.length === 0) return null;

    // 총 풀 계산 (mgAU 단위)
    let totalPool = 0;
    let winnerPool = 0;  // 승자 편에 베팅된 금액
    let loserPool  = 0;  // 패자 편에 베팅된 금액

    roomBetting.forEach(bet => {
      totalPool += bet.bet_coin;
      if (bet.bet_to_player === 0) winnerPool += bet.bet_coin; // 승자 스폰서
      else                          loserPool  += bet.bet_coin; // 패자 스폰서
    });

    if (totalPool === 0) return null;

    // ── Takeout 15% 차감 ──
    const takeout        = Math.round(totalPool * 0.15);
    const tobmateOps     = Math.round(totalPool * 0.08); // 운영비 8%
    const playerFund     = Math.round(totalPool * 0.05); // 플레이어 보상기금 5%
    const spectatorFund  = Math.round(totalPool * 0.02); // 관전자 보상 2%

    // 플레이어 보상기금 세부 분배
    const winnerPlayerReward  = Math.round(playerFund * 0.60); // 3% (승리 플레이어)
    const loserPlayerReward   = Math.round(playerFund * 0.20); // 1% (참가 플레이어)
    const tournamentFund      = Math.round(playerFund * 0.20); // 1% (토너먼트 적립)

    // ── 배분 풀 85% ──
    const distributionPool = totalPool - takeout;
    const winnerSponsorPool = Math.round(distributionPool * (80/85)); // 80%
    const loserConsolation  = Math.round(distributionPool * (5/85));  // 5% 위로금

    // ── 스폰서별 배당 계산 ──
    const sponsorResults = [];
    roomBetting.forEach(bet => {
      const isWinnerSponsor = bet.bet_to_player === 0;
      let payout = 0;
      let returnRate = 0;

      if (isWinnerSponsor && winnerPool > 0) {
        // 승리 스폰서: 비례 배분 (최소 ×1.05 보장 — 호주 Racing Act)
        const proportional = Math.round(winnerSponsorPool * (bet.bet_coin / winnerPool));
        const minGuarantee = Math.round(bet.bet_coin * 1.05); // 최소 5% 수익 보장
        payout = Math.max(proportional, minGuarantee);
        returnRate = ((payout - bet.bet_coin) / bet.bet_coin * 100).toFixed(1);
      } else {
        // 패배 스폰서: 위로금 5% 비례 지급
        payout = loserPool > 0 ? Math.round(loserConsolation * (bet.bet_coin / loserPool)) : 0;
        returnRate = ((payout - bet.bet_coin) / bet.bet_coin * 100).toFixed(1);
      }

      sponsorResults.push({
        user_id:      bet.user_id,
        bet_amount:   bet.bet_coin,
        payout,
        return_rate:  returnRate + '%',
        is_winner:    isWinnerSponsor
      });
    });

    console.log('[AU-POOL] 총풀:', totalPool, 'mgAU | Tobmate:', tobmateOps, '| 플레이어기금:', playerFund);

    return {
      total_pool:           totalPool,
      takeout:              takeout,
      tobmate_ops:          tobmateOps,
      player_fund:          playerFund,
      winner_player_reward: winnerPlayerReward,
      loser_player_reward:  loserPlayerReward,
      tournament_fund:      tournamentFund,
      spectator_fund:       spectatorFund,
      distribution_pool:    distributionPool,
      winner_sponsor_pool:  winnerSponsorPool,
      loser_consolation:    loserConsolation,
      sponsor_results:      sponsorResults
    };
  } catch(e) {
    console.error('[AU-POOL] 오류:', e.message);
    return null;
  }
}

// ══════════════════════════════════════════
// AU 보상 대국 — 플레이어 직접 보상
// 기본 +1 mgAU × TPI배율 × 연승보너스
// ══════════════════════════════════════════
async function grantPlayerAU(db, winnerId, loserId, isAUGame) {
  try {
    if (!isAUGame) return null; // 연습 대국은 AU 지급 안함

    const winner = await db.findOne({ user_id: winnerId }).lean();
    if (!winner) return null;

    const go       = winner.go || {};
    const au       = winner.au || { balance:0, total_earned:0, streak:0, history:[] };
    const tpi      = go.tpi || 0;
    const streak   = (au.streak || 0) + 1;

    // 기본 1 mgAU × TPI배율 + 연승보너스
    const baseMgAU      = 1.0;
    const tierMult      = getTierMultiplier(tpi);
    const streakBonus   = getStreakBonus(streak);
    const totalMgAU     = Math.round((baseMgAU * tierMult + streakBonus) * 100) / 100;

    const now = new Date();

    // 승자 AU 지급
    await db.updateOne({ user_id: winnerId }, {
      $inc: { 'au.balance': totalMgAU, 'au.total_earned': totalMgAU },
      $set: { 'au.streak': streak, 'au.last_game_date': now },
      $push: {
        'au.history': {
          $each: [{
            date:         now,
            type:         'earn',
            amount:       totalMgAU,
            reason:       'AU 보상 대국 승리',
            detail: {
              base:         baseMgAU,
              tier_mult:    tierMult,
              streak_bonus: streakBonus,
              streak:       streak,
              tpi:          tpi,
              opponent:     loserId
            }
          }],
          $slice: -100
        }
      }
    });

    // 패자 — 참가 플레이어 보상 (기금에서 0.1 mgAU)
    const loserReward = 0.1;
    await db.updateOne({ user_id: loserId }, {
      $inc: { 'au.balance': loserReward, 'au.total_earned': loserReward },
      $set: { 'au.streak': 0, 'au.last_game_date': now },
      $push: {
        'au.history': {
          $each: [{
            date:   now,
            type:   'earn',
            amount: loserReward,
            reason: '참가 보상',
            detail: { opponent: winnerId }
          }],
          $slice: -100
        }
      }
    });

    console.log('[AU] 승리:' + winnerId + ' +' + totalMgAU + ' mgAU (TPI:'+tpi+' 연승:'+streak+'회)');
    console.log('[AU] 참가:' + loserId  + ' +' + loserReward + ' mgAU');

    return {
      winner_id:    winnerId,
      loser_id:     loserId,
      winner_au:    totalMgAU,
      loser_au:     loserReward,
      new_balance:  Math.round(((au.balance||0) + totalMgAU) * 100) / 100,
      streak,
      tier_mult:    tierMult,
      streak_bonus: streakBonus
    };
  } catch(e) {
    console.error('[AU] 플레이어 보상 오류:', e.message);
    return null;
  }
}

// ── AU 잔액 조회 ──
async function getAUBalance(db, userId) {
  try {
    const user = await db.findOne({ user_id: userId }).lean();
    if (!user) return null;
    const au = user.au || { balance:0, total_earned:0, streak:0, history:[] };
    return {
      user_id:      userId,
      balance:      Math.round((au.balance||0) * 100) / 100,
      total_earned: Math.round((au.total_earned||0) * 100) / 100,
      total_spent:  Math.round((au.total_spent||0) * 100) / 100,
      streak:       au.streak || 0,
      history:      (au.history||[]).slice(-20),
      tpi:          (user.go||{}).tpi || 0,
      tpi_tier:     (user.go||{}).tpi_tier || 'bronze'
    };
  } catch(e) {
    console.error('[AU] 잔액 조회 오류:', e.message);
    return null;
  }
}

module.exports = { settlePariMutuel, grantPlayerAU, getAUBalance, getTierMultiplier };
