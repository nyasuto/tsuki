#!/bin/bash
# ralph.sh — µCC (Tsuki) Ralph Loop Runner
# MoonBit + Claude Code による自律的イテレーション
#
# Usage:
#   ./ralph.sh              # 通常実行（無限ループ）
#   ./ralph.sh --once       # 1回だけ実行（デバッグ用）
#   ./ralph.sh --dry-run    # PROMPT.md の内容を表示して終了
#
# 前提:
#   - Claude Code がインストール済み（claude コマンドが使える）
#   - moonbit-practice プラグインがインストール済み
#   - MoonBit ツールチェーンがインストール済み（moon コマンドが使える）
#   - wasmtime がインストール済み（Wasm 実行検証用）

set -euo pipefail

# --- 設定 ---
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_FILE="${PROJECT_DIR}/prompt.md"
TASKS_FILE="${PROJECT_DIR}/tasks.md"
LOG_DIR="${PROJECT_DIR}/.ralph-logs"
COOLDOWN_SEC=3          # イテレーション間のクールダウン（秒）
MAX_ITERATIONS=50       # 安全弁：最大イテレーション回数（0 = 無制限）

# --- カラー出力 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 引数処理 ---
ONCE=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --once)    ONCE=true ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [--once] [--dry-run]"
            echo "  --once     1回だけ実行"
            echo "  --dry-run  PROMPT.md の内容を表示して終了"
            exit 0
            ;;
    esac
done

# --- 前提チェック ---
check_prerequisites() {
    local missing=()
    command -v claude  >/dev/null 2>&1 || missing+=("claude (Claude Code)")
    command -v moon    >/dev/null 2>&1 || missing+=("moon (MoonBit toolchain)")
    command -v wasmtime >/dev/null 2>&1 || missing+=("wasmtime (Wasm runtime)")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: 以下のコマンドが見つかりません:${NC}"
        for cmd in "${missing[@]}"; do
            echo "  - $cmd"
        done
        exit 1
    fi

    if [ ! -f "$PROMPT_FILE" ]; then
        echo -e "${RED}Error: ${PROMPT_FILE} が見つかりません${NC}"
        exit 1
    fi

    if [ ! -f "$TASKS_FILE" ]; then
        echo -e "${RED}Error: ${TASKS_FILE} が見つかりません${NC}"
        exit 1
    fi
}

# --- ログ設定 ---
setup_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/ralph_$(date +%Y%m%d_%H%M%S).log"
    echo -e "${BLUE}ログ出力先: ${LOG_FILE}${NC}"
}

# --- tasks.md の状態サマリ ---
show_task_summary() {
    echo -e "${BLUE}--- tasks.md 状態 ---${NC}"
    if grep -q "🔄\|IN_PROGRESS\|\[x\]" "$TASKS_FILE" 2>/dev/null; then
        grep -E "🔄|IN_PROGRESS|\- \[x\]|\- \[ \]" "$TASKS_FILE" | head -10
    else
        echo "(タスクマーカーなし — tasks.md を確認してください)"
    fi
    echo -e "${BLUE}--------------------${NC}"
}

# --- MoonBit プロジェクトの健全性チェック ---
pre_check() {
    echo -e "${YELLOW}[pre-check] moon check 実行中...${NC}"
    if moon check 2>&1; then
        echo -e "${GREEN}[pre-check] moon check OK${NC}"
        return 0
    else
        echo -e "${YELLOW}[pre-check] moon check にエラーあり（Claude Code が修正予定）${NC}"
        return 0  # エラーがあっても続行（Claude Code に修正させる）
    fi
}

