module.exports = {
  apps: [
    {
      name: 'globe-gateway',
      script: './globe-gateway/server.js',
      cwd: '/home/boshin57/Tobmate_Live/gsos',
      env: {
        NODE_ENV: 'production',
        HOST: '127.0.0.1',
        PORT: 8110
      }
    },
    {
      name: 'spatial-registry',
      script: './spatial-registry/server.js',
      cwd: '/home/boshin57/Tobmate_Live/gsos',
      env: {
        NODE_ENV: 'production',
        HOST: '127.0.0.1',
        PORT: 8111,
        MONGODB_URL: 'mongodb://localhost:27017/tob',
        GSOS_DATABASE: 'tob',
        GSOS_SPACES_COLLECTION: 'gsos_spaces'
      }
    },
    {
      name: 'presence-hub',
      script: './presence-hub/server.js',
      cwd: '/home/boshin57/Tobmate_Live/gsos',
      env: {
        NODE_ENV: 'production',
        HOST: '127.0.0.1',
        PORT: 8112
      }
    },
    {
      name: 'agent-gateway',
      script: './agent-gateway/server.js',
      cwd: '/home/boshin57/Tobmate_Live/gsos',
      env: {
        NODE_ENV: 'production',
        HOST: '127.0.0.1',
        PORT: 8113
      }
    }
  ]
};
