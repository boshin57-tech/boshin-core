// ══════════════════════════════════════════
// Tobmate Space Engine — 공통 SAU/피드 유틸리티
// 5개 우주 게임(space, star_solar, star_signal, star_nav, star_gravity)이 공유
// ══════════════════════════════════════════
(function(global){
  const _urlP = new URLSearchParams(location.search);
  const _userId = _urlP.get('user') || 'guest';

  // 피드 메시지 큐 — 게임마다 prefix만 다르게 설정
  function createFeed(prefix, elId){
    const fq = [];
    return function feed(m){
      fq.unshift(m);
      if (fq.length > 3) fq.pop();
      const el = document.getElementById(elId || 'feed');
      if (el) el.textContent = '[ ' + prefix + ' ] ' + fq[0];
    };
  }

  // 게임 세션 결과를 서버로 보고 (부정조작 방지 검증 포함)
  async function reportSAU(game, sessionSau, seconds, onWarn){
    try {
      const r = await fetch('/sau-api/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: _userId, game, session_sau: sessionSau, session_seconds: seconds })
      });
      const d = await r.json();
      if (d.ok) {
        if (onWarn) {
          if (d.rate_capped) onWarn('속도 제한 적용됨');
          if (d.daily_capped) onWarn('일일 SAU 한도 도달!');
        }
        return d.granted;
      }
      return sessionSau;
    } catch(e) {
      console.error('SAU 보고 실패', e);
      return sessionSau;
    }
  }

  // 서버에 저장된 SAU 잔액 조회
  async function loadSauBalance(){
    try {
      const r = await fetch('/sau-api/balance/' + encodeURIComponent(_userId));
      const d = await r.json();
      if (d.ok) return { total: d.total || 0, dailyEarned: d.daily_earned || 0 };
      return null;
    } catch(e) {
      console.error('SAU 잔액 로드 실패', e);
      return null;
    }
  }

  // 페이지 이탈 시에도 마지막 세션을 안전하게 전송 (beacon API)
  function flushOnUnload(game, getSessionSau, getSeconds){
    window.addEventListener('beforeunload', () => {
      const sau = getSessionSau();
      if (sau > 0 && navigator.sendBeacon) {
        navigator.sendBeacon('/sau-api/session', JSON.stringify({
          user_id: _userId, game, session_sau: sau, session_seconds: getSeconds()
        }));
      }
    });
  }

  // ── 공통 렌더링 헬퍼 (행성/항성 입체 효과) ──
  const SPARK_COLORS = ['#FFD700','#00FFFF','#FF69B4','#7FFF00','#FFA500','#87CEFA','#DA70D6'];

  function createOrbiters(count, colors){
    return Array.from({length: count}, (_, i) => ({
      dist: 1.8 + i * 0.7,
      angle: Math.random() * Math.PI * 2,
      speed: (0.004 + Math.random() * 0.006) * (Math.random() < 0.5 ? 1 : -1),
      size: 3 + Math.random() * 3.5,
      col: colors[i % colors.length]
    }));
  }

  function createSparkles(count, colors){
    return Array.from({length: count}, () => ({
      angle: Math.random() * Math.PI * 2,
      dist: 1.0 + Math.random() * 1.5,
      phase: Math.random() * Math.PI * 2,
      speed: 0.02 + Math.random() * 0.04,
      col: (colors || SPARK_COLORS)[Math.floor(Math.random() * (colors || SPARK_COLORS).length)]
    }));
  }

  // 캔버스에 반짝이는 입자 그리기 (글로우 그라디언트 포함)
  function drawSparkle(ctx, cx, cy, sp, baseR){
    sp.phase += sp.speed;
    const tw = 0.4 + Math.sin(sp.phase) * 0.6;
    if (tw < 0.1) return;
    const x = cx + Math.cos(sp.angle) * baseR * sp.dist;
    const y = cy + Math.sin(sp.angle) * baseR * sp.dist;
    const g = ctx.createRadialGradient(x, y, 0, x, y, 3.5 + tw * 3.5);
    g.addColorStop(0, sp.col);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.globalAlpha = tw;
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(x, y, 3.5 + tw * 3.5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = sp.col;
    ctx.beginPath(); ctx.arc(x, y, 1.6 + tw * 1.8, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── 터치/마우스 통합 입력 헬퍼 ──
  // 마우스든 터치든 동일한 (x,y) 좌표를 반환
  function getPointerXY(e, el){
    const r = el.getBoundingClientRect();
    if (e.touches && e.touches.length > 0) {
      return { x: e.touches[0].clientX - r.left, y: e.touches[0].clientY - r.top };
    }
    if (e.changedTouches && e.changedTouches.length > 0) {
      return { x: e.changedTouches[0].clientX - r.left, y: e.changedTouches[0].clientY - r.top };
    }
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  }

  // 클릭/탭 핸들러를 마우스+터치 양쪽에 동시 바인딩 (모바일 히트박스 자동 확대)
  function bindTap(el, handler){
    let touched = false;
    el.addEventListener('touchstart', e => {
      touched = true;
      e.preventDefault();
      handler(e, getPointerXY(e, el));
    }, { passive: false });
    el.addEventListener('click', e => {
      if (touched) { touched = false; return; } // 터치 직후 발생하는 ghost click 무시
      handler(e, getPointerXY(e, el));
    });
  }

  // 드래그(조준 등) 핸들러를 마우스+터치 양쪽에 동시 바인딩
  function bindDrag(el, { onStart, onMove, onEnd }){
    let active = false;
    function start(e){
      const pt = getPointerXY(e, el);
      if (onStart(pt) !== false) { active = true; if (e.cancelable) e.preventDefault(); }
    }
    function move(e){
      if (!active) return;
      if (e.cancelable) e.preventDefault();
      onMove(getPointerXY(e, el));
    }
    function end(e){
      if (!active) return;
      active = false;
      onEnd(getPointerXY(e, el));
    }
    el.addEventListener('mousedown', start);
    el.addEventListener('mousemove', move);
    window.addEventListener('mouseup', end);
    el.addEventListener('touchstart', start, { passive: false });
    el.addEventListener('touchmove', move, { passive: false });
    el.addEventListener('touchend', end);
  }

  // 터치 디바이스 여부 감지 (모바일 전용 UI 힌트 등에 사용)
  function isTouchDevice(){
    return ('ontouchstart' in window) || (navigator.maxTouchPoints > 0);
  }

  // 공개 API
  global.SpaceEngine = {
    getPointerXY,
    bindTap,
    bindDrag,
    isTouchDevice,
    userId: _userId,
    createFeed,
    reportSAU,
    loadSauBalance,
    flushOnUnload,
    createOrbiters,
    createSparkles,
    drawSparkle,
    SPARK_COLORS
  };
})(window);
