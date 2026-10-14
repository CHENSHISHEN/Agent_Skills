#!/usr/bin/env bash
# 初始化多LLM共享工作区（幂等保护：已存在 .agents 时拒绝执行）
# 用法: init.sh <目标目录> [agent1 agent2 ...]   # agent 名单缺省为 codex claude gemini
set -euo pipefail

TARGET="${1:-.}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$(cd "$TARGET" && pwd)"

AGENTS=("${@:2}")
if [ ${#AGENTS[@]} -eq 0 ]; then
  AGENTS=(codex claude gemini)
fi

if [ -e "$TARGET/.agents" ]; then
  echo "ERROR: $TARGET/.agents 已存在，拒绝覆盖。如确需重置，请先手动删除。" >&2
  exit 1
fi

mkdir -p "$TARGET/.agents/workspaces"
cp "$SKILL_DIR/assets/README.md"    "$TARGET/.agents/README.md"
cp "$SKILL_DIR/assets/decisions.md" "$TARGET/.agents/decisions.md"
cp "$SKILL_DIR/assets/archive.md"   "$TARGET/.agents/archive.md"

for a in "${AGENTS[@]}"; do
  ws="$TARGET/.agents/workspaces/$a"
  mkdir -p "$ws"
  cp "$SKILL_DIR/assets/plan.md"   "$ws/plan.md"
  cp "$SKILL_DIR/assets/output.md" "$ws/output.md"
  printf 'pending\n' > "$ws/status"
done

# 三个薄指针内容统一：角色由章程分配，不由入口文件决定
for f in CLAUDE.md AGENTS.md GEMINI.md; do
  if [ -e "$TARGET/$f" ]; then
    echo "SKIP: $TARGET/$f 已存在，未覆盖（请手动追加协作规则段落）"
  else
    cp "$SKILL_DIR/assets/POINTER.md" "$TARGET/$f"
  fi
done

echo "OK: 共享工作区已初始化于 $TARGET/.agents（agent: ${AGENTS[*]}）"
echo "后续: 将 .agents/README.md 中 '待定' 替换为实际项目名，并按需修改角色分工与规范"
