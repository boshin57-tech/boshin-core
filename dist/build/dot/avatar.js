/* ============================================================
   TOBMATE 아바타 엔진 (avatar.js)
   - 카툰 3D 캐릭터. 파일 0, 로딩 0.
   - B1 공방에서 만들고 모든 셀에 공급
   ============================================================ */
(function(){
'use strict';

var SKINS=[0xffe3cf,0xffd0ae,0xd9a877,0xc0854f,0x93603a,0x5f3f28];
var HAIRC=[0x191919,0x3f2a17,0xd9a94a,0xa8391c,0x6b6b6b,0x6a3fb5];
var CLOTH=[0xff6b6b,0x38b6a5,0xf0c93d,0x6c5ce7,0x00a37a,0xe86aa6,0x1f7fd1,0xd96b3f];
var HAIR_NAMES = ['단정','덮개','뽀글','포니테일','장발','투블럭'];
var CLOTH_TYPES = ['한복','정장','캐주얼','도복'];
var FACE_NAMES = ['평온','미소','집중','놀람'];

function hashStr(s){ var h=7; for(var i=0;i<s.length;i++){ h=(h*31+s.charCodeAt(i))>>>0; } return h; }

/* 스펙 — 외부 제작자는 이 형식을 지켜야 함 */
function defaults(seed){
  var h = hashStr(seed||'guest');
  return {
    v: 1, type: 'chibi', seed: seed||'guest',
    skin:  SKINS[h%6],
    hairC: HAIRC[(h>>3)%6],
    hairStyle: (h>>9)%6,
    cloth: CLOTH[(h>>6)%8],
    clothType: (h>>12)%4,
    face: (h>>15)%4,
    gender: (h>>18)%2,   // 0=남 1=여
    glasses: false,
    height: 1.0
  };
}

/* 검증 — 스펙 안 맞으면 거절 */
function validate(cfg){
  var e = [];
  if (!cfg || typeof cfg !== 'object') return { ok:false, errors:['설정이 없습니다'] };
  if (cfg.v !== 1) e.push('버전이 다릅니다 (v:1 필요)');
  if (cfg.type !== 'chibi') e.push('지원하지 않는 타입: ' + cfg.type);
  ['skin','hairC','cloth'].forEach(function(k){
    var v = cfg[k];
    if (typeof v === 'string') v = parseInt(v.replace('#','0x'), 16);
    if (typeof v !== 'number' || v < 0 || v > 0xffffff) e.push(k + ' 색상이 올바르지 않습니다');
  });
  if (cfg.hairStyle < 0 || cfg.hairStyle > 5) e.push('헤어스타일 범위 초과 (0~5)');
  if (cfg.clothType < 0 || cfg.clothType > 3) e.push('의상 범위 초과 (0~3)');
  if (cfg.face < 0 || cfg.face > 3) e.push('표정 범위 초과 (0~3)');
  if (cfg.gender !== undefined && (cfg.gender < 0 || cfg.gender > 1)) e.push('성별 범위 초과 (0~1)');
  if (cfg.height < 0.7 || cfg.height > 1.4) e.push('키 범위 초과 (0.7~1.4)');
  return { ok: e.length === 0, errors: e };
}

function normalize(cfg){
  var d = defaults(cfg && cfg.seed);
  if (!cfg) return d;
  var out = {};
  Object.keys(d).forEach(function(k){ out[k] = (cfg[k] !== undefined) ? cfg[k] : d[k]; });
  ['skin','hairC','cloth'].forEach(function(k){
    if (typeof out[k] === 'string') out[k] = parseInt(out[k].replace('#','0x'), 16);
  });
  return out;
}

/* 저장 */
function key(user){ return 'tobmate_avatar_' + (user||'guest'); }
function load(user){
  try { var r = localStorage.getItem(key(user)); return r ? normalize(JSON.parse(r)) : defaults(user); }
  catch(e){ return defaults(user); }
}
function save(user, cfg){
  var v = validate(normalize(cfg));
  if (!v.ok) return v;
  try { localStorage.setItem(key(user), JSON.stringify(normalize(cfg))); return {ok:true}; }
  catch(e){ return {ok:false, errors:['저장 실패']}; }
}

window.Avatar = {
  SKINS:SKINS, HAIRC:HAIRC, CLOTH:CLOTH,
  HAIR_NAMES:HAIR_NAMES, CLOTH_TYPES:CLOTH_TYPES, FACE_NAMES:FACE_NAMES,
  hashStr:hashStr, defaults:defaults, validate:validate, normalize:normalize,
  load:load, save:save
};

/* ============================================================
   3D 조립 — 카툰 치비 (3.2등신, 캡슐 실루엣, 큰 눈)
   ============================================================ */

/* r128에는 CapsuleGeometry가 없음 — 원기둥+구체로 대체 */
function capsule(r, h, mat){
  var g = new THREE.Group();
  var cy = new THREE.Mesh(new THREE.CylinderGeometry(r, r, h, 12), mat);
  g.add(cy);
  var t = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 10), mat);
  t.position.y = h/2; g.add(t);
  var b = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 10), mat);
  b.position.y = -h/2; g.add(b);
  return g;
}

