const userProperties = {
  name: { type: 'string', minLength: 1, maxLength: 191 },
  email: { type: 'string', format: 'email', maxLength: 191 },
  age: { type: ['integer', 'null'], minimum: 0, maximum: 150 },
};

const userResponse = {
  type: 'object',
  properties: {
    id: { type: 'integer' },
    name: { type: 'string' },
    email: { type: 'string' },
    age: { type: ['integer', 'null'] },
    createdAt: { type: 'string', format: 'date-time' },
    updatedAt: { type: 'string', format: 'date-time' },
  },
};

const idParams = {
  type: 'object',
  required: ['id'],
  properties: { id: { type: 'integer', minimum: 1 } },
};

export const createUserSchema = {
  body: {
    type: 'object',
    required: ['name', 'email'],
    additionalProperties: false,
    properties: userProperties,
  },
  response: { 201: userResponse },
};

export const listUsersSchema = {
  querystring: {
    type: 'object',
    properties: {
      page: { type: 'integer', minimum: 1, default: 1 },
      limit: { type: 'integer', minimum: 1, maximum: 100, default: 10 },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        data: { type: 'array', items: userResponse },
        meta: {
          type: 'object',
          properties: {
            page: { type: 'integer' },
            limit: { type: 'integer' },
            total: { type: 'integer' },
            totalPages: { type: 'integer' },
          },
        },
      },
    },
  },
};

export const getUserSchema = {
  params: idParams,
  response: { 200: userResponse },
};

export const updateUserSchema = {
  params: idParams,
  body: {
    type: 'object',
    additionalProperties: false,
    minProperties: 1,
    properties: userProperties,
  },
  response: { 200: userResponse },
};

export const deleteUserSchema = {
  params: idParams,
};
