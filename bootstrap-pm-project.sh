#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${PWD}"
FORCE=false
DRY_RUN=false
SUBMODULE_PATH=".agent-project"
SUBMODULE_URL="https://github.com/enadata/PM-Project"
SUBMODULE_BRANCH="feature/codex-cli-adaptation"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/enadata/PM-Project/${SUBMODULE_BRANCH}/bootstrap-pm-project.sh"
BACKUP_DIR_NAME=".pm-project-backup"

usage() {
  cat <<EOF
用法:
  bash <(curl -fsSL $RAW_SCRIPT_URL) [target_dir] [--force] [--dry-run]

说明:
  在目标 Git 项目中，通过 git submodule add 接入 PM-Project 的
  feature/codex-cli-adaptation 分支到 .agent-project，并创建 agents/skills 相关软链接。

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

backup_path() {
  local target_path="$1"
  local backup_root="$2"
  local relative_path="${target_path#$TARGET_DIR/}"
  local destination="$backup_root/$relative_path"

  ensure_dir "$(dirname "$destination")"
  run_cmd mv "$target_path" "$destination"
  announce "备份: $target_path -> $destination"
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

assert_target_repo() {
  if ! git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "目标目录不是 Git 仓库: $TARGET_DIR"
    log "请先在目标项目执行 git init 或克隆已有仓库，然后重新运行本脚本。"
    exit 1
  fi
}

assert_clean_submodule_worktree() {
  local submodule_abs="$1"

  if [[ ! -d "$submodule_abs/.git" && ! -f "$submodule_abs/.git" ]]; then
    return 0
  fi

  if [[ -n "$(git -C "$submodule_abs" status --short)" ]]; then
    log "检测到 submodule 工作区存在未提交修改: $submodule_abs"
    log "请先在 submodule 内提交或暂存修改后再执行更新。"
    exit 1
  fi
}

ensure_submodule() {
  local backup_root="$1"
  local submodule_abs="$TARGET_DIR/$SUBMODULE_PATH"

  if [[ -e "$submodule_abs" || -L "$submodule_abs" ]]; then
    if git -C "$TARGET_DIR" config --file .gitmodules --get "submodule.$SUBMODULE_PATH.path" >/dev/null 2>&1; then
      assert_clean_submodule_worktree "$submodule_abs"
      run_cmd git -C "$TARGET_DIR" config -f .gitmodules "submodule.$SUBMODULE_PATH.url" "$SUBMODULE_URL"
      run_cmd git -C "$TARGET_DIR" config -f .gitmodules "submodule.$SUBMODULE_PATH.branch" "$SUBMODULE_BRANCH"
      run_cmd git -C "$TARGET_DIR" submodule sync "$SUBMODULE_PATH"
      run_cmd git -C "$TARGET_DIR" submodule update --init --remote "$SUBMODULE_PATH"
      announce "更新 submodule: $SUBMODULE_PATH"
      return 0
    fi

    if [[ "$FORCE" != true ]]; then
      log "目标路径已存在，但不是当前脚本受管的 Git submodule: $submodule_abs"
      log "请使用 --force 允许脚本自动备份并重新创建。"
      exit 1
    fi

    backup_path "$submodule_abs" "$backup_root"
  fi

  if ! run_cmd git -C "$TARGET_DIR" submodule add -b "$SUBMODULE_BRANCH" "$SUBMODULE_URL" "$SUBMODULE_PATH"; then
    log "submodule 添加失败，请检查网络连接和仓库 URL 是否正确。"
    exit 1
  fi
  announce "添加 submodule: $SUBMODULE_PATH -> $SUBMODULE_URL ($SUBMODULE_BRANCH)"
  run_cmd git -C "$TARGET_DIR" submodule update --init --remote "$SUBMODULE_PATH"
  announce "更新 submodule: $SUBMODULE_PATH"
}

assert_submodule_layout() {
  local source_root="$TARGET_DIR/$SUBMODULE_PATH"

  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi

  local required_paths=(
    "$source_root/AGENTS.md"
    "$source_root/.codex/agents"
    "$source_root/.codex/config.toml"
    "$source_root/.github/agents"
    "$source_root/.github/skills"
  )

  local missing=0
  for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      log "submodule 内缺少路径: $path"
      missing=1
    fi
  done

  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi
}

main() {
  parse_args "$@"

  if [[ ! -d "$TARGET_DIR" ]]; then
    log "目标目录不存在: $TARGET_DIR"
    exit 1
  fi

  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
  assert_target_repo

  local backup_root="$TARGET_DIR/$BACKUP_DIR_NAME/$(date +%Y%m%d-%H%M%S)"
  local source_root="$TARGET_DIR/$SUBMODULE_PATH"

  log "目标项目: $TARGET_DIR"
  log "submodule 仓库: $SUBMODULE_URL"
  log "submodule 分支: $SUBMODULE_BRANCH"

  ensure_submodule "$backup_root"
  assert_submodule_layout

  link_path "$source_root/AGENTS.md" "$TARGET_DIR/AGENTS.md" "$backup_root"
  link_path "$source_root/.codex/agents" "$TARGET_DIR/.codex/agents" "$backup_root"
  link_path "$source_root/.codex/config.toml" "$TARGET_DIR/.codex/config.toml" "$backup_root"
  link_path "$source_root/.github/agents" "$TARGET_DIR/.github/agents" "$backup_root"
  link_path "$source_root/.github/skills" "$TARGET_DIR/.github/skills" "$backup_root"
  link_path "../.github/skills" "$TARGET_DIR/.agents/skills" "$backup_root"

  cat <<EOF

接入完成。

本次接入方式：
- 已将 $SUBMODULE_URL 的 $SUBMODULE_BRANCH 分支添加为 submodule：$SUBMODULE_PATH
- Agents / Skills 相关入口已通过软链接指向 $SUBMODULE_PATH

建议下一步：
1. 查看 submodule 状态：
   cd "$TARGET_DIR" && git submodule status
2. 确认软链接：
   cd "$TARGET_DIR" && ls -l .codex .github .agents
3. 按需配置环境变量：
   - MODAO_TOKEN
   - FEISHU_MCP_UAT / FEISHU_MCP_TAT
   - GITHUB_PERSONAL_ACCESS_TOKEN
   - TAVILY_API_KEY

如需预演执行过程，可运行：
  bash <(curl -fsSL $RAW_SCRIPT_URL) "$TARGET_DIR" --dry-run
EOF
}

main "$@"