function makeAvatar(cfg){
  cfg = normalize(cfg);
  var g = new THREE.Group();
  var H = cfg.height || 1.0;

  var mSkin  = new THREE.MeshStandardMaterial({color:cfg.skin,  roughness:0.62});
  var mHair  = new THREE.MeshStandardMaterial({color:cfg.hairC, roughness:0.8});
  var mCloth = new THREE.MeshStandardMaterial({color:cfg.cloth, roughness:0.75});
  var mDark  = new THREE.MeshStandardMaterial({color:0x2b2b2b,  roughness:0.85});
  var mWhite = new THREE.MeshStandardMaterial({color:0xffffff,  roughness:0.25});
  var mIris  = new THREE.MeshStandardMaterial({color:0x3a2418,  roughness:0.2});

  /* --- 다리 (캡슐, 살짝 벌어짐) --- */
  [-0.115, 0.115].forEach(function(x){
    var leg = capsule(0.082, 0.30, mDark);
    leg.position.set(x, 0.42, 0); g.add(leg);
    var shoe = new THREE.Mesh(new THREE.SphereGeometry(0.1, 10, 8), mDark);
    shoe.scale.set(1, 0.6, 1.35); shoe.position.set(x, 0.19, 0.03); g.add(shoe);
  });

  /* --- 몸통 (의상 타입별) --- */
  var F = (cfg.gender === 1);   // 여성
  var body;
  if (cfg.clothType === 0){         // 한복 — 넓게 퍼지는 치마선
    body = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.42, 0.72, 18), mCloth);
    var belt = new THREE.Mesh(new THREE.TorusGeometry(0.27, 0.035, 8, 20), mDark);
    belt.rotation.x = Math.PI/2; belt.position.y = 1.02; g.add(belt);
  } else if (cfg.clothType === 1){  // 정장 — 각지고 단정
    body = new THREE.Mesh(new THREE.CylinderGeometry(F?0.245:0.275, F?0.225:0.245, 0.56, 20), mCloth);
    var tie = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.22, 0.02), mDark);
    tie.position.set(0, 1.02, 0.29); g.add(tie);
  } else if (cfg.clothType === 3){  // 도복 — 넉넉하고 여밈
    body = new THREE.Mesh(new THREE.CylinderGeometry(0.30, 0.34, 0.74, 16), mCloth);
    var lapel = new THREE.Mesh(new THREE.BoxGeometry(0.10, 0.44, 0.03), mWhite);
    lapel.position.set(0, 1.0, 0.30); lapel.rotation.z = 0.12; g.add(lapel);
  } else {                          // 캐주얼
    body = capsule(0.28, 0.44, mCloth);
  }
  body.position.y = 1.04; g.add(body);
  // 골반
  var hip = new THREE.Mesh(new THREE.SphereGeometry(0.24, 16, 12), mCloth);
  hip.scale.set(F?1.05:0.92, 0.62, 0.82); hip.position.y = 0.76; g.add(hip);

  // 목 — 머리와 몸을 잇는다
  var neck = new THREE.Mesh(new THREE.CylinderGeometry(0.10, 0.12, 0.14, 12), mSkin);
  neck.position.y = 1.40; g.add(neck);

  // 어깨 — 원통을 사람 실루엣으로
  [F?-0.265:-0.30, F?0.265:0.30].forEach(function(x){
    var sh = new THREE.Mesh(new THREE.SphereGeometry(F?0.10:0.115, 14, 12), mCloth);
    sh.scale.set(1, 0.85, 1); sh.position.set(x, 1.26, 0); g.add(sh);
  });

  /* --- 팔 (캡슐 + 손) --- */
  var arms = [];
  [[-1, F?-0.275:-0.315], [1, F?0.275:0.315]].forEach(function(s){
    var pivot = new THREE.Group();
    pivot.position.set(s[1], 1.22, 0);
    var arm = capsule(0.058, 0.38, mCloth);
    arm.position.y = -0.24; pivot.add(arm);
    var hand = new THREE.Mesh(new THREE.SphereGeometry(0.078, 10, 10), mSkin);
    hand.position.y = -0.48; pivot.add(hand);
    pivot.rotation.z = s[0] * -0.13;
    g.add(pivot); arms.push(pivot);
  });

  /* --- 머리 (작게 = 3.2등신) --- */
  var head = new THREE.Mesh(new THREE.SphereGeometry(0.36, 24, 22), mSkin);
  head.scale.set(1, 1.06, 0.96);
  head.position.y = 1.72; g.add(head);

  // 얼굴 텍스처 (공인 프리셋용 — 있으면 덮어씀)
  if (cfg.faceTexture){
    var tex = new THREE.TextureLoader().load(cfg.faceTexture);
    var faceP = new THREE.Mesh(
      new THREE.PlaneGeometry(0.52, 0.56),
      new THREE.MeshBasicMaterial({map:tex, transparent:true})
    );
    faceP.position.set(0, 0.0, 0.335);
    head.add(faceP);
    head.userData.hasFaceTex = true;
  }

  /* --- 큰 눈 (흰자 + 홍채 + 하이라이트) — 카툰의 핵심 --- */
  var eyes = [];
  if (!cfg.faceTexture){
    [-0.125, 0.125].forEach(function(x){
      var eg = new THREE.Group();
      eg.position.set(x, 0.02, 0.335);

      var w = new THREE.Mesh(new THREE.SphereGeometry(0.086, 16, 14), mWhite);
      w.scale.set(1, 1.2, 0.42); eg.add(w);

      var ir = new THREE.Mesh(new THREE.SphereGeometry(0.058, 14, 14), mIris);
      ir.scale.set(1, 1, 0.45); ir.position.z = 0.032; eg.add(ir);

      var pu = new THREE.Mesh(new THREE.SphereGeometry(0.03, 12, 12), mDark);
      pu.scale.set(1, 1, 0.4); pu.position.z = 0.05; eg.add(pu);

      // 하이라이트 2개 — 눈이 살아있게
      var hl = new THREE.Mesh(new THREE.SphereGeometry(0.022, 10, 10), mWhite);
      hl.position.set(-0.024, 0.03, 0.07); eg.add(hl);
      var hl2 = new THREE.Mesh(new THREE.SphereGeometry(0.009, 8, 8), mWhite);
      hl2.position.set(0.021, -0.018, 0.066); eg.add(hl2);

      // 눈꺼풀 (깜빡임용)
      var lid = new THREE.Mesh(new THREE.SphereGeometry(0.09, 16, 8, 0, Math.PI*2, 0, Math.PI*0.5), mSkin);
      lid.position.y = 0.105; lid.scale.set(1, 0.18, 0.42);
      eg.add(lid);
      eg.userData.lid = lid;

      if (F){
        var lash = new THREE.Mesh(new THREE.BoxGeometry(0.115, 0.016, 0.02), mDark);
        lash.position.set(0, 0.072, 0.045); lash.rotation.z = (x<0?0.18:-0.18);
        eg.add(lash);
      }
      head.add(eg); eyes.push(eg);
    });

    /* --- 눈썹 (표정) --- */
    var browY = 0.135, browRot = 0;
    if (cfg.face === 1) browY = 0.14;                     // 미소
    else if (cfg.face === 2){ browY = 0.115; browRot = 0.28; }  // 집중 (찌푸림)
    else if (cfg.face === 3){ browY = 0.17; }             // 놀람 (치켜)
    [-0.125, 0.125].forEach(function(x, i){
      var br = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.022, 0.02), mHair);
      br.position.set(x, browY, 0.315);
      br.rotation.z = (i === 0 ? browRot : -browRot);
      head.add(br);
    });

    /* --- 입 (표정) --- */
    var mouth;
    if (cfg.face === 1){        // 미소 — 반달
      mouth = new THREE.Mesh(new THREE.TorusGeometry(0.055, 0.014, 8, 14, Math.PI), mDark);
      mouth.rotation.z = Math.PI; mouth.position.set(0, -0.15, 0.30);
    } else if (cfg.face === 3){ // 놀람 — O
      mouth = new THREE.Mesh(new THREE.SphereGeometry(0.036, 10, 10), mDark);
      mouth.scale.set(1, 1.3, 0.5); mouth.position.set(0, -0.15, 0.30);
    } else {                    // 평온/집중 — 짧은 선
      mouth = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.016, 0.02), mDark);
      mouth.position.set(0, -0.15, 0.31);
    }
    head.add(mouth);

    /* --- 볼터치 --- */
    [-0.20, 0.20].forEach(function(x){
      var ck = new THREE.Mesh(
        new THREE.SphereGeometry(0.048, 10, 8),
        new THREE.MeshStandardMaterial({color:0xff9a9a, transparent:true, opacity:0.35, roughness:1})
      );
      ck.scale.set(1.3, 0.8, 0.28);
      ck.position.set(x, -0.07, 0.265);
      head.add(ck);
    });
  }

  /* --- 귀 --- */
  [-0.345, 0.345].forEach(function(x){
    var ear = new THREE.Mesh(new THREE.SphereGeometry(0.062, 10, 10), mSkin);
    ear.scale.set(0.5, 1, 0.7); ear.position.set(x, -0.02, 0);
    head.add(ear);
  });

  /* --- 머리카락 6종 --- */
  buildHair(head, cfg.hairStyle, mHair);

  /* --- 안경 --- */
  if (cfg.glasses){
    var mG = new THREE.MeshStandardMaterial({color:0x222222, roughness:0.3, metalness:0.4});
    [-0.125, 0.125].forEach(function(x){
      var rim = new THREE.Mesh(new THREE.TorusGeometry(0.082, 0.011, 8, 18), mG);
      rim.position.set(x, 0.03, 0.325); head.add(rim);
    });
    var br2 = new THREE.Mesh(new THREE.CylinderGeometry(0.009, 0.009, 0.07, 6), mG);
    br2.rotation.z = Math.PI/2; br2.position.set(0, 0.03, 0.325); head.add(br2);
  }

  g.scale.setScalar(H);
  g.userData = {
    cfg: cfg, head: head, eyes: eyes,
    armL: arms[0], armR: arms[1],
    blinkT: Math.random()*4
  };
  return g;
}

