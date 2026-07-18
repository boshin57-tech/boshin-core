'use strict';

const express = require('express');
const cors = require('cors');

const PORT = Number(process.env.PORT || 8110);
const HOST = process.env.HOST || '127.0.0.1';

const app = express();

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    service: 'Globe Gateway',
    status: 'online',
    port: PORT,
    version: '0.1.0'
  });
});

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'globe-gateway',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/gsos/services', async (req, res) => {
  res.json({
    globeGateway: 'http://127.0.0.1:8110',
    spatialRegistry: 'http://127.0.0.1:8111',
    presenceHub: 'http://127.0.0.1:8112',
    agentGateway: 'http://127.0.0.1:8113'
  });
});

app.listen(PORT, HOST, () => {
  console.log(`[Globe Gateway] http://${HOST}:${PORT}`);
});
