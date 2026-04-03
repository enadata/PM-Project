#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$SCRIPT_DIR"
TARGET_DIR="${PWD}"
FORCE=false
DRY_RUN=false

usage() {
  cat <<'EOF'
用法:
  bash /path/to/PM-Project/bootstrap-pm-project.sh [target_dir] [--force] [--dry-run]

说明:
  在目标项目内创建指向 PM-Project 的软链接，使当前项目直接复用本仓库的 agents 和 skills。

参数:
  target_dir   目标项目目录，默认当前目录
  --force      遇到已存在文件时自动备份并覆盖
  --dry-run    仅打印将执行的操作，不落盘
  -h, --help   显示帮助
EOF
}

log() {
  printf '[pm-project] %s\n' "$1"
}

announce() {
  local action="$1"
  if [[ "$DRY_RUN" == true ]]; then
    log "将${action}"
  else
    log "已${action}"
  fi
}

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

ensure_dir() {
  run_cmd mkdir -p "$1"
}

assert_source_layout() {
  local required_paths=(
    "$SOURCE_ROOT/AGENTS.md"
    "$SOURCE_ROOT/.codex/agents"
    "$SOURCE_ROOT/.codex/config.toml"
    "$SOURCE_ROOT/.github/agents"
    "$SOURCE_ROOT/.github/skills"
  )

  local missing=0
  for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      log "缺少源路径: $path"
      missing=1
    fi
  done

  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi
}

backup_path() {
  local target_path="$1"
  local backup_root="$2"
  local relative_path="${target_path#$TARGET_DIR/}"
  local backup_path="$backup_root/$relative_path"

  ensure_dir "$(dirname "$backup_path")"
  run_cmd mv "$target_path" "$backup_path"
  announce "备份: $target_path -> $backup_path"
}

prepare_existing_path() {
  local target_path="$1"
  local expected_source="$2"
  local backup_root="$3"

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    return 0
  fi

  if [[ -L "$target_path" ]]; then
    local current_target
    current_target="$(readlink "$target_path")"
    if [[ "$current_target" == "$expected_source" ]]; then
      log "已存在正确软链接: $target_path"
      return 0
    fi
  fi

  if [[ "$FORCE" != true ]]; then
    log "目标已存在: $target_path"
    log "请使用 --force 允许脚本自动备份并覆盖。"
    exit 1
  fi

  backup_path "$target_path" "$backup_root"
}

link_path() {
  local source_path="$1"
  local target_path="$2"
  local backup_root="$3"

  prepare_existing_path "$target_path" "$source_path" "$backup_root"
  ensure_dir "$(dirname "$target_path")"
  run_cmd ln -s "$source_path" "$target_path"
  announce "创建软链接: $target_path -> $source_path"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        log "未知参数: $1"
        usage
        exit 1
        ;;
      *)
        TARGET_DIR="$1"
        shift
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  assert_source_layout

  if [[ ! -d "$TARGET_DIR" ]]; then
    log "目标目录不存在: $TARGET_DIR"
    exit 1
  fi

  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

  local backup_root="$TARGET_DIR/.pm-project-backup/$(date +%Y%m%d-%H%M%S)"

  log "源仓库: $SOURCE_ROOT"
  log "目标项目: $TARGET_DIR"

  link_path "$SOURCE_ROOT/AGENTS.md" "$TARGET_DIR/AGENTS.md" "$backup_root"
  link_path "$SOURCE_ROOT/.codex/agents" "$TARGET_DIR/.codex/agents" "$backup_root"
  link_path "$SOURCE_ROOT/.codex/config.toml" "$TARGET_DIR/.codex/config.toml" "$backup_root"
  link_path "$SOURCE_ROOT/.github/agents" "$TARGET_DIR/.github/agents" "$backup_root"
  link_path "$SOURCE_ROOT/.github/skills" "$TARGET_DIR/.github/skills" "$backup_root"

  prepare_existing_path "$TARGET_DIR/.agents/skills" "../.github/skills" "$backup_root"
  ensure_dir "$TARGET_DIR/.agents"
  run_cmd ln -s ../.github/skills "$TARGET_DIR/.agents/skills"
  announce "创建软链接: $TARGET_DIR/.agents/skills -> ../.github/skills"

  cat <<EOF

接入完成。

建议下一步：
1. 在目标项目目录确认软链接：
   ls -l "$TARGET_DIR/.codex" "$TARGET_DIR/.github" "$TARGET_DIR/.agents"
2. 按需配置环境变量：
   - MODAO_TOKEN
   - FEISHU_MCP_UAT / FEISHU_MCP_TAT
   - GITHUB_PERSONAL_ACCESS_TOKEN
   - TAVILY_API_KEY
3. 在目标项目中启动 Codex CLI / App，或在 VS Code 中重新打开项目。

如需预演执行过程，可运行：
  bash "$SOURCE_ROOT/bootstrap-pm-project.sh" "$TARGET_DIR" --dry-run
EOF
}

main "$@"
