#!/usr/bin/env bash
set -euo pipefail

RELEASE_BRANCH="release"
DEV_BRANCH="dev"
RELEASE_WORKFLOW_FILE="release.yml"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not found in PATH."
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is required but not found in PATH."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Run this script inside a git repository."
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh is not authenticated. Run: gh auth login"
  exit 1
fi

REPO_SLUG="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [[ -z "$REPO_SLUG" ]]; then
  REPO_SLUG="$(git remote get-url origin | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

NON_INTERACTIVE=0
if [[ ! -t 0 || ! -t 1 ]]; then
  NON_INTERACTIVE=1
fi

trim() {
  local value="$*"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

confirm() {
  local prompt="$1"
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    echo "$prompt [auto-yes]"
    return 0
  fi
  local answer
  read -r -p "$prompt [y/N]: " answer
  case "${answer,,}" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

print_header() {
  echo
  echo "=============================================================="
  echo " Release Assistant"
  echo "=============================================================="
  echo "Repo:            ${REPO_SLUG:-unknown}"
  echo "Repo root:       $repo_root"
  echo "Current branch:  $(git rev-parse --abbrev-ref HEAD)"
}

print_status() {
  git fetch --all --tags --prune >/dev/null 2>&1 || true

  local latest_tag latest_tag_commit latest_tag_date
  latest_tag="$(git tag --sort=-v:refname | head -n 1 || true)"

  if [[ -n "$latest_tag" ]]; then
    latest_tag_commit="$(git rev-list -n 1 "$latest_tag" 2>/dev/null || true)"
    latest_tag_date="$(git log -1 --format=%ad --date=short "$latest_tag" 2>/dev/null || true)"
  else
    latest_tag_commit="-"
    latest_tag_date="-"
  fi

  local last_release_title="-"
  local last_release_tag="-"
  if gh release view --repo "$REPO_SLUG" >/dev/null 2>&1; then
    last_release_title="$(gh release view --repo "$REPO_SLUG" --json name --jq .name 2>/dev/null || echo -)"
    last_release_tag="$(gh release view --repo "$REPO_SLUG" --json tagName --jq .tagName 2>/dev/null || echo -)"
  fi

  local ahead_behind
  ahead_behind="$(git rev-list --left-right --count "origin/${RELEASE_BRANCH}...origin/${DEV_BRANCH}" 2>/dev/null || echo "? ?")"

  local release_sha dev_sha
  release_sha="$(git rev-parse --short "origin/${RELEASE_BRANCH}" 2>/dev/null || echo "?")"
  dev_sha="$(git rev-parse --short "origin/${DEV_BRANCH}" 2>/dev/null || echo "?")"

  local open_prs
  open_prs="$(gh pr list --repo "$REPO_SLUG" --base "$RELEASE_BRANCH" --head "$DEV_BRANCH" --state open --json number,title --jq 'length' 2>/dev/null || echo "?")"

  echo
  echo "--- Repo Status ---"
  echo "Latest git tag:              ${latest_tag:-<none>}"
  echo "Latest tag date:             $latest_tag_date"
  echo "Latest tag commit:           $latest_tag_commit"
  echo "Latest GitHub release tag:   $last_release_tag"
  echo "Latest GitHub release title: $last_release_title"
  echo "origin/${DEV_BRANCH} SHA:            $dev_sha"
  echo "origin/${RELEASE_BRANCH} SHA:        $release_sha"
  echo "release...dev counts:        $ahead_behind  (left=release-only, right=dev-only)"
  echo "Open PRs ${DEV_BRANCH}->${RELEASE_BRANCH}:    $open_prs"

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree:                DIRTY (commit/stash before release ops)"
  else
    echo "Working tree:                clean"
  fi
}

create_or_view_pr() {
  git fetch origin "$DEV_BRANCH" "$RELEASE_BRANCH" --tags --prune

  local existing_pr
  existing_pr="$(gh pr list --repo "$REPO_SLUG" --base "$RELEASE_BRANCH" --head "$DEV_BRANCH" --state open --json number,url,title --jq 'if length > 0 then .[0] | "#\(.number) \(.title) \(.url)" else "" end' 2>/dev/null || true)"

  if [[ -n "$(trim "$existing_pr")" ]]; then
    echo "Open PR already exists: $existing_pr"
    if [[ "$NON_INTERACTIVE" -eq 0 ]] && confirm "Open PR in browser?"; then
      gh pr view --repo "$REPO_SLUG" --base "$RELEASE_BRANCH" --head "$DEV_BRANCH" --web
    fi
    return
  fi

  local default_title="Release: merge ${DEV_BRANCH} into ${RELEASE_BRANCH}"
  local default_body
  default_body=$(cat <<EOF
Automated PR created by tools/release-assistant.sh

- Source: ${DEV_BRANCH}
- Target: ${RELEASE_BRANCH}
EOF
)

  local pr_title pr_body
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    pr_title="$default_title"
    pr_body="$default_body"
    echo "Using default PR title/body (non-interactive mode)."
  else
    read -r -p "PR title [$default_title]: " pr_title
    pr_title="$(trim "${pr_title:-$default_title}")"

    echo "PR body (single line; leave empty for default):"
    read -r pr_body
    pr_body="$(trim "${pr_body:-$default_body}")"
  fi

  gh pr create \
    --repo "$REPO_SLUG" \
    --base "$RELEASE_BRANCH" \
    --head "$DEV_BRANCH" \
    --title "$pr_title" \
    --body "$pr_body"

  echo "PR created."
}

merge_release_pr() {
  local pr_number
  pr_number="$(gh pr list --repo "$REPO_SLUG" --base "$RELEASE_BRANCH" --head "$DEV_BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || true)"

  if [[ -z "$(trim "$pr_number")" || "$pr_number" == "null" ]]; then
    echo "No open ${DEV_BRANCH}->${RELEASE_BRANCH} PR found."
    return
  fi

  echo "Found PR #$pr_number"
  local merge_flag="--merge"
  local execution_flag=""
  if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
    echo "Choose merge method:"
    echo "1) merge commit"
    echo "2) squash"
    echo "3) rebase"

    local method
    read -r -p "Method [1]: " method
    method="${method:-1}"

    case "$method" in
      1) merge_flag="--merge" ;;
      2) merge_flag="--squash" ;;
      3) merge_flag="--rebase" ;;
      *) echo "Invalid method."; return ;;
    esac

    echo "Choose merge execution mode:"
    echo "1) merge now (default)"
    echo "2) auto-merge when requirements pass (--auto)"
    echo "3) admin override now (--admin)"

    local exec_mode
    read -r -p "Execution mode [1]: " exec_mode
    exec_mode="${exec_mode:-1}"

    case "$exec_mode" in
      1) execution_flag="" ;;
      2) execution_flag="--auto" ;;
      3) execution_flag="--admin" ;;
      *) echo "Invalid execution mode."; return ;;
    esac
  else
    echo "Using merge commit (non-interactive mode)."
    execution_flag="--auto"
    echo "Using auto-merge mode (non-interactive mode)."
  fi

  if confirm "Attempt to merge PR #$pr_number now?"; then
    if gh pr merge "$pr_number" --repo "$REPO_SLUG" "$merge_flag" ${execution_flag:+$execution_flag}; then
      if [[ -n "$execution_flag" ]]; then
        echo "Merge command executed ($execution_flag)."
      else
        echo "Merge command executed."
      fi
    else
      echo "Merge failed with current mode."
      if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
        echo "Tip: if branch policy requires review/checks, retry and choose --auto or --admin."
      fi
      return
    fi
  fi
}

