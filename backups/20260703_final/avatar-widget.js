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
    p.style.cssText = 'position:fixed;bottom:64px;left:12px;z-index:9999;background:rgba(10,10,26,0.92);border:1px solid rgba(39,174,96,0.4);border-radius:12px;padding:10px;max-width:260px;font-family:monospace;color:#ddd;font-size:12px;box-shadow:0 4px 20px rgba(0,0,0,0.5)';
    p.innerHTML = '<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">'
      + '<img id="av-w-face" src="' + (localStorage.getItem('av_face') || 'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress&cs=tinysrgb&w=200') + '" style="width:40px;height:40px;border-radius:50%;object-fit:cover;border:2px solid #27AE60">'
      + '<span style="color:#27AE60;font-weight:bold;font-size:11px">'+TW.name+'</span>'
      + '<button id="av-w-min" style="margin-left:auto;background:none;border:none;color:#888;cursor:pointer;font-size:14px">—</button>'
      + '</div>'
      + '<div id="av-w-text" style="line-height:1.5;min-height:32px">게임을 시작하면 바둑 이야기를 들려드려요!</div>'
      + '<div style="font-size:9px;color:#666;margin-top:6px">'+TW.notice+'</div>';
    document.body.appendChild(p);
    W.panel = p;
    document.getElementById('av-w-min').onclick = function(){
      const t = document.getElementById('av-w-text');
      t.style.display = t.style.display==='none' ? 'block' : 'none';
    };
  }

  // 음성 재생 (기존 avatar-engine ElevenLabs 재사용)
  // === 다국어 ===
  const _rw = new URLSearchParams(location.search).get('lang') || localStorage.getItem('lang') || 'ko';
  const AVW_LANG = ({cn:'zh', jp:'ja', kp:'ko'})[_rw] || _rw;
  const AVW_T = {
    ko:{name:'AI 바둑 선생님', notice:'🤖 AI 생성 음성 안내'},
    en:{name:'AI Go Teacher', notice:'🤖 AI-generated voice'},
    zh:{name:'AI围棋老师', notice:'🤖 AI生成语音'},
    ja:{name:'AI囲碁先生', notice:'🤖 AI生成音声'},
    ru:{name:'ИИ-учитель го', notice:'🤖 Голос сгенерирован ИИ'},
    ar:{name:'معلم الغو بالذكاء الاصطناعي', notice:'🤖 صوت مولد بالذكاء الاصطناعي'}
  };
  const TW = AVW_T[AVW_LANG] || AVW_T.ko;
  // API 실패 시 범용 폴백 (비한국어) — 한국어는 게임별 고유 폴백 유지
  const AVW_FB = {
    en:{start:'Welcome! This game trains a key Go concept — enjoy!', milestone:'Great progress! Your Go sense is growing.', gameover:'Well played! Every game builds your Go intuition.'},
    zh:{start:'欢迎！这个游戏训练围棋的核心概念，加油！', milestone:'进步很大！你的围棋感觉正在提升。', gameover:'打得好！每一局都在培养你的围棋直觉。'},
    ja:{start:'ようこそ！このゲームは囲碁の大切な感覚を鍛えます。', milestone:'素晴らしい！囲碁の感覚が育っています。', gameover:'お見事！一局ごとに囲碁の直感が磨かれます。'},
    ru:{start:'Добро пожаловать! Эта игра развивает важное чувство го.', milestone:'Отличный прогресс! Ваше чувство го растёт.', gameover:'Отлично сыграно! Каждая игра развивает интуицию го.'},
    ar:{start:'مرحباً! هذه اللعبة تدرب مفهوماً أساسياً في الغو.', milestone:'تقدم رائع! حسك في الغو ينمو.', gameover:'أحسنت! كل جولة تنمي حدسك في الغو.'}
  };
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
      if(opts.startText) setTimeout(function(){
        if(AVW_LANG!=='ko' && W.speakAI){
          W.speakAI(opts.game||'mining', 0, 'start', (AVW_FB[AVW_LANG]||{}).start || opts.startText);
        } else {
          speak(opts.startText);
        }
      }, 1500);
    },
    speak: speak,
    speakAI: function(game, score, event, fallback){
      if(AVW_LANG!=='ko' && AVW_FB[AVW_LANG]) fallback = AVW_FB[AVW_LANG][event||'milestone'] || fallback;
      // AI 맞춤 멘트 시도 → 3초 내 실패 시 고정 멘트 폴백
      var done = false;
      var timer = setTimeout(function(){
        if(!done){ done = true; if(fallback) speak(fallback); }
      }, 3000);
      fetch('/api/lecture-game?game='+encodeURIComponent(game)+'&score='+(score||0)+'&event='+(event||'milestone')+'&lang='+AVW_LANG)
        .then(function(r){ return r.json(); })
        .then(function(d){
          if(done) return;
          done = true; clearTimeout(timer);
          if(d.ok && d.text) speak(d.text);
          else if(fallback) speak(fallback);
        })
        .catch(function(){
          if(done) return;
          done = true; clearTimeout(timer);
          if(fallback) speak(fallback);
        });
    },
    milestone: function(text){ if(!W.busy) speak(text); },
    gameover: function(text){ speak(text); },
    setGender: function(g){ W.gender = g; localStorage.setItem('av_gender', g); }
  };
})(window);
