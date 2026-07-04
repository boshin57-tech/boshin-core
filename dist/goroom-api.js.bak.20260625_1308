'use strict';
const http = require('http');
const { MongoClient, ObjectId } = require('mongodb');
const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/tob';
let db;
MongoClient.connect(mongoUrl, {useUnifiedTopology:true, useNewUrlParser:true}).then(c => {
  db = c.db('tob');
  console.log('[goroom-api] MongoDB 연결');
}).catch(e => console.error('[goroom-api] DB 연결 실패:', e.message));

http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.url.startsWith('/goroom-record/')) {
    try {
      const id = req.url.split('/goroom-record/')[1].split('?')[0];
      const game = await db.collection('gogames')
        .findOne({_id: new ObjectId(id)});
      if (!game) { res.writeHead(404); return res.end('{}'); }
      res.writeHead(200,{'Content-Type':'application/json'});
      res.end(JSON.stringify({
        move_history: game.move_history||[],
        boardSize: game.board_size||19,
        rule: game.rule||0,
        handicap: game.handicap||0,
        colors: game.colors||[1,2],
        komi: game.komi||6.5
      }));
    } catch(e){ res.writeHead(500); res.end(JSON.stringify({error:e.message})); }
  } else { res.writeHead(404); res.end(); }
}).listen(8020, () => console.log('[goroom-api] 포트 8020 시작'));
