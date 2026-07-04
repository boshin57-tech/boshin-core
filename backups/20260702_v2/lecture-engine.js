'use strict';
const http      = require('http');
const Anthropic = require('@anthropic-ai/sdk');

const PORT      = 8016;

function classifyBoardPoint(coord, boardsize){
  if(!coord || coord==='?' || coord.toLowerCase()==='pass') return null;
  const cols = 'ABCDEFGHJKLMNOPQRST';
  const colChar = coord[0].toUpperCase();
  const rowNum = parseInt(coord.slice(1));
  if(isNaN(rowNum)) return null;
  const x = cols.indexOf(colChar);
  if(x === -1) return null;
  const n = boardsize || 19;
  const y = n - rowNum;
  if(x<0||x>=n||y<0||y>=n) return null;

  const distFromEdge = (v) => Math.min(v, n-1-v);
  const dx = distFromEdge(x);
  const dy = distFromEdge(y);

  if(n !== 19) return null;

  if(dx===2 && dy===2) return '삼삼';
  if((dx===3 && dy===3)) return '화점';
  if((dx===2 && dy===3) || (dx===3 && dy===2)) return '소목';
  if((dx===2 && dy===4) || (dx===4 && dy===2)) return '외목';
  if((dx===3 && dy===4) || (dx===4 && dy===3)) return '고목';
  if(dx===3 && dy===9) return '변의 중앙(텐겐 라인)';
  if(dx<=1 || dy<=1) return '1~2선(실리 변두리)';
  return null;
}

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// 대화 히스토리 저장 (room별)
const chatHistory = {};

const LEVELS = {
  ko: ['입문','초급','중급','고급','최상급'],
  en: ['beginner','intermediate','advanced','expert','master'],
};

const COLOR_NAME = {
  ko: {0:'흑',1:'백'}, en: {0:'Black',1:'White'},
};

function getLevel(tpi, lang) {
  const l = LEVELS[lang] || LEVELS.en;
  if (tpi < 200) return l[0];
  if (tpi < 400) return l[1];
  if (tpi < 600) return l[2];
  if (tpi < 800) return l[3];
  return l[4];
}

function getPhase(turn) {
  if (turn < 40) return '포석';
  if (turn < 120) return '중반';
  return '끝내기';
}

function getWinrateComment(prev, cur) {
  const diff = cur - prev;
  if (Math.abs(diff) < 2) return '';
  if (diff > 15) return `(흑 승률 ${diff.toFixed(1)}% 급등 — 핵심 수)`;
  if (diff < -15) return `(백에게 유리한 역전 수 ${Math.abs(diff).toFixed(1)}%)`;
  if (diff > 5) return `(흑 유리 +${diff.toFixed(1)}%)`;
  if (diff < -5) return `(백 유리 ${diff.toFixed(1)}%)`;
  return '';
}

function parseQuery(url) {
  const u = new URL(url, 'http://x');
  return Object.fromEntries(u.searchParams);
}

// KataGo 최선수 조회
async function getKatagoTopMove(boardStr, boardsize, rule, turn) {
  return new Promise((resolve) => {
    try {
      const body = JSON.stringify({
        room_id: 'lec_' + Date.now(),
        boardsize: boardsize || 19,
        board: boardStr,
        rule: rule || 0
      });
      const req = http.request({
        hostname: 'localhost', port: 8098,
        path: '/score', method: 'POST',
        headers: {'Content-Type':'application/json','Content-Length':Buffer.byteLength(body)}
      }, (res) => {
        let data = '';
        res.on('data', d => data += d);
        res.on('end', () => {
          try { resolve(JSON.parse(data)); }
          catch(e) { resolve(null); }
        });
      });
      req.on('error', () => resolve(null));
      req.setTimeout(2500, () => { req.destroy(); resolve(null); });
      req.write(body); req.end();
    } catch(e) { resolve(null); }
  });
}

