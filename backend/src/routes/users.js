import {
  createUserSchema,
  listUsersSchema,
  getUserSchema,
  updateUserSchema,
  deleteUserSchema,
} from '../schemas/user.schema.js';

export default async function userRoutes(fastify) {
  // CREATE
  fastify.post('/', { schema: createUserSchema }, async (request, reply) => {
    const user = await fastify.prisma.user.create({ data: request.body });
    return reply.code(201).send(user);
  });

  // READ (list with pagination)
  fastify.get('/', { schema: listUsersSchema }, async (request) => {
    const { page, limit } = request.query;

    const [data, total] = await fastify.prisma.$transaction([
      fastify.prisma.user.findMany({
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { id: 'desc' },
      }),
      fastify.prisma.user.count(),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  });

  // READ (single)
  fastify.get('/:id', { schema: getUserSchema }, async (request, reply) => {
    const user = await fastify.prisma.user.findUnique({
      where: { id: request.params.id },
    });

    if (!user) {
      return reply.code(404).send({
        statusCode: 404,
        error: 'Not Found',
        message: `User ${request.params.id} not found`,
      });
    }
    return user;
  });

  // UPDATE (send only the fields you want to change)
  fastify.put('/:id', { schema: updateUserSchema }, async (request) => {
    return fastify.prisma.user.update({
      where: { id: request.params.id },
      data: request.body,
    });
  });

  // DELETE
  fastify.delete('/:id', { schema: deleteUserSchema }, async (request, reply) => {
    await fastify.prisma.user.delete({ where: { id: request.params.id } });
    return reply.code(204).send();
  });
}
