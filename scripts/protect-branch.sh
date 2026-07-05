#!/usr/bin/env bash
# One-time GitHub settings for a repo derived from this template - the parts
# that can't be templated as files:
#   - repository auto-merge + delete-branch-on-merge (auto-merge is what lets
#     renovate.json's platformAutomerge actually merge PRs)
#   - a ruleset on the target branch requiring PR approval and the given CI
#     status checks, with the repo owner (admin role) and the Renovate app
#     exempted as bypass actors on both
#
# Deletes every ruleset currently on the repo before creating this one, so
# the repo always ends up with exactly the state this script defines rather
# than accumulating stale rulesets from earlier runs or manual changes made
# in the GitHub UI.
#
# Requires: gh CLI, authenticated with admin rights on the target repo.
#
# Usage:
#   ./scripts/protect-branch.sh [branch] <required-check-contexts>
#
# required-check-contexts is a required, space-separated list of status check
# context names - there's no sane default since it varies per repo (whatever
# workflows/job ids a given consumer of this template has). Check names must
# match the job ids that report on a PR to the target branch, e.g. for this
# repo's own workflows that would be "pre-commit ci-terraform" (see CLAUDE.md
# on why ci-terraform, not test/plan directly, is the one to require).
#
# Env overrides:
#   REPO               owner/name (default: current repo via gh)
#   APPROVALS_REQUIRED number of required approving reviews (default: 1)

set -euo pipefail

BRANCH="${1:-main}"
REQUIRED_CHECKS="${2:-}"
APPROVALS_REQUIRED="${APPROVALS_REQUIRED:-1}"
RULESET_NAME="Protect ${BRANCH}"

command -v gh >/dev/null 2>&1 || { echo "gh CLI is required" >&2; exit 1; }

if [[ -z "${REQUIRED_CHECKS}" ]]; then
  echo "error: required-check-contexts is required (space-separated status check names)" >&2
  echo "usage: ./scripts/protect-branch.sh [branch] \"<check1> <check2> ...\"" >&2
  echo "       e.g. ./scripts/protect-branch.sh main \"pre-commit ci-terraform\"" >&2
  exit 1
fi

gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first" >&2; exit 1; }

REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

echo "Repo:    ${REPO}"
echo "Branch:  ${BRANCH}"
echo "Checks:  ${REQUIRED_CHECKS}"

echo "==> Enabling repository auto-merge and merged-branch cleanup"
gh api -X PATCH "repos/${REPO}" -f allow_auto_merge=true -F delete_branch_on_merge=true >/dev/null

read -ra REQUIRED_CHECKS_ARR <<<"${REQUIRED_CHECKS}"
REQUIRED_CHECKS_JSON="$(jq -nc '$ARGS.positional | map({context: .})' --args -- "${REQUIRED_CHECKS_ARR[@]}")"

echo "Looking up the Renovate GitHub App id..."
RENOVATE_APP_ID="$(gh api apps/renovate --jq .id)"
echo "Renovate app id: ${RENOVATE_APP_ID}"

# Built-in RepositoryRole ids used by the rulesets API (GitHub-defined, fixed):
# read=1 triage=2 write=3 maintain=4 admin=5
ADMIN_ROLE_ID=5

PAYLOAD="$(cat <<JSON
{
  "name": "${RULESET_NAME}",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/${BRANCH}"],
      "exclude": []
    }
  },
  "bypass_actors": [
    { "actor_id": ${RENOVATE_APP_ID}, "actor_type": "Integration", "bypass_mode": "always" },
    { "actor_id": ${ADMIN_ROLE_ID}, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": ${APPROVALS_REQUIRED},
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": ${REQUIRED_CHECKS_JSON},
        "strict_required_status_checks_policy": true
      }
    }
  ]
}
JSON
)"

echo "==> Clearing existing rulesets"
gh api "repos/${REPO}/rulesets" --jq '.[] | "\(.id) \(.name)"' | while read -r id name; do
  echo "    deleting '${name}' (id ${id})"
  gh api --method DELETE "repos/${REPO}/rulesets/${id}" >/dev/null
done

echo "==> Creating ruleset '${RULESET_NAME}'"
gh api --method POST "repos/${REPO}/rulesets" --input - <<<"${PAYLOAD}" >/dev/null

echo "Done. Verify at: https://github.com/${REPO}/settings/rules"