const server = http.createServer(async (req, res) => {
  const url = req.url || '/';
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  if (url === '/health') {
    res.writeHead(200, {'Content-Type':'application/json; charset=utf-8'});
    return res.end(JSON.stringify({status:'ok', port:PORT}));
  }

  // GET /lecture
  if (url.startsWith('/lecture') && req.method === 'GET') {
    const q       = parseQuery(url);
    const lang    = q.lang || 'ko';
    const gender  = q.gender || 'female';
    const tpi     = parseInt(q.playerTPI) || 0;
    const lvl     = getLevel(tpi, lang);
    const winCur  = parseFloat(q.winrate) || 0.5;
    const winPrev = parseFloat(q.prevWinrate) || winCur;
    const coord   = q.lastMove || '?';
    const cornerPointType = classifyBoardPoint(coord, parseInt(q.boardsize) || 19);
    const turn    = parseInt(q.turn) || 0;
    const totalMoves = parseInt(q.totalMoves) || turn;
    const colorName = (COLOR_NAME[lang] || COLOR_NAME.ko)[turn % 2] || '흑';
    const phase   = getPhase(turn);
    const winComment = getWinrateComment(winPrev * 100, winCur * 100);
    const nearBoard = q.nearBoard || '';
    const rule    = parseInt(q.rule) || 0;
const ruleDescMap = {
  ko: {sunjang:'순장바둑', normal:'일반바둑(일본룰)'},
  en: {sunjang:'Sunjang Baduk', normal:'Standard Go (Japanese rules)'},
  zh: {sunjang:'巡장围棋', normal:'标准围棋(日本规则)'},
  ja: {sunjang:'スンジャン碁', normal:'標準囲碁(日本ルール)'},
  ru: {sunjang:'Сунджан Бадук', normal:'Стандартная игра Го (японские правила)'},
  ar: {sunjang:'سونجانج بادوك', normal:'لعبة الغو القياسية (القواعد اليابانية)'}
};
const ruleDescLng = ruleDescMap[lang] || ruleDescMap.en;
const ruleDesc = rule === 2 ? ruleDescLng.sunjang : ruleDescLng.normal;
    const roomId  = q.roomId || 'default';
    const boardStr = q.boardStr || '';
    const winDiff = Math.abs(winCur - winPrev) * 100;
    const isKeyMove = winDiff > 8;
    const maxTok  = isKeyMove ? 400 : 250;
    const winTrend = winCur > winPrev
      ? `흑에게 유리 (+${((winCur-winPrev)*100).toFixed(1)}%)`
      : winCur < winPrev
      ? `백에게 유리 (+${((winPrev-winCur)*100).toFixed(1)}%)`
      : '균형 유지';

    // 대화 히스토리 관리 (최근 3수)
    if (!chatHistory[roomId]) chatHistory[roomId] = [];
    const history = chatHistory[roomId];

    // 보드 컨텍스트
    const boardContext = nearBoard
      ? `\n착수 주변 국면 (●흑 ○백 +빈칸, 가운데가 착수점):\n${nearBoard}`
      : '';

    // 이전 강의 컨텍스트
    const prevContext = history.length > 0
      ? `\n[이전 ${history.length}수 흐름]\n` + history.slice(-3).map(h => h.summary).join(' → ')
      : '';

const langInst = {
  ko: '반드시 한국어로만 답하세요.',
  en: 'You must answer in English only.',
  zh: '请只用中文回答。',
  ja: '必ず日本語のみで答えてください。',
  ru: 'Отвечайте только на русском языке.',
  ar: 'يجب أن تجيب باللغة العربية فقط.'
};
const langInstText = langInst[lang] || langInst.en;
    const systemPrompt = `당신은 ${ruleDesc} AI 강사입니다. ${langInstText}

[대국 정보]
- 게임: ${ruleDesc}
- 국면: ${phase} (${turn}수째 / 총 ${totalMoves}수)
- 학생 수준: ${lvl}
- 착수 후 승률 변화: ${winTrend} (현재 흑 ${(winCur*100).toFixed(1)}%)
- 착수 좌표 ${coord}의 정확한 분류: ${cornerPointType || '귀퉁이 정형점이 아닌 일반 좌표'} (이 분류는 서버에서 좌표를 계산해 확정한 값이므로 반드시 이 명칭을 그대로 사용하고 절대 다른 명칭으로 부르지 마세요)${boardContext}${prevContext}

[강의 지침]
${isKeyMove
  ? `이 수는 승률이 ${winDiff.toFixed(1)}% 변한 핵심 착수입니다:
1. 왜 이 수가 중요한지 (세력/실리/공격/수비)
2. 이 수를 두지 않았다면 생길 문제
3. 다음 주목해야 할 지점`
  : `이 수의 의도와 다음 주목 포인트를 ${lvl} 수준에 맞게 설명하세요.`}
- ${ruleDesc} 특성 반영
- 이전 흐름을 자연스럽게 이어서 설명
- 마크다운 기호 절대 금지
- 2~3문장으로 간결하게`;

    // 멀티턴 메시지 구성
    const messages = [];
    // 이전 대화 추가 (최근 2턴)
    history.slice(-2).forEach(h => {
      messages.push({role:'user', content: h.userMsg});
      messages.push({role:'assistant', content: h.assistantMsg});
    });
    // 현재 착수
    const currentUserMsg = `${colorName}이 ${coord}에 착수했습니다 ${winComment}\n현재 흑 승률: ${(winCur*100).toFixed(1)}% | ${phase} ${turn}수`;
    messages.push({role:'user', content: currentUserMsg});

    try {
      const msg = await anthropic.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: maxTok,
        system: systemPrompt,
        messages: messages
      });
      const rawText = msg.content[0]?.text || '';
      const text = rawText.replace(/\*\*(.+?)\*\*/g,'$1').replace(/\*(.+?)\*/g,'$1').replace(/#{1,6}\s+/g,'').trim();

      // 히스토리 저장 (요약 포함)
      history.push({
        turn, coord, colorName,
        userMsg: currentUserMsg,
        assistantMsg: text,
        summary: `${turn}수 ${colorName} ${coord}: ${text.slice(0,30)}...`
      });
      // 최근 6수만 유지
      if (history.length > 6) history.shift();
      chatHistory[roomId] = history;

      console.log(`[lecture][${phase}][${colorName}][${coord}][${winDiff.toFixed(1)}%] ${text.slice(0,50)}`);
      const body = Buffer.from(JSON.stringify({ok:true, text, lang, gender, level:lvl, coord, color:colorName, phase, isKeyMove}), 'utf8');
      res.writeHead(200, {'Content-Type':'application/json; charset=utf-8', 'Content-Length': body.length});
      res.end(body);
    } catch(err) {
      console.error('[lecture]', err.message);
      const body = Buffer.from(JSON.stringify({ok:false, error:err.message}), 'utf8');
      res.writeHead(500, {'Content-Type':'application/json; charset=utf-8'});
      res.end(body);
    }
    return;
  }

  // POST /review
  if ((url.startsWith('/review') || url.startsWith('/api/review')) && req.method === 'POST') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const data  = JSON.parse(body);
        const lang  = data.lang || 'ko';
        const moves = data.moves || '';
        const total = data.total || 0;
        const tpi   = parseInt(data.playerTPI) || 300;
        const lvl   = getLevel(tpi, lang);
        const roomId = data.roomId || 'default';
        const history = chatHistory[roomId] || [];

        const prevFlow = history.length > 0
          ? `\n[강의 중 주요 착수 흐름]\n` + history.map(h=>h.summary).join('\n')
          : '';

        const reviewLangInst = {
          ko:'반드시 한국어로만 답하세요.',
          en:'You must answer in English only.',
          zh:'请只用中文回答。',
          ja:'必ず日本語のみで答えてください。',
          ru:'Отвечайте только на русском языке.',
          ar:'يجب أن تجيب باللغة العربية فقط.'
        }[lang] || 'You must answer in English only.';
        const reviewRuleDesc = {
          ko:{s:'순장바둑',n:'일반바둑'},
          en:{s:'Sunjang Baduk',n:'Standard Go'},
          zh:{s:'巡장围棋',n:'标准围棋'},
          ja:{s:'スンジャン碁',n:'標準囲碁'},
          ru:{s:'Сунджан',n:'Стандартное Го'},
          ar:{s:'سونجانج',n:'الغو القياسي'}
        }[lang] || {s:'Sunjang Baduk',n:'Standard Go'};
        const reviewRule = data.rule===2 ? reviewRuleDesc.s : reviewRuleDesc.n;
        const systemPrompt = `당신은 ${reviewRule} AI 강사입니다. ${reviewLangInst} ${lvl} 수준 학생의 ${total}수 대국을 복기합니다.${prevFlow}

다음 구조로 분석하세요:
1. 전체 흐름 한 줄 평가
2. 가장 잘한 수 1개 (좌표와 이유)
3. 가장 아쉬운 수 1개 (좌표와 개선 방향)
4. 다음 대국 핵심 조언 1가지
마크다운 금지, 4~5문장으로 자연스럽게.`;

        const msg = await anthropic.messages.create({
          model: 'claude-sonnet-4-6', max_tokens: 500,
          system: systemPrompt,
          messages: [{role:'user', content:`기보: ${moves.slice(0,500)}\n총 ${total}수`}]
        });
        const rawText = msg.content[0]?.text || '';
        const text = rawText.replace(/\*\*(.+?)\*\*/g,'$1').replace(/\*(.+?)\*/g,'$1').replace(/#{1,6}\s+/g,'').trim();
        console.log(`[review][${lang}] ${text.slice(0,50)}`);
        // 복기 후 히스토리 초기화
        chatHistory[roomId] = [];
        const rbody = Buffer.from(JSON.stringify({ok:true, text, lang, level:lvl}), 'utf8');
        res.writeHead(200, {'Content-Type':'application/json; charset=utf-8', 'Content-Length': rbody.length});
        res.end(rbody);
      } catch(err) {
        console.error('[review]', err.message);
        const rbody = Buffer.from(JSON.stringify({ok:false, error:err.message}), 'utf8');
        res.writeHead(500, {'Content-Type':'application/json; charset=utf-8'});
        res.end(rbody);
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => console.log(`[lecture-engine] port ${PORT} ready`));
