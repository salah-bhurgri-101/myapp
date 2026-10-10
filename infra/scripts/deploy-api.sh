#!/bin/bash
# Usage: deploy-api <s3://bucket/key.tgz> <release-id>
# Runs as root on the server via SSM. Safe to re-run.
set -euo pipefail
export HOME=/root
export PATH=/usr/local/bin:/usr/bin:/bin

S3_URI="$1"
RELEASE="$2"

# shellcheck disable=SC1091
source /etc/app/config.env

RELEASES=/opt/app/releases
RELEASE_DIR="$RELEASES/$RELEASE"
PREVIOUS="$(readlink -f /opt/app/current || true)"

echo ">> Downloading $S3_URI"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
aws s3 cp "$S3_URI" /tmp/release.tgz --region "$AWS_REGION" --only-show-errors
tar -xzf /tmp/release.tgz -C "$RELEASE_DIR"
rm -f /tmp/release.tgz

echo ">> Writing environment"
DATABASE_URL="$(aws ssm get-parameter --name "$DB_URL_PARAM" --with-decryption \
  --query Parameter.Value --output text --region "$AWS_REGION")"
install -m 600 -o root -g root /dev/null /etc/app/app.env
cat > /etc/app/app.env <<EOF
DATABASE_URL=$DATABASE_URL
NODE_ENV=production
PORT=3000
CORS_ORIGIN=$CORS_ORIGIN
EOF

echo ">> Installing dependencies"
cd "$RELEASE_DIR"
npm ci --omit=dev --no-audit --no-fund --loglevel=error
if [ ! -x ./node_modules/.bin/prisma ]; then
  echo "!! prisma CLI missing. Move 'prisma' from devDependencies to dependencies in package.json."
  exit 1
fi
./node_modules/.bin/prisma generate

echo ">> Running database migrations"
set -a
# shellcheck disable=SC1091
source /etc/app/app.env
set +a
./node_modules/.bin/prisma migrate deploy

echo ">> Switching to release $RELEASE"
ln -sfn "$RELEASE_DIR" /opt/app/current
systemctl restart app-api

echo ">> Health check"
healthy=false
for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 2
done

if [ "$healthy" != true ]; then
  echo "!! Health check failed. Recent logs:"
  journalctl -u app-api -n 40 --no-pager || true
  if [ -n "$PREVIOUS" ] && [ -d "$PREVIOUS" ] && [ "$PREVIOUS" != "$RELEASE_DIR" ]; then
    echo "!! Rolling back code to $PREVIOUS (migrations are NOT rolled back)"
    ln -sfn "$PREVIOUS" /opt/app/current
    systemctl restart app-api
  fi
  exit 1
fi

# Keep the 3 newest releases
# shellcheck disable=SC2012
ls -1dt "$RELEASES"/* | tail -n +4 | xargs -r rm -rf

# First deploy only: issue the HTTPS certificate (DNS already points here via Terraform)
if [ ! -d "/etc/letsencrypt/live/$API_DOMAIN" ]; then
  echo ">> Requesting TLS certificate for $API_DOMAIN"
  certbot --nginx -d "$API_DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" --redirect
fi

echo ">> Deploy complete: $RELEASE"
