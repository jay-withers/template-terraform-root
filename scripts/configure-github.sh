#!/usr/bin/env bash
# Configures GitHub repository settings that can't be templated as files:
# auto-merge (so Renovate's automerge config in renovate.json actually takes
# effect) and branch protection on the default branch. Idempotent - safe to
# re-run any time (e.g. after renaming the repo or reinstalling Renovate).
#
# Requires: gh CLI, authenticated (`gh auth login`) as an account with admin
# rights on the target repository.
set -euo pipefail

RENOVATE_BOT_LOGIN="${RENOVATE_BOT_LOGIN:-renovate[bot]}"

command -v gh >/dev/null 2>&1 || {
  echo "error: gh CLI is required (https://cli.github.com)" >&2
  exit 1
}
gh auth status >/dev/null 2>&1 || {
  echo "error: not authenticated - run 'gh auth login' first" >&2
  exit 1
}

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Configuring $REPO"

echo "==> Enabling repository auto-merge and merged-branch cleanup"
gh api -X PATCH "repos/$REPO" -f allow_auto_merge=true -F delete_branch_on_merge=true >/dev/null

# GitHub bot users' avatar URLs embed their GitHub App ID as /in/<app_id>,
# which lets us find the Renovate app's ID without any special permissions
# (the /user/installations and /repos/{owner}/{repo}/installation endpoints
# both require GitHub App auth, which a `gh auth login` PAT doesn't have).
# Override RENOVATE_APP_ID directly if this ever stops working or you run a
# self-hosted Renovate under a different bot login.
if [ -z "${RENOVATE_APP_ID:-}" ]; then
  echo "==> Looking up ${RENOVATE_BOT_LOGIN}'s GitHub App ID"
  RENOVATE_APP_ID=$(gh api "users/${RENOVATE_BOT_LOGIN}" --jq '.avatar_url' 2>/dev/null \
    | grep -oE '/in/[0-9]+' | grep -oE '[0-9]+' || true)
fi

apply_ruleset() {
  local name="$1" payload_file="$2" existing_id
  existing_id=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name==\"$name\") | .id" 2>/dev/null || true)
  if [ -n "$existing_id" ]; then
    echo "==> Updating ruleset '$name' (#$existing_id)"
    gh api -X PUT "repos/$REPO/rulesets/$existing_id" --input "$payload_file" >/dev/null
  else
    echo "==> Creating ruleset '$name'"
    gh api -X POST "repos/$REPO/rulesets" --input "$payload_file" >/dev/null
  fi
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# Required status checks + basic history protection, enforced on everyone
# (including Renovate) - these gate on CI, not on human judgement, so there's
# no reason to bypass them. Context names must match the job ids in
# .github/workflows/ci-pre-commit.yml (pre-commit) and ci-terraform.yml (the
# ci-terraform gate job) - see README's "Branch protection" section.
jq -n '{
  name: "required-status-checks",
  target: "branch",
  enforcement: "active",
  conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
  rules: [
    { type: "deletion" },
    { type: "non_fast_forward" },
    {
      type: "required_status_checks",
      parameters: {
        strict_required_status_checks_policy: false,
        required_status_checks: [
          { context: "pre-commit" },
          { context: "ci-terraform" }
        ]
      }
    }
  ]
}' >"$WORKDIR/status-checks.json"
apply_ruleset "required-status-checks" "$WORKDIR/status-checks.json"

# Human review gate, with Renovate and repo admins exempted. Classic branch
# protection has no way to require reviews for humans while letting a bot
# self-merge (a bot can't approve its own PR either way), so this uses a
# separate ruleset with bypass actors instead of folding review into the
# ruleset above. The repo Admin role (built-in RepositoryRole actor_id 5)
# bypasses "always" so admins can merge without a second approver; Renovate
# bypasses only in the pull_request flow.
if [ -n "${RENOVATE_APP_ID:-}" ]; then
  jq -n --argjson app_id "$RENOVATE_APP_ID" '{
    name: "require-pull-request-review",
    target: "branch",
    enforcement: "active",
    bypass_actors: [
      { actor_id: $app_id, actor_type: "Integration", bypass_mode: "pull_request" },
      { actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always" }
    ],
    conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
    rules: [
      {
        type: "pull_request",
        parameters: {
          required_approving_review_count: 1,
          dismiss_stale_reviews_on_push: true,
          require_code_owner_review: false,
          require_last_push_approval: false,
          required_review_thread_resolution: false
        }
      }
    ]
  }' >"$WORKDIR/require-review.json"
  apply_ruleset "require-pull-request-review" "$WORKDIR/require-review.json"
else
  echo "warning: could not resolve ${RENOVATE_BOT_LOGIN}'s app ID - skipping the" >&2
  echo "         review-requirement ruleset. Install the Renovate GitHub App first," >&2
  echo "         then re-run, or set RENOVATE_APP_ID explicitly." >&2
fi

echo "Done."
