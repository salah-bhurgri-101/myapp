import Fastify from 'fastify';
import prismaPlugin from './plugins/prisma.js';
import userRoutes from './routes/users.js';
import cors from '@fastify/cors';

export function buildApp(opts = {}) {
  const app = Fastify(opts);

  app.register(cors, {
  origin: (process.env.CORS_ORIGIN ?? 'http://localhost:4200').split(','),
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });
  app.register(prismaPlugin);
  app.register(userRoutes, { prefix: '/api/users' });
  

  app.get('/health', async () => ({ status: 'ok' }));

  // Map Prisma errors to proper HTTP responses
  app.setErrorHandler((error, request, reply) => {
    if (error.code === 'P2002') {
      return reply.code(409).send({
        statusCode: 409,
        error: 'Conflict',
        message: `Duplicate value for: ${error.meta?.target ?? 'unique field'}`,
      });
    }

    if (error.code === 'P2025') {
      return reply.code(404).send({
        statusCode: 404,
        error: 'Not Found',
        message: 'User not found',
      });
    }

    const statusCode = error.statusCode ?? 500;
    if (statusCode >= 500) request.log.error(error);

    return reply.code(statusCode).send({
      statusCode,
      error: statusCode >= 500 ? 'Internal Server Error' : error.name,
      message: statusCode >= 500 ? 'Something went wrong' : error.message,
    });
  });

  return app;
}
