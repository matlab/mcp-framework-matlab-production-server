#!/usr/bin/env bash
set -euo pipefail

# Required env vars: GITLAB_TOKEN, GITLAB_HOST, GITLAB_PROJECT, COVERAGE_SOURCE
# Optional env vars: COVERAGE_PCT_FILE, COVERAGE_PCT_VALUE

GITLAB_TOKEN=$(echo "$GITLAB_TOKEN" | tr -d '[:space:]')

git clone "https://oauth2:${GITLAB_TOKEN}@${GITLAB_HOST}/${GITLAB_PROJECT}.git" gl-repo
mkdir -p "gl-repo/public"
rm -rf "gl-repo/public"/*
cp -r "${COVERAGE_SOURCE}"/* "gl-repo/public/"

if [[ -n "${COVERAGE_PCT_FILE:-}" && -n "${COVERAGE_PCT_VALUE:-}" ]]; then
    echo "${COVERAGE_PCT_VALUE}" > "gl-repo/public/${COVERAGE_PCT_FILE}"
fi

date -u '+%Y-%m-%d %H:%M UTC' > "gl-repo/public/.coverage-time"

cd gl-repo
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add -A
git diff --cached --quiet && echo "No changes to deploy" || (git commit -m "Update coverage report" && git push)