# --- メインのイテレーション ---
run_iteration() {
    local iteration=$1
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} Ralph Loop — Iteration #${iteration}${NC}"
    echo -e "${GREEN} ${timestamp}${NC}"
    echo -e "${GREEN}========================================${NC}"

    show_task_summary

    # PROMPT.md の内容を Claude Code に渡す
    echo -e "${BLUE}[ralph] Claude Code 実行中...${NC}"

    local start_time
    start_time=$(date +%s)

    # Claude Code 実行
    # --print: 出力のみ（インタラクティブモードなし）
    # --output-format stream-json: リアルタイムストリーミング
    # --dangerously-skip-permissions: 自律実行を許可
    claude --print \
           --dangerously-skip-permissions \
           --output-format stream-json \
           "$(cat "$PROMPT_FILE")" \
           2>&1 | while IFS= read -r line; do
        # stream-json から result テキストを抽出して表示
        if echo "$line" | python3 -c "
import sys, json
try:
    obj = json.load(sys.stdin)
    if obj.get('type') == 'assistant' and 'content' in obj:
        for block in obj['content']:
            if block.get('type') == 'text':
                print(block['text'])
            elif block.get('type') == 'tool_use':
                print(f\"  [tool] {block.get('name', '?')}\")
    elif obj.get('type') == 'result':
        for block in obj.get('content', []):
            if block.get('type') == 'text':
                print(block['text'])
except: pass
" 2>/dev/null; then
            :
        fi
        echo "$line" >> "$LOG_FILE"
    done

    local exit_code=${PIPESTATUS[0]}
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}[ralph] Iteration #${iteration} 完了（${elapsed}秒, exit=${exit_code}）${NC}" | tee -a "$LOG_FILE"

    # git 状態を表示
    echo -e "${BLUE}--- git 状態 ---${NC}"
    git -C "$PROJECT_DIR" log --oneline -5 2>/dev/null || true
    local uncommitted
    uncommitted=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$uncommitted" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  未コミットの変更: ${uncommitted} ファイル${NC}"
        git -C "$PROJECT_DIR" status --short
    else
        echo -e "${GREEN}✓ 未コミットの変更なし${NC}"
    fi
    echo -e "${BLUE}----------------${NC}"

    # 完了チェック：tasks.md に ALL_DONE マーカーがあれば終了
    if grep -q "ALL_PHASES_COMPLETE\|🏁 ALL DONE" "$TASKS_FILE" 2>/dev/null; then
        echo -e "${GREEN}🎉 全フェーズ完了！ Ralph Loop を終了します。${NC}"
        return 1  # ループ終了シグナル
    fi

    return 0
}

# --- メイン ---
main() {
    check_prerequisites

    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}--- PROMPT.md の内容 ---${NC}"
        cat "$PROMPT_FILE"
        echo -e "${BLUE}--- ここまで ---${NC}"
        exit 0
    fi

    cd "$PROJECT_DIR"
    setup_logging

    echo -e "${GREEN}🌙 µCC (Tsuki) Ralph Loop 開始${NC}"
    echo -e "${BLUE}プロジェクト: ${PROJECT_DIR}${NC}"
    echo -e "${BLUE}MoonBit: $(moon version 2>/dev/null || echo 'unknown')${NC}"
    echo ""

    pre_check

    local iteration=0
    while true; do
        iteration=$((iteration + 1))

        # 安全弁
        if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
            echo -e "${RED}⚠️  最大イテレーション回数（${MAX_ITERATIONS}）に到達。停止します。${NC}"
            break
        fi

        # イテレーション実行
        if ! run_iteration "$iteration"; then
            break  # 全フェーズ完了
        fi

        # --once モード
        if [ "$ONCE" = true ]; then
            echo -e "${BLUE}[ralph] --once モードのため終了${NC}"
            break
        fi

        # クールダウン
        echo -e "${YELLOW}[ralph] ${COOLDOWN_SEC}秒待機...${NC}"
        sleep "$COOLDOWN_SEC"
    done

    echo ""
    echo -e "${GREEN}🌙 Ralph Loop 終了（計 ${iteration} イテレーション）${NC}"
    echo -e "${BLUE}ログ: ${LOG_FILE}${NC}"
}

main "$@"