# User Manager — Angular frontend

Angular app (standalone components, signals, reactive forms) for the Fastify + Prisma + MySQL User CRUD API.

## Run
```bash
npm install
npm start            # http://localhost:4200
```
The API must be running on `http://localhost:3000` (change it in `src/app/config.ts`).

## Features
- List users with pagination and page size
- Create / edit user with validation (name, email, optional age)
- Delete with confirmation
- Friendly errors (API down, duplicate email, not found)

## Scripts
`npm start` · `npm run build` · `npm test`