function buildHair(head, style, mHair){
  // 반구를 살짝 키우고 위로 — 얼굴(z+ 방향)을 덮지 않게
  function cap(phi, y, r){
    var m = new THREE.Mesh(
      new THREE.SphereGeometry(r||0.375, 22, 18, 0, Math.PI*2, 0, Math.PI*phi), mHair);
    m.position.y = y; m.scale.z = 0.98;
    head.add(m); return m;
  }
  if (style === 0){            // 단정
    cap(0.42, 0.06);
    var f0 = new THREE.Mesh(new THREE.SphereGeometry(0.15, 12, 10), mHair);
    f0.scale.set(1.7, 0.32, 0.5); f0.position.set(0, 0.235, 0.19); head.add(f0);
  } else if (style === 1){     // 덮개 (앞머리)
    cap(0.46, 0.05, 0.382);
    var f1 = new THREE.Mesh(new THREE.SphereGeometry(0.19, 14, 12), mHair);
    f1.scale.set(1.55, 0.42, 0.5); f1.position.set(0, 0.185, 0.22); head.add(f1);
  } else if (style === 2){     // 뽀글
    cap(0.40, 0.07, 0.37);
    [[0,0.30,-0.02],[-0.21,0.25,0.06],[0.21,0.25,0.06],[0,0.20,-0.26],[-0.24,0.12,-0.16],[0.24,0.12,-0.16]].forEach(function(p){
      var pf = new THREE.Mesh(new THREE.SphereGeometry(0.145, 12, 10), mHair);
      pf.position.set(p[0], p[1], p[2]); head.add(pf);
    });
  } else if (style === 3){     // 포니테일
    cap(0.43, 0.06, 0.378);
    var f3 = new THREE.Mesh(new THREE.SphereGeometry(0.14, 12, 10), mHair);
    f3.scale.set(1.6, 0.3, 0.5); f3.position.set(0, 0.235, 0.19); head.add(f3);
    var t1 = capsule(0.085, 0.22, mHair);
    t1.position.set(0, 0.06, -0.36); t1.rotation.x = -0.55; head.add(t1);
    var t2 = new THREE.Mesh(new THREE.SphereGeometry(0.07, 10, 10), mHair);
    t2.position.set(0, -0.13, -0.42); head.add(t2);
  } else if (style === 4){     // 장발
    cap(0.45, 0.05, 0.382);
    var f4 = new THREE.Mesh(new THREE.SphereGeometry(0.17, 12, 10), mHair);
    f4.scale.set(1.6, 0.35, 0.5); f4.position.set(0, 0.21, 0.20); head.add(f4);
    [-0.30, 0.30].forEach(function(x){
      var sd = capsule(0.072, 0.30, mHair);
      sd.position.set(x, -0.20, -0.05); head.add(sd);
    });
    var bk = capsule(0.135, 0.24, mHair);
    bk.position.set(0, -0.17, -0.23); head.add(bk);
  } else {                     // 투블럭
    cap(0.34, 0.10, 0.372);
    var top = new THREE.Mesh(new THREE.SphereGeometry(0.17, 14, 12), mHair);
    top.scale.set(1.5, 0.62, 1.1); top.position.set(0, 0.26, 0.02); head.add(top);
    var f5 = new THREE.Mesh(new THREE.SphereGeometry(0.13, 12, 10), mHair);
    f5.scale.set(1.5, 0.3, 0.45); f5.position.set(0, 0.245, 0.20); head.add(f5);
  }
}


