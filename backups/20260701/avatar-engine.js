'use strict';
const http = require('http');
const https = require('https');

const PORT = 8019;
const DID_API_KEY = 'Ym9zaGluNTdAZ21haWwuY29t:_3AbdYfGnksaLuJyQvVoc';
const ELEVEN_API_KEY = 'sk_adda0bba56bffb558d3c9f6818357d172cf896741632ac1f';
const ELEVEN_VOICE_MALE = 'JBFqnCBsd6RMkjVDRZzb';
const ELEVEN_VOICE_FEMALE = 'EXAVITQu4vr4xnSDxMaL';
const DEFAULT_AVATAR_MALE = 'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?auto=compress&cs=tinysrgb&w=800';
const DEFAULT_AVATAR_FEMALE = 'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=800';

function didRequest(method, path, data) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: 'api.d-id.com', path, method,
      headers: {
        'Authorization': `Basic ${DID_API_KEY}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    };
    const req = https.request(opts, r => {
      let body = '';
      r.on('data', d => body += d);
      r.on('end', () => { try { resolve(JSON.parse(body)); } catch(e) { resolve({raw:body}); } });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function createTalk(text, lang, avatarUrl) {
  const data = {
    source_url: avatarUrl || DEFAULT_AVATAR,
    script: {
      type: 'text', input: text,
      provider: {
        type: 'microsoft',
        voice_id: lang === 'ko-KR' ? 'ko-KR-SunHiNeural' : 'en-US-JennyNeural'
      }
    },
    config: { fluent: true, pad_audio: 0.5 }
  };
  console.log('[avatar] D-ID 요청:', text.slice(0,30));
  return await didRequest('POST', '/talks', data);
}

function elevenSpeak(text, voiceId) {
  return new Promise((resolve, reject) => {
    const vid = voiceId || ELEVEN_VOICE_MALE;
    const data = JSON.stringify({
      text,
      model_id: 'eleven_multilingual_v2',
      voice_settings: { stability: 0.5, similarity_boost: 0.8 }
    });
    const opts = {
      hostname: 'api.elevenlabs.io',
      path: `/v1/text-to-speech/${vid}`,
      method: 'POST',
      headers: {
        'xi-api-key': ELEVEN_API_KEY,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg'
      }
    };
    const chunks = [];
    const req = https.request(opts, r => {
      r.on('data', d => chunks.push(d));
      r.on('end', () => {
        const buf = Buffer.concat(chunks);
        resolve({ audio_base64: buf.toString('base64'), content_type: 'audio/mpeg' });
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }

  if (req.url === '/health') {
    res.writeHead(200, {'Content-Type':'application/json'});
    return res.end(JSON.stringify({status:'ok', port:PORT}));
  }

  if ((req.url === '/avatar/speak' || req.url === '/speak') && req.method === 'POST') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { text, lang, avatar_url, gender } = JSON.parse(body);
        const autoAvatar = gender==='female' ? DEFAULT_AVATAR_FEMALE : DEFAULT_AVATAR_MALE;
        const result = await createTalk(text, lang||'ko-KR', avatar_url||autoAvatar);
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify(result));
      } catch(e) {
        res.writeHead(500, {'Content-Type':'application/json'});
        res.end(JSON.stringify({error: e.message}));
      }
    });
    return;
  }

  if ((req.url.startsWith('/avatar/status/') || req.url.startsWith('/status/')) && req.method === 'GET') {
    const talkId = req.url.split('/').pop();
    didRequest('GET', `/talks/${talkId}`, null).then(result => {
      if(res.headersSent) return;
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify(result));
    }).catch(e => {
      if(res.headersSent) return;
      res.writeHead(500);
      res.end(JSON.stringify({error:e.message}));
    });
    return;
  }

  if (req.url === '/eleven/speak' && req.method === 'POST') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { text, voice_id, gender } = JSON.parse(body);
        const vid = voice_id || (gender==='female' ? ELEVEN_VOICE_FEMALE : ELEVEN_VOICE_MALE);
        const result = await elevenSpeak(text, vid);
        res.writeHead(200, {'Content-Type':'application/json'});
        res.end(JSON.stringify(result));
      } catch(e) {
        res.writeHead(500, {'Content-Type':'application/json'});
        res.end(JSON.stringify({error: e.message}));
      }
    });
    return;
  }

  res.writeHead(404); res.end();
});

server.listen(PORT, () => console.log(`[avatar-engine] 포트 ${PORT} 시작`));
