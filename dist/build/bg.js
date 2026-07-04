// ===================================
// Tobmate 배경 설정 파일
// BG_CONFIG 값만 바꾸면 스타일 변경!
// ===================================
var BG_CONFIG = {
  style: 'tiles',      // 'tiles' | 'dark' | 'gradient'
  speed: 1.0,
  stoneCount: 7
};

(function(){
  var canvas, ctx, stones = [], frame = 0;

  function init(){
    if(document.getElementById('tobmate-bg')) return;

    // 캔버스는 콘텐츠 영역에만
    var style = document.createElement('style');
    style.textContent = `
      #tobmate-bg {
        position: absolute;
        top: 0; left: 0;
        width: 100%; height: 100%;
        z-index: 0;
        pointer-events: none;
      }
      .lobby-content-area {
        position: relative !important;
      }
    `;
    document.head.appendChild(style);

    canvas = document.createElement('canvas');
    canvas.id = 'tobmate-bg';

    // 메인 콘텐츠 영역 찾기
    var target = null;
    var candidates = document.querySelectorAll('div');
    for(var i=0; i<candidates.length; i++){
      var el = candidates[i];
      if(el.offsetWidth > 600 && el.offsetHeight > 400 && !el.id && el.children.length > 0){
        target = el;
        break;
      }
    }
    if(!target) target = document.body;
    target.style.position = 'relative';
    target.insertBefore(canvas, target.firstChild);

    ctx = canvas.getContext('2d');
    resize();
    window.addEventListener('resize', resize);
    createStones();
    animate();
    console.log('[BG] 배경 로드완료!');
  }

  function resize(){
    if(!canvas) return;
    canvas.width = canvas.offsetWidth || window.innerWidth;
    canvas.height = canvas.offsetHeight || window.innerHeight;
  }

  function createStones(){
    var pos = [
      {xr:0.15,yr:0.72,r:55,b:true, d:0},
      {xr:0.52,yr:0.65,r:42,b:false,d:15},
      {xr:0.78,yr:0.78,r:35,b:true, d:30},
      {xr:0.33,yr:0.82,r:28,b:false,d:45},
      {xr:0.65,yr:0.88,r:22,b:true, d:60},
      {xr:0.10,yr:0.55,r:18,b:false,d:20},
      {xr:0.88,yr:0.55,r:20,b:true, d:35},
    ];
    stones = pos.slice(0, BG_CONFIG.stoneCount).map(function(p){
      return {xr:p.xr,yr:p.yr,r:p.r,black:p.b,delay:p.d,age:0,
              wobble:Math.random()*Math.PI*2,
              wobbleSpeed:(0.015+Math.random()*0.015)*BG_CONFIG.speed,
              settling:0,settled:false};
    });
  }

  function drawBg(){
    var W=canvas.width, H=canvas.height;
    var hz = H*0.42;

    if(BG_CONFIG.style==='tiles'){
      var fg=ctx.createLinearGradient(0,hz,0,H);
      fg.addColorStop(0,'#e8e8e8'); fg.addColorStop(1,'#d0d0d0');
      ctx.fillStyle=fg; ctx.fillRect(0,hz,W,H-hz);
      var sg=ctx.createLinearGradient(0,0,0,hz);
      sg.addColorStop(0,'#f0f0f0'); sg.addColorStop(1,'#e4e4e4');
      ctx.fillStyle=sg; ctx.fillRect(0,0,W,hz);
      ctx.strokeStyle='rgba(160,160,160,0.5)'; ctx.lineWidth=0.7;
      for(var i=0;i<=14;i++){
        var t=i/14, y=hz+(H-hz)*Math.pow(t,0.5), sp=0.06+t*1.7;
        ctx.beginPath(); ctx.moveTo(W*0.5-W*sp,y); ctx.lineTo(W*0.5+W*sp,y); ctx.stroke();
      }
      for(var j=-10;j<=10;j++){
        ctx.beginPath(); ctx.moveTo(W*0.5,hz); ctx.lineTo(W*0.5+j*(W/10),H); ctx.stroke();
      }
    } else if(BG_CONFIG.style==='dark'){
      var dg=ctx.createLinearGradient(0,0,W,H);
      dg.addColorStop(0,'#0f2027'); dg.addColorStop(1,'#2c5364');
      ctx.fillStyle=dg; ctx.fillRect(0,0,W,H);
    } else {
      var lg=ctx.createLinearGradient(0,0,W,H);
      lg.addColorStop(0,'#e8f4f8'); lg.addColorStop(1,'#d0e8f0');
      ctx.fillStyle=lg; ctx.fillRect(0,0,W,H);
    }
  }

  function drawStone(s){
    var W=canvas.width, H=canvas.height;
    var cx=s.xr*W+Math.sin(s.wobble)*2;
    var cy=s.settled?s.yr*H:s.yr*H-(30-Math.min(s.settling,30))*s.r*0.04;
    var r=s.r;
    ctx.save(); ctx.scale(1,0.22);
    var sh=ctx.createRadialGradient(cx,cy*4.5+r,0,cx,cy*4.5+r,r*1.4);
    sh.addColorStop(0,'rgba(0,0,0,0.2)'); sh.addColorStop(1,'rgba(0,0,0,0)');
    ctx.fillStyle=sh; ctx.beginPath();
    ctx.ellipse(cx,cy*4.5+r,r*1.4,r*1.4,0,0,Math.PI*2); ctx.fill();
    ctx.restore();
    var g=ctx.createRadialGradient(cx-r*0.3,cy-r*0.28,r*0.05,cx,cy,r);
    if(s.black){g.addColorStop(0,'#686878');g.addColorStop(0.4,'#282838');g.addColorStop(1,'#080812');}
    else{g.addColorStop(0,'#fff');g.addColorStop(0.4,'#ebebeb');g.addColorStop(1,'#b0b0b8');}
    ctx.fillStyle=g; ctx.beginPath();
    ctx.ellipse(cx,cy,r,r*0.93,0,0,Math.PI*2); ctx.fill();
    var hl=ctx.createRadialGradient(cx-r*0.32,cy-r*0.32,0,cx-r*0.18,cy-r*0.18,r*0.52);
    hl.addColorStop(0,s.black?'rgba(255,255,255,0.22)':'rgba(255,255,255,0.88)');
    hl.addColorStop(1,'rgba(255,255,255,0)');
    ctx.fillStyle=hl; ctx.beginPath();
    ctx.ellipse(cx,cy,r,r*0.93,0,0,Math.PI*2); ctx.fill();
  }

  function animate(){
    if(!canvas) return;
    ctx.clearRect(0,0,canvas.width,canvas.height);
    drawBg();
    stones.forEach(function(s){
      s.age++;
      if(s.age<s.delay) return;
      if(!s.settled){s.settling++;if(s.settling>=30)s.settled=true;}
      s.wobble+=s.wobbleSpeed;
      drawStone(s);
    });
    requestAnimationFrame(animate);
  }

  // React 렌더링 후 실행
  var tries = 0;
  var timer = setInterval(function(){
    tries++;
    var mainArea = document.querySelector('[class*="jss"]');
    if(mainArea || tries > 20){
      clearInterval(timer);
      init();
    }
  }, 300);
})();
