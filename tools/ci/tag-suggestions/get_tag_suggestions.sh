#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMP_ROOT="$SCRIPT_DIR/temp"
ARTICLES_LIST_FILE="${ARTICLES_LIST_FILE:-$TEMP_ROOT/articles_list.txt}"
COMBINED_COMMENT_FILE="${COMBINED_COMMENT_FILE:-$TEMP_ROOT/comment_body.txt}"
COMMENT_TEMPLATE_FILE="$SCRIPT_DIR/pr-comment-tagging.md"
LLM_REQUEST_SCRIPT="$SCRIPT_DIR/llm_request.py"

REQUIRED_TOOLS=(
    jq
    python3
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
      echo "ERROR: Missing required tools:" >&2
      for tool in "${missing[@]}"; do
          echo "  - $tool" >&2
      done
      return 1
  fi
  return 0
}

check_required_env() {
  local missing=()
  for var in LLM_API_KEY LLM_MODEL LLM_BASE_URL; do
      if [[ -z "${!var:-}" ]]; then
          missing+=("$var")
      fi
  done
  if ((${#missing[@]} > 0)); then
      echo "ERROR: Missing required environment variables:" >&2
      for var in "${missing[@]}"; do
          echo "  - $var" >&2
      done
      return 1
  fi
  return 0
}


###############################################################################
# ASK LLM
###############################################################################

ask_llm() {
  local err
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "ERROR: Prompt file not found: $PROMPT_FILE" >&2
    echo "Run prepare_tagging_prompt.sh first." >&2
    return 1
  fi

  if [[ ! -f "$LLM_REQUEST_SCRIPT" ]]; then
    echo "ERROR: llm_request.py not found at $SCRIPT_DIR" >&2
    return 1
  fi

  mkdir -p "$(dirname "$RESPONSE_JSON_FILE")"
  err="$(python3 "$LLM_REQUEST_SCRIPT" \
    --llm-model "$LLM_MODEL" \
    --prompt "$PROMPT_FILE" \
    --response "$RESPONSE_JSON_FILE" 2>&1)" || {
    echo "Cannot get response from the LLM model." >&2
    echo "$err" >&2
    return 1
  }
  return 0
}


###############################################################################
# PARSE TAGS: "tag1, tag2, (tagA), (tagB)" -> tags + suggested_tags
###############################################################################

parse_tags_string() {
  local raw="$1"
  local tags=()
  local suggested=()
  local count=0
  local max_pieces=200

  # Delimiter is comma only. Each piece is one tag. Only "(...)" as the entire piece is a suggested tag.
  while IFS= read -r -d ',' piece; do
    ((count++)) || true
    [[ "$count" -gt "$max_pieces" ]] && break
    piece="$(echo "$piece" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$piece" ]] && continue

    if [[ "$piece" =~ ^\((.+)\)$ ]]; then
      # Entire piece is in parentheses -> suggested tag
      suggested+=("$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')")
    else
      # Anything else is one tag (e.g. "Cloud (power management)" stays one tag)
      tags+=("$piece")
    fi
  done < <(echo "$raw,")

  # Output: one tag per line, then blank line, then one suggested per line
  for t in "${tags[@]}"; do echo "$t"; done
  echo ""
  for s in "${suggested[@]}"; do echo "$s"; done
}


###############################################################################
# PREPARE COMMENT BODY
###############################################################################

prepare_comment() {
  # Extract first line only and limit length so parse_tags_string never sees huge input
  local first_line
  first_line="$(jq -r '
    .choices[0].message.content // .content.message // empty
  ' "$RESPONSE_JSON_FILE" 2>/dev/null | head -n 1 | cut -c1-2000)" || first_line=""
  if [[ -z "$first_line" ]]; then
    echo "ERROR: Could not extract content from LLM response." >&2
    return 1
  fi

  local tags_lines=()
  local suggested_lines=()
  local state="tags"
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      state="suggested"
    elif [[ "$state" == "tags" ]]; then
      tags_lines+=("$line")
    else
      suggested_lines+=("$line")
    fi
  done < <(parse_tags_string "$first_line")

  local comment
  comment="\`\`\`yaml"
  comment+=$'\n'"tags:"
  for t in "${tags_lines[@]}"; do
    [[ -n "$t" ]] && comment+=$'\n'"  - $t"
  done
  if (( ${#suggested_lines[@]} > 0 )); then
    comment+=$'\n\n'"suggested tags:"
    for t in "${suggested_lines[@]}"; do
      [[ -n "$t" ]] && comment+=$'\n'"  - $t"
    done
  fi
  comment+=$'\n'"\`\`\`"

  mkdir -p "$(dirname "$COMMENT_BODY_FILE")"
  echo "$comment" > "$COMMENT_BODY_FILE"
  echo "Comment body written to $COMMENT_BODY_FILE"
}


###############################################################################
# FALLBACK COMMENT (when LLM is unavailable)
###############################################################################

write_fallback_comment() {
  mkdir -p "$(dirname "$COMMENT_BODY_FILE")"
  {
    echo "> [!WARNING]"
    echo "> Suggesting tags is not available at the moment."
  } > "$COMMENT_BODY_FILE"
}


###############################################################################
# PROCESS ONE ARTICLE (sets PROMPT_FILE, RESPONSE_JSON_FILE, COMMENT_BODY_FILE)
###############################################################################

process_one_article() {
  local article_path="$1"
  local slug base
  slug="$(basename "$(dirname "$article_path")")"
  base="$(basename "$article_path" .md)"
  PROMPT_FILE="$TEMP_ROOT/$slug/$base-prompt.txt"
  RESPONSE_JSON_FILE="$TEMP_ROOT/$slug/$base-response.json"
  COMMENT_BODY_FILE="$TEMP_ROOT/$slug/$base-comment.txt"

  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "ERROR: Prompt file not found: $PROMPT_FILE (run prepare_tagging_prompt.sh first)" >&2
    return 1
  fi

  echo
  echo "Article: $article_path"
  if ! ask_llm; then
    write_fallback_comment "$article_path"
    return 0
  fi
  prepare_comment || return 1
  return 0
}


###############################################################################
# BUILD COMBINED COMMENT (article sections + template)
###############################################################################

build_combined_comment() {
  local article_sections_file="$TEMP_ROOT/comment_article_sections.txt"
  local article_path slug base

  : > "$article_sections_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    article_path="$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$article_path" ]] && continue
    process_one_article "$article_path" || return 1
    slug="$(basename "$(dirname "$article_path")")"
    base="$(basename "$article_path" .md)"
    echo "#### \`$article_path\`" >> "$article_sections_file"
    echo "" >> "$article_sections_file"
    cat "$TEMP_ROOT/$slug/$base-comment.txt" >> "$article_sections_file"
    echo "" >> "$article_sections_file"
  done < "$ARTICLES_LIST_FILE"

  mkdir -p "$(dirname "$COMBINED_COMMENT_FILE")"
  sed "/{{ARTICLE_SECTIONS}}/r $article_sections_file" "$COMMENT_TEMPLATE_FILE" | sed '/{{ARTICLE_SECTIONS}}/d' > "$COMBINED_COMMENT_FILE"
}


###############################################################################
# MAIN
###############################################################################

banner "Get tag suggestions"

check_required_tools || exit 1
check_required_env || exit 1

if [[ ! -f "$ARTICLES_LIST_FILE" || ! -s "$ARTICLES_LIST_FILE" ]]; then
  echo "ERROR: Articles list not found or empty: $ARTICLES_LIST_FILE" >&2
  echo "Run prepare_tagging_prompt.sh first (same as in CI: it uses git diff to find added articles)." >&2
  exit 1
fi

banner "Calling LLM..."

build_combined_comment || exit 1

echo
echo "Done. Combined comment body: $COMBINED_COMMENT_FILE"