/* ============================================================
   애니메이션 — 숨쉬기 · 눈 깜빡임 · 걷기 · 말하기
   ============================================================ */
function animate(av, t, state){
  if (!av || !av.userData) return;
  var u = av.userData;
  state = state || {};

  // 숨쉬기
  if (u.head) u.head.position.y = 1.72 + Math.sin(t*1.6)*0.012;

  // 눈 깜빡임 (2~6초 간격)
  if (u.eyes && u.eyes.length){
    u.blinkT -= 0.016;
    var closing = 0;
    if (u.blinkT < 0.14 && u.blinkT > 0){
      closing = 1 - Math.abs(u.blinkT - 0.07) / 0.07;
    } else if (u.blinkT <= 0){
      u.blinkT = 2 + Math.random()*4;
    }
    u.eyes.forEach(function(e){
      if (e.userData.lid){
        e.userData.lid.scale.y = 0.28 + closing * 1.75;
        e.userData.lid.position.y = 0.085 - closing * 0.095;
      }
    });
  }

  // 말하기 — 고개 살짝 끄덕
  if (state.speaking && u.head){
    u.head.rotation.x = Math.sin(t*7)*0.045;
    if (u.armR) u.armR.rotation.x = Math.sin(t*5)*0.2 - 0.15;
  } else if (u.head){
    u.head.rotation.x *= 0.9;
  }

  // 걷기 — 팔 흔들기
  if (state.walking){
    if (u.armL) u.armL.rotation.x =  Math.sin(t*9)*0.5;
    if (u.armR) u.armR.rotation.x = -Math.sin(t*9)*0.5;
    av.position.y = Math.abs(Math.sin(t*9))*0.04;
  } else {
    if (u.armL) u.armL.rotation.x *= 0.88;
    if (u.armR) u.armR.rotation.x *= 0.88;
    av.position.y *= 0.88;
  }

  // 생각중 — 고개 갸웃
  if (state.thinking && u.head){
    u.head.rotation.z = Math.sin(t*0.9)*0.09;
  } else if (u.head){
    u.head.rotation.z *= 0.92;
  }
}

