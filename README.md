# AWS deployment: Terraform + GitHub Actions

Monorepo layout (copy these folders next to your app code):

    backend/    Fastify + Prisma app
    frontend/   Angular app
    infra/      Terraform for the app (EC2, RDS, S3, CloudFront, Route 53)
    bootstrap/  Run once by hand: state bucket + GitHub OIDC roles
    .github/workflows/  infra.yml, backend.yml, frontend.yml

## One-time setup
1. `cd bootstrap && terraform init && terraform apply -var project=myapp -var github_org=ORG -var github_repo=REPO`
2. Put the state bucket name in `infra/backend.hcl`; edit `infra/prod.tfvars`.
3. GitHub: Settings > Environments > create `production` with a required reviewer.
4. GitHub: Settings > Variables > add AWS_REGION, TF_PLAN_ROLE_ARN, TF_APPLY_ROLE_ARN, DEPLOY_ROLE_ARN (from `terraform output`).
5. Push to `main`. infra.yml plans, waits for approval, applies.
6. Add ARTIFACT_BUCKET, FRONTEND_BUCKET, CLOUDFRONT_DISTRIBUTION_ID, API_INSTANCE_NAME (from the apply summary).
7. Re-run backend.yml and frontend.yml (Actions > Run workflow). Done.

## App requirements
- `prisma` in `dependencies`, migrations committed in `prisma/migrations`.
- `GET /health` returns 200.
- `npm run build` outputs `dist/server.js`.
- Read `PORT` and `CORS_ORIGIN` from the environment; use `trustProxy: true`.