suggest_next_tag() {
  local latest
  latest="$(git tag --sort=-v:refname | head -n 1 || true)"
  if [[ -z "$latest" ]]; then
    echo "v0.1.0"
    return
  fi

  if [[ "$latest" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    local major minor patch
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    patch=$((patch + 1))
    echo "v${major}.${minor}.${patch}"
  else
    echo "$latest"
  fi
}

create_and_push_tag() {
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit/stash changes first."
    return
  fi

  git fetch origin "$RELEASE_BRANCH" --tags --prune

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"

  if [[ "$current_branch" != "$RELEASE_BRANCH" ]]; then
    if confirm "Checkout ${RELEASE_BRANCH} branch now?"; then
      git checkout "$RELEASE_BRANCH"
    else
      echo "Tagging aborted (must be on ${RELEASE_BRANCH})."
      return
    fi
  fi

  git pull --ff-only origin "$RELEASE_BRANCH"

  local suggested tag msg
  suggested="$(suggest_next_tag)"
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    tag="$suggested"
    echo "Using suggested tag: $tag"
  else
    read -r -p "Tag to create [$suggested]: " tag
    tag="$(trim "${tag:-$suggested}")"
  fi

  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Tag must match v<major>.<minor>.<patch> (example: v0.1.0)."
    return
  fi

  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "Tag $tag already exists locally."
    return
  fi

  if git ls-remote --tags origin "$tag" | grep -q "$tag"; then
    echo "Tag $tag already exists on origin."
    return
  fi

  local default_msg="Release $tag"
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    msg="$default_msg"
  else
    read -r -p "Tag message [$default_msg]: " msg
    msg="$(trim "${msg:-$default_msg}")"
  fi

  echo "About to run:"
  echo "  git tag -a $tag -m \"$msg\""
  echo "  git push origin $tag"

  if confirm "Proceed with tag creation and push?"; then
    git tag -a "$tag" -m "$msg"
    git push origin "$tag"
    echo "Tag pushed. This should trigger workflow: $RELEASE_WORKFLOW_FILE"

    if [[ "$NON_INTERACTIVE" -eq 1 ]] || confirm "Watch release workflow runs now?"; then
      gh run list --repo "$REPO_SLUG" --workflow "$RELEASE_WORKFLOW_FILE" --limit 10
      echo
      echo "Use: gh run watch --repo $REPO_SLUG <run-id>"
    fi

    if [[ "$NON_INTERACTIVE" -eq 0 ]] && confirm "Open Releases page in browser?"; then
      gh repo view --repo "$REPO_SLUG" --web
    fi
  fi
}

watch_release_workflow() {
  echo "Recent runs for $RELEASE_WORKFLOW_FILE:"
  gh run list --repo "$REPO_SLUG" --workflow "$RELEASE_WORKFLOW_FILE" --limit 10
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    return
  fi
  echo
  read -r -p "Run ID to watch (empty = skip): " run_id
  run_id="$(trim "$run_id")"
  if [[ -n "$run_id" ]]; then
    gh run watch --repo "$REPO_SLUG" "$run_id"
    if confirm "Open run in browser?"; then
      gh run view --repo "$REPO_SLUG" "$run_id" --web
    fi
  fi
}

sync_dev_from_release() {
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit/stash changes first."
    return
  fi

  git fetch origin "$DEV_BRANCH" "$RELEASE_BRANCH" --prune
  git checkout "$DEV_BRANCH"
  git pull --ff-only origin "$RELEASE_BRANCH"
  git push origin "$DEV_BRANCH"
  echo "${DEV_BRANCH} synced with origin/${RELEASE_BRANCH}."
}

run_full_flow() {
  print_status

  if confirm "Step 1/4: Create or view ${DEV_BRANCH}->${RELEASE_BRANCH} PR?"; then
    create_or_view_pr
  fi

  if confirm "Step 2/4: Merge open ${DEV_BRANCH}->${RELEASE_BRANCH} PR (if possible)?"; then
    merge_release_pr
  fi

  if confirm "Step 3/4: Create and push new release tag on ${RELEASE_BRANCH}?"; then
    create_and_push_tag
  fi

  if confirm "Step 4/4: Sync ${DEV_BRANCH} from ${RELEASE_BRANCH}?"; then
    sync_dev_from_release
  fi
}

run_full_flow_noninteractive() {
  echo
  echo "Running non-interactive full flow (no flags required)."
  print_status
  create_or_view_pr
  merge_release_pr
  create_and_push_tag
  sync_dev_from_release
}

main_menu() {
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    print_header
    run_full_flow_noninteractive
    return
  fi

  while true; do
    print_header
    print_status

    echo
    echo "Choose action:"
    echo "1) Run full flow (${DEV_BRANCH} -> ${RELEASE_BRANCH} -> tag -> sync)"
    echo "2) Create/view PR (${DEV_BRANCH} -> ${RELEASE_BRANCH})"
    echo "3) Merge open PR (${DEV_BRANCH} -> ${RELEASE_BRANCH})"
    echo "4) Create and push release tag"
    echo "5) Watch release workflow runs"
    echo "6) Sync ${DEV_BRANCH} from ${RELEASE_BRANCH}"
    echo "7) Refresh status"
    echo "0) Exit"

    local choice
    read -r -p "> " choice

    case "${choice:-}" in
      1) run_full_flow ;;
      2) create_or_view_pr ;;
      3) merge_release_pr ;;
      4) create_and_push_tag ;;
      5) watch_release_workflow ;;
      6) sync_dev_from_release ;;
      7) true ;;
      0) break ;;
      *) echo "Invalid selection." ;;
    esac

    echo
    read -r -p "Press Enter to continue..." _
  done
}

main_menu
