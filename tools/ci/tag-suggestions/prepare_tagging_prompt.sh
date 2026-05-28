#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

TARGET_REPO_URL="${TARGET_REPO_URL:-https://github.com/espressif/developer-portal.git}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
REMOTE_ADDED=false
TEMP_DIR=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMP_ROOT="$SCRIPT_DIR/temp"
ARTICLES_LIST_FILE="$TEMP_ROOT/articles_list.txt"
PROMPT_TMPL_TXT="$SCRIPT_DIR/prompt-tmpl-tagging.txt"
TAGGING_GUIDELINES_URL="${TAGGING_GUIDELINES_URL:-https://raw.githubusercontent.com/espressif/developer-portal/refs/heads/main/content/pages/contribution-guide/tagging-content/index.md}"
TAGGING_SYSTEM_URL="${TAGGING_SYSTEM_URL:-https://developer.espressif.com/persist/maintenance/contribution/how-to-assign-tags.json}"

REQUIRED_TOOLS=(
    git
    curl
)


###############################################################################
# UTILITIES
###############################################################################

banner() {
  echo
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

check_required_tools() {
  local missing=()

  for tool in "${REQUIRED_TOOLS[@]}"; do
      if ! command -v "$tool" >/dev/null 2>&1; then
          missing+=("$tool")
      fi
  done

  if ((${#missing[@]} > 0)); then
      echo
      echo "ERROR: Missing required tools:" >&2
      for tool in "${missing[@]}"; do
          echo "  - $tool" >&2
      done
      return 1
  fi
  return 0
}


###############################################################################
# CLEANUP
###############################################################################

cleanup() {
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
  if [[ "$REMOTE_ADDED" = "true" ]]; then
    git remote remove target >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT


###############################################################################
# GIT + BASELINE
###############################################################################

ensure_target_remote() {
  if ! git remote get-url target >/dev/null 2>&1; then
    git remote add target "$TARGET_REPO_URL"
    REMOTE_ADDED=true
  fi
  git fetch target "$TARGET_BRANCH"
}

resolve_base_ref() {
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    echo "origin/${GITHUB_BASE_REF}"
  elif [[ -n "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}" ]]; then
    echo "target/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
  else
    echo "target/${TARGET_BRANCH}"
  fi
}


###############################################################################
# COLLECT ADDED ARTICLES
###############################################################################

collect_added_index_files() {
  local base_ref="$1"

  mkdir -p "$TEMP_ROOT"
  TEMP_DIR="$(mktemp -d "$TEMP_ROOT/prepare-tagging-prompt.XXXXXX")"

  git diff --name-only --diff-filter=A "$base_ref"...HEAD \
    | grep -E '^content/blog/.*/index\.md$' \
    > "$TEMP_DIR/index-added.txt" || true

  echo
  echo "List of added index files:"
  cat "$TEMP_DIR/index-added.txt" || true
}


###############################################################################
# CREATE PROMPT
###############################################################################

# Builds the tagging prompt from template + remote guidelines + article content.
# Usage: build_tagging_prompt <article_file> <output_file>
build_tagging_prompt() {
  local article_path="$1"
  local output_file="$2"
  local prompt guidelines system_md article_content

  prompt="$(cat "$PROMPT_TMPL_TXT")"
  guidelines="$(curl -sL "$TAGGING_GUIDELINES_URL")"
  prompt="${prompt//\{\{TAGGING_GUIDELINES_PATH\}\}/$guidelines}"
  system_md="$(curl -sL "$TAGGING_SYSTEM_URL" | \
    sed 's/.*"how_to_assign_tags": "//; s/"[[:space:]]*}.*//; s/\\n/\n/g; s/\\"/"/g')"
  prompt="${prompt//\{\{TAGGING_SYSTEM_PATH\}\}/$system_md}"
  article_content="$(sed '/^tags:/,/^[^[:space:]-]/ { /^tags:/d; /^[[:space:]]*-[[:space:]]/d; }' "$article_path")"
  prompt="${prompt//\{\{ARTICLE_PATH\}\}/$article_content}"

  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$prompt" > "$output_file"
}

_create_tagging_prompt_fail() {
  echo
  echo "No prompt generated (no added articles or error)." >&2
}

create_tagging_prompt() {
  if [[ ! -s "$TEMP_DIR/index-added.txt" ]]; then
    echo "No added index files; nothing to prepare." >&2
    _create_tagging_prompt_fail
    return 1
  fi

  if [[ ! -f "$PROMPT_TMPL_TXT" ]]; then
    echo "ERROR: prompt-tmpl-tagging.txt not found at $SCRIPT_DIR" >&2
    _create_tagging_prompt_fail
    return 1
  fi

  mkdir -p "$TEMP_ROOT"
  cp "$TEMP_DIR/index-added.txt" "$ARTICLES_LIST_FILE"

  local article_path article_full slug base output_prompt
  while IFS= read -r line || [[ -n "$line" ]]; do
    article_path="$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$article_path" ]] && continue
    article_full="$REPO_ROOT/$article_path"
    if [[ ! -f "$article_full" ]]; then
      echo "ERROR: Article not found: $article_path" >&2
      _create_tagging_prompt_fail
      return 1
    fi
    slug="$(basename "$(dirname "$article_path")")"
    base="$(basename "$article_path" .md)"
    output_prompt="$TEMP_ROOT/$slug/$base-prompt.txt"

    echo
    echo "Preparing prompt for article: $article_path -> $slug/$base-prompt.txt"
    build_tagging_prompt "$article_full" "$output_prompt"
    echo "Prompt written to $output_prompt"
  done < "$TEMP_DIR/index-added.txt"

  return 0
}


###############################################################################
# MAIN
###############################################################################

banner "Prepare tagging prompt"

check_required_tools || exit 1

cd "$REPO_ROOT"
ensure_target_remote
BASE_REF="$(resolve_base_ref)"

banner "Collecting added articles..."

collect_added_index_files "$BASE_REF"

banner "Creating prompt..."

create_tagging_prompt || exit 1

echo
echo "Done."
