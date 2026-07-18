'use strict';

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 8113);
const HOST = process.env.HOST || '127.0.0.1';

const app = express();
const agents = new Map();
const events = [];

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    service: 'Agent Gateway',
    status: 'online',
    registeredAgents: agents.size
  });
});

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    service: 'agent-gateway',
    registeredAgents: agents.size,
    timestamp: new Date().toISOString()
  });
});

app.get('/agents', (req, res) => {
  res.json(Array.from(agents.values()));
});

app.post('/agents/register', (req, res) => {
  const {
    name,
    type = 'ai',
    capabilities = [],
    endpoint = null,
    metadata = {}
  } = req.body || {};

  if (!name) {
    return res.status(400).json({
      ok: false,
      error: 'NAME_REQUIRED'
    });
  }

  const id = crypto.randomUUID();

  const agent = {
    id,
    name,
    type,
    capabilities,
    endpoint,
    metadata,
    status: 'online',
    registeredAt: new Date().toISOString()
  };

  agents.set(id, agent);

  res.status(201).json({
    ok: true,
    agent
  });
});

app.post('/agents/:id/events', (req, res) => {
  const agent = agents.get(req.params.id);

  if (!agent) {
    return res.status(404).json({
      ok: false,
      error: 'AGENT_NOT_FOUND'
    });
  }

  const event = {
    id: crypto.randomUUID(),
    agentId: agent.id,
    type: req.body?.type || 'generic',
    spaceId: req.body?.spaceId || null,
    payload: req.body?.payload || {},
    createdAt: new Date().toISOString()
  };

  events.push(event);

  if (events.length > 1000) {
    events.shift();
  }

  res.status(202).json({
    ok: true,
    event
  });
});

app.get('/events', (req, res) => {
  res.json(events);
});

app.listen(PORT, HOST, () => {
  console.log(`[Agent Gateway] http://${HOST}:${PORT}`);
});
