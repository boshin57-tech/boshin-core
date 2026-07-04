/* avatar-widget.js — 우주게임용 AI 아바타 강사 위젯 (음성 중심) */
(function(global){
  const W = {
    gender: localStorage.getItem('av_gender') || 'female',
    lang: 'ko',
    busy: false,
    panel: null,
    gameName: '',
    goConcept: '',
  };

  // 플로팅 패널 생성
  function createPanel(){
    if(W.panel) return;
    const p = document.createElement('div');
    p.id = 'av-widget';
    p.style.cssText = 'position:fixed;bottom:12px;right:12px;z-index:9999;background:rgba(10,10,26,0.92);border:1px solid rgba(39,174,96,0.4);border-radius:12px;padding:10px;max-width:260px;font-family:monospace;color:#ddd;font-size:12px;box-shadow:0 4px 20px rgba(0,0,0,0.5)';
    p.innerHTML = '<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">'
      + '<img id="av-w-face" src="' + (localStorage.getItem('av_face') || 'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress&cs=tinysrgb&w=200') + '" style="width:40px;height:40px;border-radius:50%;object-fit:cover;border:2px solid #27AE60">'
      + '<span style="color:#27AE60;font-weight:bold;font-size:11px">AI 바둑 선생님</span>'
      + '<button id="av-w-min" style="margin-left:auto;background:none;border:none;color:#888;cursor:pointer;font-size:14px">—</button>'
      + '</div>'
      + '<div id="av-w-text" style="line-height:1.5;min-height:32px">게임을 시작하면 바둑 이야기를 들려드려요!</div>'
      + '<div style="font-size:9px;color:#666;margin-top:6px">🤖 AI 생성 음성 안내</div>';
    document.body.appendChild(p);
    W.panel = p;
    document.getElementById('av-w-min').onclick = function(){
      const t = document.getElementById('av-w-text');
      t.style.display = t.style.display==='none' ? 'block' : 'none';
    };
  }

  // 음성 재생 (기존 avatar-engine ElevenLabs 재사용)
  async function speak(text){
    if(W.busy) return;
    W.busy = true;
    try {
      const t = document.getElementById('av-w-text');
      if(t) t.textContent = text;
      const r = await fetch('/avatar/eleven/speak', {
        method: 'POST',
        headers: {'Content-Type':'application/json'},
        body: JSON.stringify({text: text, gender: W.gender})
      });
      const d = await r.json();
      if(d.audio_base64){
        const audio = new Audio('data:audio/mpeg;base64,' + d.audio_base64);
        audio.onended = function(){ W.busy = false; };
        audio.play().catch(function(){ W.busy = false; });
      } else { W.busy = false; }
    } catch(e){ W.busy = false; console.warn('[AV-W]', e.message); }
  }

  // 이벤트 훅
  const handlers = { start: [], milestone: [], gameover: [] };

  global.AvatarWidget = {
    init: function(opts){
      W.gameName = opts.game || '';
      W.goConcept = opts.concept || '';
      createPanel();
      if(opts.startText) setTimeout(function(){ speak(opts.startText); }, 1500);
    },
    speak: speak,
    milestone: function(text){ if(!W.busy) speak(text); },
    gameover: function(text){ speak(text); },
    setGender: function(g){ W.gender = g; localStorage.setItem('av_gender', g); }
  };
})(window);
