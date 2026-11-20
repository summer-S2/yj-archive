#!/usr/bin/env python3
"""Claude Code 세션 기록(~/.claude/projects/*/*.jsonl)에서 특정 날짜의 작업 근거를 뽑는다.

사용법:
  python3 sessions.py list   <YYYY-MM-DD> [--tz 9]
  python3 sessions.py digest <jsonl 경로> <YYYY-MM-DD> [--tz 9] [--max 400]

list   : 그 날짜에 사용자 입력이 있었던 세션 목록 (경로, 작업 폴더, 시간대, 제목, 첫 입력)
digest : 한 세션의 그 날짜 분량 요약 (사용자 입력, 어시스턴트 답변, 수정 파일, git/gh 명령, PR 링크)
"""
import argparse
import glob
import json
import os
import sys
from datetime import datetime, timedelta, timezone

PROJECTS_DIR = os.path.expanduser("~/.claude/projects")
EXCLUDE_DIR_KEYWORDS = ("observer-sessions",)  # 메모리 플러그인 등 자동 세션은 사용자 작업이 아님
WRITE_TOOLS = ("Edit", "Write", "NotebookEdit", "MultiEdit")
CMD_KEYWORDS = ("git commit", "git push", "gh pr", "gh issue", "glab mr")


def local_date(ts, tz):
    t = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(tz)
    return t, t.strftime("%Y-%m-%d")


def read_records(path):
    with open(path, errors="ignore") as f:
        for line in f:
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def user_text(rec):
    """사람이 직접 입력한 텍스트만 반환. 도구 결과·메타·요약은 None."""
    if rec.get("type") != "user" or rec.get("isMeta") or rec.get("isCompactSummary") or rec.get("isSidechain"):
        return None
    c = rec.get("message", {}).get("content")
    if isinstance(c, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
            return None
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
    if not isinstance(c, str):
        return None
    c = c.strip()
    if not c or c.startswith(("<command-", "<local-command", "<system-reminder", "<task-notification")):
        return None
    return c


def session_files():
    for p in glob.glob(os.path.join(PROJECTS_DIR, "*", "*.jsonl")):
        if any(k in p for k in EXCLUDE_DIR_KEYWORDS):
            continue
        yield p


def cmd_list(date, tz):
    rows = []
    for p in session_files():
        times, prompts, cwd, title = [], [], None, None
        for r in read_records(p):
            if r.get("type") in ("custom-title", "ai-title"):
                title = r.get("customTitle") or r.get("aiTitle") or r.get("title") or title
            ts = r.get("timestamp")
            text = user_text(r)
            if not ts or text is None:
                continue
            t, d = local_date(ts, tz)
            if d != date:
                continue
            times.append(t)
            cwd = r.get("cwd") or cwd
            prompts.append(text)
        if times:
            rows.append((min(times), max(times), p, cwd, title, len(prompts), prompts[:3]))
    if not rows:
        print(f"{date}: 사용자 입력이 있는 세션 없음")
        return
    for start, end, p, cwd, title, n, first in sorted(rows):
        print(f"## {start:%H:%M}~{end:%H:%M}  입력 {n}건  cwd={cwd}")
        print(f"   file={p}")
        if title:
            print(f"   title={title}")
        for x in first:
            print(f"   > {x[:120].replace(chr(10), ' ')}")


def cmd_digest(path, date, tz, max_len):
    files, cmds, prs = [], [], set()
    for r in read_records(path):
        if r.get("type") == "pr-link":
            prs.add(json.dumps({k: v for k, v in r.items() if k not in ("type", "sessionId")}, ensure_ascii=False))
        ts = r.get("timestamp")
        if not ts or r.get("isSidechain"):
            continue
        t, d = local_date(ts, tz)
        if d != date:
            continue
        text = user_text(r)
        if text is not None:
            print(f"\n[{t:%H:%M}] USER: {text[:max_len]}")
            continue
        if r.get("type") != "assistant":
            continue
        for c in r.get("message", {}).get("content", []):
            if c.get("type") == "text" and c.get("text", "").strip():
                print(f"[{t:%H:%M}] CLAUDE: {c['text'].strip()[:max_len]}")
            elif c.get("type") == "tool_use":
                inp = c.get("input", {})
                if c.get("name") in WRITE_TOOLS and inp.get("file_path"):
                    files.append(inp["file_path"])
                cmd = inp.get("command", "")
                if isinstance(cmd, str) and any(k in cmd for k in CMD_KEYWORDS):
                    cmds.append(f"[{t:%H:%M}] {cmd[:200]}")
    print("\n=== 수정한 파일 ===")
    for f in sorted(set(files)):
        print(f"- {f}")
    print("\n=== git/gh 명령 ===")
    for c in cmds:
        print(f"- {c}")
    if prs:
        print("\n=== PR 링크 기록 ===")
        for x in prs:
            print(f"- {x}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("list")
    a.add_argument("date")
    a.add_argument("--tz", type=float, default=9)
    b = sub.add_parser("digest")
    b.add_argument("path")
    b.add_argument("date")
    b.add_argument("--tz", type=float, default=9)
    b.add_argument("--max", type=int, default=400, help="메시지별 최대 글자 수")
    args = ap.parse_args()
    tz = timezone(timedelta(hours=args.tz))
    try:
        datetime.strptime(args.date, "%Y-%m-%d")
    except ValueError:
        sys.exit(f"날짜 형식 오류: {args.date} (YYYY-MM-DD)")
    if args.cmd == "list":
        cmd_list(args.date, tz)
    else:
        if not os.path.isfile(args.path):
            sys.exit(f"파일 없음: {args.path}")
        cmd_digest(args.path, args.date, tz, args.max)


if __name__ == "__main__":
    main()
