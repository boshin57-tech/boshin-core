import {
  registerBlockchainRoutes,
} from './blockchain-api.mjs';

const routes = [];

const mockApp = {
  get(path, handler) {
    routes.push({
      method: 'GET',
      path,
      handlerType: typeof handler,
    });
  },
};

registerBlockchainRoutes(mockApp);

console.log(
  JSON.stringify(
    {
      ok: true,
      routes,
    },
    null,
    2,
  ),
);