/* 이름표 */
function addLabel(g, text, color){
  var cv = document.createElement('canvas'); cv.width=512; cv.height=96;
  var ctx = cv.getContext('2d');
  ctx.fillStyle='rgba(0,0,0,0.6)';
  if (ctx.roundRect){ ctx.beginPath(); ctx.roundRect(4,10,504,76,16); ctx.fill(); }
  else ctx.fillRect(4,10,504,76);
  var fs=40; ctx.font='bold '+fs+'px sans-serif';
  while(ctx.measureText(text).width>480 && fs>16){ fs-=2; ctx.font='bold '+fs+'px sans-serif'; }
  ctx.textAlign='center'; ctx.textBaseline='middle';
  ctx.fillStyle=color||'#ffffff'; ctx.fillText(text,256,48);
  var sp = new THREE.Sprite(new THREE.SpriteMaterial({
    map:new THREE.CanvasTexture(cv), transparent:true }));
  sp.scale.set(2.0,0.38,1); sp.position.y=2.5; g.add(sp);
  return sp;
}

/* 공인 프리셋 — 승인된 프로기사용 (나중에 채움) */
var PRESETS = {
  teacher: { v:1, type:'chibi', seed:'teacher',
    skin:SKINS[3], hairC:0x191919, cloth:0x2c3e60,
    hairStyle:0, clothType:1, face:1, glasses:true, height:1.15 }
  // 승인 후 추가:
  // pro_a: { ..., faceTexture:'/dot/faces/xxx.jpg', official:true }
};

/* JSON 입출력 — 외부 제작 아바타 */
function importJSON(str){
  try {
    var cfg = typeof str === 'string' ? JSON.parse(str) : str;
    var v = validate(normalize(cfg));
    return v.ok ? {ok:true, cfg:normalize(cfg)} : v;
  } catch(e){ return {ok:false, errors:['JSON 형식이 잘못되었습니다']}; }
}
function exportJSON(cfg){
  var c = normalize(cfg);
  return JSON.stringify({
    v:1, type:'chibi',
    skin:'#'+c.skin.toString(16).padStart(6,'0'),
    hairC:'#'+c.hairC.toString(16).padStart(6,'0'),
    cloth:'#'+c.cloth.toString(16).padStart(6,'0'),
    hairStyle:c.hairStyle, clothType:c.clothType,
    face:c.face, gender:c.gender, glasses:c.glasses, height:c.height
  }, null, 2);
}

window.Avatar.makeAvatar = makeAvatar;
window.Avatar.animate = animate;
window.Avatar.addLabel = addLabel;
window.Avatar.PRESETS = PRESETS;
window.Avatar.importJSON = importJSON;
window.Avatar.exportJSON = exportJSON;

console.log('[avatar] 엔진 로드됨 — 조합 55,296가지');
})();
