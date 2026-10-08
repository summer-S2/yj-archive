#!/usr/bin/env bash
# public 레포 공개 금지 정보 검사
#   --staged         스테이징된 변경 (pre-commit)
#   --msg <file>     커밋 메시지 (commit-msg)
#   --range <a> <b>  a..b 사이 모든 커밋의 메시지·변경 (pre-push, a가 0000…이면 b까지 전체)
#   --all            추적 중인 전체 파일 (수동 점검)
set -uo pipefail

git() { command git -c core.quotePath=false "$@"; }
SELF="scripts/check-public.sh"

ROOT=$(git rev-parse --show-toplevel)
LOCAL_PATTERNS="$ROOT/.public-guard-patterns"
URL_ALLOW="$ROOT/scripts/url-allowlist.txt"
ZERO=0000000000000000000000000000000000000000

if [[ ! -s "$LOCAL_PATTERNS" ]]; then
  echo "✖ $LOCAL_PATTERNS 가 없거나 비어 있음 — 회사 고유 금지어 목록을 먼저 작성해야 커밋·push 가능" >&2
  echo "  예시: scripts/public-guard-patterns.example" >&2
  exit 1
fi

# 공통 금지 패턴 (이름|정규식)
BUILTIN=(
  "로컬 절대경로|(^|[^A-Za-z0-9_.-])/(Users|home)/[A-Za-z0-9_.-]+/"
  "이슈·MR 번호|(^|[^&0-9A-Za-z])#[0-9]{2,5}([^0-9A-Fa-f]|$)|issues/[0-9]+|pull/[0-9]+|merge_requests/[0-9]+"
  "브랜치명|(^|[ \`'\"(])(feature|hotfix|bugfix|release|fix)/[#0-9A-Za-z][^ ]*"
  "번들 ID·패키지명|(^|[^A-Za-z0-9.])(com|io|kr|net|co)\.[a-z0-9_]+\.[a-z0-9_.]+"
  "스토어 앱 ID|(isi|appId|app_id|apple-itunes-app)[=:][ \"']*[0-9]{6,}|id[0-9]{9,10}"
  "Firebase 앱 ID|1:[0-9]{6,}:(android|ios|web):[0-9a-f]+"
  "기기 UDID|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|(^|[^0-9a-f])[0-9a-f]{40}([^0-9a-f]|$)"
  "IP 주소|(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)"
  "이메일|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z.]{2,}"
  "전화번호|01[016789][- ]?[0-9]{3,4}[- ]?[0-9]{4}"
  "주민번호|[0-9]{6}-[1-4]"
  "키·토큰|-----BEGIN|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|xox[abpr]-|AIza[0-9A-Za-z_-]{20,}"
  "계정·서명 정보|(store|key)Password|keyAlias|password[ ]*[:=][ ]*[^ <]|PIN[ ]*[:=][ ]*[0-9]"
)

fail=0
report() { echo "✖ [$1] $2" >&2; fail=1; }

scan() { # stdin: 검사할 텍스트, $1: 출처 라벨
  local text; text=$(sed 's/noreply@anthropic\.com//g')  # 커밋 공동 작성자 표기는 허용
  [[ -z "$text" ]] && return
  local entry name re hit
  for entry in "${BUILTIN[@]}"; do
    name=${entry%%|*}; re=${entry#*|}
    hit=$(grep -nE -- "$re" <<<"$text" | head -5)
    [[ -n "$hit" ]] && while IFS= read -r l; do report "$name" "$1: $l"; done <<<"$hit"
  done
  hit=$(grep -nEi -f <(grep -vE '^\s*(#|$)' "$LOCAL_PATTERNS") <<<"$text" | head -10)
  [[ -n "$hit" ]] && while IFS= read -r l; do report "회사 고유 금지어" "$1: $l"; done <<<"$hit"
  local url host
  while IFS= read -r url; do
    host=$(sed -E 's#https?://([^/:?]+).*#\1#' <<<"$url")
    grep -qxF "$host" "$URL_ALLOW" 2>/dev/null || report "허용되지 않은 URL" "$1: $url"
  done < <(grep -oE 'https?://[^] )"'"'"'>`<]+' <<<"$text" | sort -u)
}

check_binary() { # $1: 경로
  if [[ "${PUBLIC_GUARD_REVIEWED_BINARIES:-}" != "1" ]]; then
    report "바이너리(이미지 등) 미검토" "$1 — 내용을 직접 눈으로 확인한 뒤 PUBLIC_GUARD_REVIEWED_BINARIES=1 로 다시 실행"
  fi
}

scan_diff() { # $1: git diff 출력, $2: 라벨
  scan "$2" < <(printf '%s\n' "$1" | grep -E '^\+' | grep -vE '^\+\+\+ ' | sed 's/^+//')
}

case "${1:-}" in
  --staged)
    scan "파일명" < <(git diff --cached --name-only --diff-filter=ACMR)
    while IFS= read -r f; do
      [[ "$f" == "$SELF" ]] && continue
      if git diff --cached --numstat -- "$f" | grep -q '^-'; then check_binary "$f"
      else scan_diff "$(git diff --cached -U0 --no-color -- "$f")" "$f"; fi
    done < <(git diff --cached --name-only --diff-filter=ACMR)
    ;;
  --msg)
    scan "커밋 메시지" < <(grep -vE '^#' "$2")
    ;;
  --range)
    if [[ "$2" == "$ZERO" ]]; then commits=$(git rev-list "$3"); else commits=$(git rev-list "$2..$3"); fi
    for c in $commits; do
      short=${c:0:7}
      scan "커밋 $short 메시지" < <(git log -1 --format=%B "$c")
      scan "커밋 $short 파일명" < <(git diff-tree -r --root --no-commit-id --name-only --diff-filter=ACMR "$c")
      while IFS= read -r f; do
        [[ "$f" == "$SELF" ]] && continue
        if git diff-tree -r --root --numstat --no-commit-id "$c" -- "$f" | grep -q '^-'; then check_binary "$short:$f"
        else scan_diff "$(git diff-tree -r --root -p -U0 --no-color --no-commit-id "$c" -- "$f")" "커밋 $short $f"; fi
      done < <(git diff-tree -r --root --no-commit-id --name-only --diff-filter=ACMR "$c")
    done
    ;;
  --all)
    scan "파일명" < <(git ls-files)
    while IFS= read -r f; do
      [[ "$f" == "$SELF" ]] && continue
      if grep -qI . "$ROOT/$f" 2>/dev/null || [[ ! -s "$ROOT/$f" ]]; then scan "$f" < "$ROOT/$f"
      else check_binary "$f"; fi
    done < <(git ls-files)
    ;;
  *) echo "usage: $0 --staged | --msg <file> | --range <old> <new> | --all" >&2; exit 2 ;;
esac

if [[ $fail -ne 0 ]]; then
  echo "" >&2
  echo "공개 금지 정보가 발견되어 중단합니다. CLAUDE.md 'public 레포 규칙'에 따라 자리표시(<...>)로 바꾼 뒤 다시 시도하세요." >&2
  echo "검사를 건너뛰는 --no-verify 사용은 금지입니다." >&2
  exit 1
fi
echo "✔ public 검사 통과 (${1})"
