/* ============================================================
   TOBMATE 은하계 엔진 (galaxy.js)
   - 실전 판정 / 행성 생성 / 성장 / 무작위 이벤트
   - classroom3d, G1, planet 페이지가 공유
   ============================================================ */
(function(){
'use strict';

var KEY_PREFIX = 'tobmate_galaxy_';

function curUser(){
  try { return new URLSearchParams(location.search).get('user') || 'guest'; }
  catch(e){ return 'guest'; }
}
function load(){
  try { var raw = localStorage.getItem(KEY_PREFIX + curUser()); return raw ? JSON.parse(raw) : []; }
  catch(e){ return []; }
}
function save(g){
  try { localStorage.setItem(KEY_PREFIX + curUser(), JSON.stringify(g)); return true; }
  catch(e){ console.warn('[galaxy] 저장 실패', e); return false; }
}

/* ---------- 실전 판정 (AI 선생님은 상주 NPC라 제외) ---------- */
function humanCount(){
  var o = window._others || {};
  return 1 + Object.keys(o).length;
}
function isRanked(){ return humanCount() >= 2; }

function opponentName(){
  var o = window._others || {};
  var ids = Object.keys(o);
  if (!ids.length) return null;
  var av = o[ids[0]];
  return (av && av.userData && av.userData.pname) || '상대';
}

/* ---------- 희귀도 팔레트 ---------- */
var RARITY = {
  common:   { name:'일반',   colors:['#7fd4ff','#4a9eff'] },
  rare:     { name:'희귀',   colors:['#c8a2ff','#ff9dd4'] },
  legendary:{ name:'전설',   colors:['#ff6b9d','#ffd76b','#7fffd4'] },
  treasure: { name:'보물',   colors:['#ffcc44','#ffffff'] }
};

/* ---------- 무작위 이벤트: 4개 인자 모두 반영 ---------- */
function rollEvents(ctx){
  var winMul   = ctx.won ? 2.0 : 1.0;
  var loyalMul = 1 + Math.min(ctx.totalGames, 200) * 0.01;
  var bigMul   = 1 + Math.min(Math.abs(ctx.territoryDiff), 150) / 100;

  // 초반 부스터 — 첫인상이 전부다
  var boost = 1.0;
  if (ctx.totalGames < 5)  boost = 4.0;
  else if (ctx.totalGames < 20) boost = 2.0;

  function hit(base){ return Math.random() < base * winMul * loyalMul * bigMul * boost; }

  var out = { moons:[], particles:[], rings:[], treasure:false };

  // 첫 대국 = 첫 나비 확정 (첫 상대는 영원히 내 정원에)
  if (ctx.totalGames === 0){
    out.moons.push({
      name: ctx.opponent || '첫 상대',
      color: '#ff9dd4',
      orbit: 1.8, speed: 0.75,
      first: true
    });
    if (Math.random() < 0.5) out.particles.push({
      type:'aurora', palette: RARITY.rare.colors });
    return out;
  }

  if (hit(0.05)) out.moons.push({
    name: ctx.opponent || '알 수 없는 여행자',
    color: RARITY.common.colors[Math.floor(Math.random()*2)],
    orbit: 1.6 + Math.random()*0.8,
    speed: 0.4 + Math.random()*0.9
  });
  if (hit(0.03)) out.particles.push({
    type: Math.random() < 0.5 ? 'aurora' : 'dust',
    palette: (Math.random() < 0.3 ? RARITY.legendary : RARITY.rare).colors
  });
  if (hit(0.01)) out.rings.push({
    tilt: Math.random()*Math.PI,
    width: 0.2 + Math.random()*0.35,
    palette: RARITY.rare.colors
  });
  if (hit(0.003)) out.treasure = true;

  return out;
}

/* ---------- 성장: 매 대국마다 은하 전체가 자람 ---------- */
function applyGrowth(galaxy){
  var games = galaxy.length;
  var wins  = galaxy.filter(function(p){ return p.iWon; }).length;
  galaxy.forEach(function(p){
    p.growth = (games * 1) + (wins * 2);
    p.size   = (p.baseSize || 0) + p.growth;
  });
  return galaxy;
}

/* ---------- 행성 탄생 ---------- */
function birthPlanet(opts){
  // opts: { myScore, oppScore, iAmBlack, borderStones, sgf, moves, komi, handicap }
  if (!isRanked()){
    return { ok:false, reason:'practice', humans: humanCount() };
  }

  var galaxy = load();
  var me  = (window.myName) || curUser();
  var opp = opponentName() || '상대';
  var iWon = opts.myScore > opts.oppScore;
  var diff = Math.abs(opts.myScore - opts.oppScore);

  var ev = rollEvents({
    won: iWon,
    totalGames: galaxy.length,
    territoryDiff: diff,
    opponent: opp
  });

  // 경계선을 행성 표면 지형으로 (판마다 유일한 무늬)
  var signature = (opts.borderStones || []).map(function(s){
    return { c:s.c, r:s.r, b:s.b };
  });

  var planet = {
    id: 'P' + Date.now().toString(36) + Math.random().toString(36).slice(2,6),
    date: new Date().toISOString(),
    black: { user: opts.iAmBlack ? me  : opp, score: opts.iAmBlack ? opts.myScore : opts.oppScore },
    white: { user: opts.iAmBlack ? opp : me,  score: opts.iAmBlack ? opts.oppScore : opts.myScore },
    iAmBlack: !!opts.iAmBlack,
    iWon: iWon,
    winner: iWon ? me : opp,
    territoryDiff: diff,
    komi: opts.komi || 0,
    handicap: opts.handicap || 0,
    moves: opts.moves || 0,
    sgf: opts.sgf || '',
    signature: signature,          // 빨간 경계선 = 행성 지형
    baseSize: Math.max(opts.myScore, opts.oppScore),
    moons: ev.moons,
    particles: ev.particles,
    rings: ev.rings,
    treasure: ev.treasure,
    rainbow: true,                 // 2인 실전 = 무지개 행성
    isRanked: true,
    nickname: ''                   // 유저가 직접 이름 붙임
  };

  galaxy.push(planet);
  applyGrowth(galaxy);
  save(galaxy);

  return { ok:true, planet:planet, total:galaxy.length, events:ev };
}

/* ---------- 통계 ---------- */
function stats(){
  var g = load();
  return {
    planets: g.length,
    wins:    g.filter(function(p){ return p.iWon; }).length,
    territory: g.reduce(function(a,p){ return a + (p.size || p.baseSize || 0); }, 0),
    moons:   g.reduce(function(a,p){ return a + (p.moons||[]).length; }, 0),
    treasures: g.filter(function(p){ return p.treasure; }).length,
    age: g.length ? Math.floor((Date.now() - new Date(g[0].date)) / 86400000) : 0
  };
}

window.Galaxy = {
  load: load, save: save, stats: stats,
  humanCount: humanCount, isRanked: isRanked, opponentName: opponentName,
  birthPlanet: birthPlanet, applyGrowth: applyGrowth,
  RARITY: RARITY
};
console.log('[galaxy] 엔진 로드됨');
})();
