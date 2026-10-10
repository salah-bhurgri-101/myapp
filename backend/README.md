# Fastify + Prisma + MySQL — User CRUD

## Setup
```bash
npm install
cp .env.example .env            # edit DATABASE_URL if needed
docker compose up -d            # optional: starts MySQL 8.4
npx prisma migrate dev          # applies the init migration + generates client
npm run dev
```

## Endpoints
| Method | URL                      | Description              |
|--------|--------------------------|--------------------------|
| POST   | /api/users               | Create user              |
| GET    | /api/users?page=1&limit=10 | List users (paginated) |
| GET    | /api/users/:id           | Get one user             |
| PUT    | /api/users/:id           | Update (partial body OK) |
| DELETE | /api/users/:id           | Delete user              |
| GET    | /health                  | Health check             |

## Example
```bash
curl -X POST localhost:3000/api/users -H "Content-Type: application/json" \
  -d '{"name":"Ali","email":"ali@example.com","age":25}'
```

## Changing the schema later
Edit `prisma/schema.prisma`, then run `npx prisma migrate dev --name describe_change`.
In production use `npx prisma migrate deploy`.
