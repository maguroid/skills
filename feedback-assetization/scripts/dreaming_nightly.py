#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# ///
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SESSION_LIMIT = 200 * 1024
HUB_LIMIT = 2 * 1024 * 1024
DIGEST_NOTE_RESERVE = 4 * 1024
POLL_INTERVAL_SECONDS = 30
MODEL_TIMEOUT_SECONDS = 45 * 60


@dataclass
class Hub:
    name: str
    path: Path
    scope_raw: str
    scope_path: Path | None
    is_default: bool


@dataclass
class RepoInfo:
    remote: str
    branch: str

    @property
    def base_ref(self) -> str:
        return f"{self.remote}/{self.branch}"


@dataclass
class Transcript:
    path: Path
    cwd: str | None
    session_id: str
    mtime: dt.datetime


@dataclass
class DigestStats:
    included_sessions: int = 0
    skipped_by_size: int = 0
    truncated_sessions: int = 0
    digest_bytes: int = 0
    candidate_sessions: int = 0
    missing_cwd: int = 0


@dataclass
class Digest:
    text: str
    stats: DigestStats


@dataclass
class HubRun:
    hub: Hub
    repo: RepoInfo
    window_start: dt.datetime
    window_end: dt.datetime
    transcripts: list[Transcript]
    digest: Digest


def log(message: str) -> None:
    print(f"[{dt.datetime.now().isoformat(timespec='seconds')}] {message}", flush=True)


def run(
    args: list[str],
    cwd: Path | None = None,
    *,
    check: bool = True,
    capture: bool = True,
) -> subprocess.CompletedProcess[str]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            check=False,
        )
    except FileNotFoundError as exc:
        executable = args[0] if args else "<empty command>"
        raise FileNotFoundError(f"executable not found while running {executable!r} in {cwd or Path.cwd()}") from exc
    if check and proc.returncode != 0:
        stderr = (proc.stderr or "").strip()
        stdout = (proc.stdout or "").strip()
        details = stderr or stdout or f"exit {proc.returncode}"
        raise RuntimeError(f"{' '.join(args)} failed in {cwd or Path.cwd()}: {details}")
    return proc


def resolve_requested_hub(hubs: list[Hub], requested: str) -> list[Hub]:
    exact = [hub for hub in hubs if hub.name == requested]
    if exact:
        return exact

    prefix_matches = [
        hub for hub in hubs
        if hub.name.startswith(requested)
        and len(hub.name) > len(requested)
        and hub.name[len(requested)] in {"（", "("}
    ]
    if len(prefix_matches) == 1:
        return prefix_matches
    if prefix_matches:
        names = ", ".join(hub.name for hub in prefix_matches)
        raise SystemExit(f"hub name is ambiguous: {requested} matches {names}")
    raise SystemExit(f"hub not found: {requested}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Mine Claude Code transcripts into dreaming branches.")
    parser.add_argument("--hub", help="Run only the named hub from ~/.agents/hubs.md")
    parser.add_argument(
        "--window-hours",
        type=float,
        help="Ignore markers and mine the last N hours.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print routing and digest statistics without creating branches, tmux sessions, or pushes.",
    )
    return parser.parse_args(argv)


def parse_hubs(path: Path) -> list[Hub]:
    if not path.exists():
        raise FileNotFoundError(f"hub registry not found: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()
    in_hubs = False
    current_name: str | None = None
    current_lines: list[str] = []
    sections: list[tuple[str, list[str]]] = []

    for line in lines:
        if line.startswith("## "):
            if in_hubs and current_name:
                sections.append((current_name, current_lines))
            in_hubs = line.strip() == "## ハブ一覧"
            current_name = None
            current_lines = []
            continue
        if not in_hubs:
            continue
        if line.startswith("### "):
            if current_name:
                sections.append((current_name, current_lines))
            current_name = line[4:].strip()
            current_lines = []
            continue
        if current_name:
            current_lines.append(line)

    if in_hubs and current_name:
        sections.append((current_name, current_lines))

    hubs: list[Hub] = []
    default_count = 0
    for name, body in sections:
        hub_path: Path | None = None
        scope_raw: str | None = None
        for line in body:
            stripped = line.strip()
            if stripped.startswith("- パス:"):
                hub_path = parse_backtick_path(stripped.split(":", 1)[1].strip())
            elif stripped.startswith("- 作業フォルダスコープ:"):
                scope_raw = stripped.split(":", 1)[1].strip()
        if hub_path is None or scope_raw is None:
            continue

        is_default = scope_raw.startswith("既定ハブ")
        scope_path = None if is_default else parse_backtick_path(scope_raw)
        if not is_default and scope_path is None:
            log(f"skip hub {name}: unsupported scope declaration: {scope_raw}")
            continue
        if is_default:
            default_count += 1
        hubs.append(
            Hub(
                name=name,
                path=hub_path.expanduser(),
                scope_raw=scope_raw,
                scope_path=scope_path.expanduser() if scope_path else None,
                is_default=is_default,
            )
        )

    if default_count != 1:
        raise ValueError(f"expected exactly one default hub, found {default_count}")
    return hubs


def parse_backtick_path(value: str) -> Path | None:
    match = re.search(r"`([^`]+)`", value)
    if match:
        return Path(match.group(1))
    if value.startswith("~") or value.startswith("/"):
        return Path(value.split()[0])
    return None


def resolve_repo_info(hub: Hub) -> RepoInfo:
    if hub.path.name == "Workspace-Me":
        return RepoInfo(remote="github", branch="workspace")

    remotes = run(["git", "remote"], cwd=hub.path).stdout.splitlines()
    for remote in ("github", "origin"):
        if remote not in remotes:
            continue
        proc = run(
            ["git", "symbolic-ref", "--short", f"refs/remotes/{remote}/HEAD"],
            cwd=hub.path,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            short = proc.stdout.strip()
            prefix = f"{remote}/"
            if short.startswith(prefix):
                return RepoInfo(remote=remote, branch=short[len(prefix) :])
        for fallback in ("main", "master", "workspace"):
            if remote_ref_exists(hub.path, remote, fallback):
                return RepoInfo(remote=remote, branch=fallback)
    raise RuntimeError(f"cannot resolve remote/main branch for hub {hub.name}: {hub.path}")


def remote_ref_exists(repo: Path, remote: str, branch: str) -> bool:
    proc = run(
        ["git", "rev-parse", "--verify", "--quiet", f"refs/remotes/{remote}/{branch}"],
        cwd=repo,
        check=False,
    )
    return proc.returncode == 0


def read_marker(repo: Path, base_ref: str, now: dt.datetime, window_hours: float | None) -> dt.datetime:
    if window_hours is not None:
        return now - dt.timedelta(hours=window_hours)

    proc = run(
        ["git", "show", f"{base_ref}:agent-memory/.dreaming/marker"],
        cwd=repo,
        check=False,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return now - dt.timedelta(hours=48)
    try:
        return parse_iso_datetime(proc.stdout.strip().splitlines()[0])
    except ValueError:
        log(f"invalid marker in {repo} at {base_ref}; falling back to 48 hours")
        return now - dt.timedelta(hours=48)


def parse_iso_datetime(value: str) -> dt.datetime:
    if value.endswith("Z"):
        value = f"{value[:-1]}+00:00"
    parsed = dt.datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.datetime.now().astimezone().tzinfo)
    return parsed.astimezone()


def list_transcripts(root: Path) -> tuple[list[Transcript], int]:
    transcripts: list[Transcript] = []
    missing_cwd = 0
    for path in sorted(root.glob("*/*.jsonl")):
        cwd = read_cwd_from_head(path)
        if not cwd:
            missing_cwd += 1
            log(f"skip transcript without cwd: {path}")
            continue
        stat = path.stat()
        transcripts.append(
            Transcript(
                path=path,
                cwd=cwd,
                session_id=path.stem,
                mtime=dt.datetime.fromtimestamp(stat.st_mtime).astimezone(),
            )
        )
    return transcripts, missing_cwd


def read_cwd_from_head(path: Path, max_lines: int = 30) -> str | None:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for index, line in enumerate(handle):
                if index >= max_lines:
                    break
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                cwd = find_key(obj, "cwd")
                if isinstance(cwd, str) and cwd:
                    return cwd
    except OSError as exc:
        log(f"cannot read {path}: {exc}")
    return None


def find_key(value: object, key: str) -> object | None:
    if isinstance(value, dict):
        if key in value:
            return value[key]
        for child in value.values():
            found = find_key(child, key)
            if found is not None:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_key(child, key)
            if found is not None:
                return found
    return None


def route_transcripts(hubs: list[Hub], transcripts: Iterable[Transcript]) -> dict[str, list[Transcript]]:
    default_hub = next(hub for hub in hubs if hub.is_default)
    scoped_hubs = [hub for hub in hubs if not hub.is_default and hub.scope_path is not None]
    routed = {hub.name: [] for hub in hubs}
    dreaming_root = Path.home() / ".cache" / "dreaming" / "worktrees"

    for transcript in transcripts:
        cwd = expand_cwd(transcript.cwd)
        if cwd and path_has_prefix(cwd, dreaming_root):
            continue
        hub = None
        for candidate in scoped_hubs:
            if cwd and path_has_prefix(cwd, candidate.scope_path):
                hub = candidate
                break
        if hub is None:
            hub = default_hub
        routed[hub.name].append(transcript)
    return routed


def expand_cwd(value: str | None) -> Path | None:
    if not value:
        return None
    return Path(value).expanduser()


def path_has_prefix(path: Path, prefix: Path | None) -> bool:
    if prefix is None:
        return False
    path_s = str(path)
    prefix_s = str(prefix)
    return path_s == prefix_s or path_s.startswith(prefix_s.rstrip("/") + "/")


def build_hub_run(
    hub: Hub,
    repo: RepoInfo,
    routed: list[Transcript],
    window_start: dt.datetime,
    window_end: dt.datetime,
) -> HubRun:
    in_window = [
        transcript
        for transcript in routed
        if window_start <= transcript.mtime <= window_end
    ]
    in_window.sort(key=lambda item: item.mtime, reverse=True)
    digest = build_digest(in_window)
    return HubRun(
        hub=hub,
        repo=repo,
        window_start=window_start,
        window_end=window_end,
        transcripts=in_window,
        digest=digest,
    )


def build_digest(transcripts: list[Transcript]) -> Digest:
    stats = DigestStats(candidate_sessions=len(transcripts))
    chunks: list[str] = []
    total = 0
    content_limit = HUB_LIMIT - DIGEST_NOTE_RESERVE

    for index, transcript in enumerate(transcripts):
        text = render_session(transcript)
        encoded = text.encode("utf-8")
        if len(encoded) > SESSION_LIMIT:
            note = "\n\n[truncated: session exceeded 200KB]\n"
            text = truncate_utf8(text, SESSION_LIMIT - len(note.encode("utf-8"))) + note
            stats.truncated_sessions += 1
            encoded = text.encode("utf-8")
        if total + len(encoded) > content_limit:
            stats.skipped_by_size += len(transcripts) - index
            break
        chunks.append(text)
        total += len(encoded)
        stats.included_sessions += 1

    notes: list[str] = []
    if stats.truncated_sessions:
        notes.append(f"- {stats.truncated_sessions} session(s) were truncated at 200KB.")
    if stats.skipped_by_size:
        notes.append(f"- {stats.skipped_by_size} newer-to-older session(s) were omitted after the 2MB hub limit.")
    prefix = ""
    if notes:
        prefix = "# digest notes\n" + "\n".join(notes) + "\n\n"
    text = prefix + "\n\n".join(chunks)
    stats.digest_bytes = len(text.encode("utf-8"))
    return Digest(text=text, stats=stats)


def truncate_utf8(text: str, max_bytes: int) -> str:
    return text.encode("utf-8")[:max_bytes].decode("utf-8", errors="ignore")


def render_session(transcript: Transcript) -> str:
    turns: list[str] = []
    started_at: str | None = None
    discovered_session_id: str | None = None
    try:
        with transcript.path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if started_at is None:
                    timestamp = find_key(obj, "timestamp")
                    if isinstance(timestamp, str):
                        started_at = timestamp
                if discovered_session_id is None:
                    session_id = find_key(obj, "sessionId") or find_key(obj, "session_id")
                    if isinstance(session_id, str):
                        discovered_session_id = session_id
                role = message_role(obj)
                if role not in {"user", "assistant"}:
                    continue
                content = message_content(obj)
                text = "\n\n".join(extract_text_blocks(content)).strip()
                if not text:
                    continue
                turns.append(f"### {role}\n{text}")
    except OSError as exc:
        turns.append(f"[unreadable transcript: {exc}]")

    session_id = discovered_session_id or transcript.session_id
    start = started_at or transcript.mtime.isoformat(timespec="seconds")
    header = f"## session {session_id} ({transcript.cwd}, {start})"
    return header + "\n\n" + "\n\n".join(turns)


def message_role(obj: dict[str, object]) -> str | None:
    message = obj.get("message")
    if isinstance(message, dict) and isinstance(message.get("role"), str):
        return str(message["role"])
    if isinstance(obj.get("role"), str):
        return str(obj["role"])
    if isinstance(obj.get("type"), str) and obj["type"] in {"user", "assistant"}:
        return str(obj["type"])
    return None


def message_content(obj: dict[str, object]) -> object:
    message = obj.get("message")
    if isinstance(message, dict) and "content" in message:
        return message["content"]
    return obj.get("content")


def extract_text_blocks(content: object) -> list[str]:
    if isinstance(content, str):
        return [content]
    if isinstance(content, list):
        texts: list[str] = []
        for item in content:
            if not isinstance(item, dict):
                continue
            item_type = item.get("type")
            if item_type == "text" and isinstance(item.get("text"), str):
                texts.append(str(item["text"]))
        return texts
    if isinstance(content, dict):
        if content.get("type") == "text" and isinstance(content.get("text"), str):
            return [str(content["text"])]
    return []


def fetch_repo(repo: Path, remote: str) -> None:
    log(f"fetch {repo} {remote}")
    run(["git", "fetch", remote, "--prune"], cwd=repo, capture=False)


def supersede_dreaming_branches(repo: Path, repo_info: RepoInfo) -> None:
    remote_prefix = f"{repo_info.remote}/"
    remote_refs = run(
        ["git", "branch", "-r", "--list", f"{repo_info.remote}/dreaming/*"],
        cwd=repo,
    ).stdout.splitlines()
    for ref in remote_refs:
        ref = ref.strip()
        if not ref or " -> " in ref:
            continue
        branch = ref[len(remote_prefix) :] if ref.startswith(remote_prefix) else ref
        close_pr(repo, branch)
        log(f"delete remote branch {repo_info.remote}/{branch}")
        run(["git", "push", repo_info.remote, "--delete", branch], cwd=repo, check=False)

    local_refs = run(
        ["git", "branch", "--format=%(refname:short)", "--list", "dreaming/*"],
        cwd=repo,
    ).stdout.splitlines()
    for branch in local_refs:
        branch = branch.strip()
        if not branch:
            continue
        log(f"delete local branch {branch}")
        run(["git", "branch", "-D", branch], cwd=repo, check=False)


def close_pr(repo: Path, branch: str) -> None:
    if shutil.which("gh") is None:
        return
    run(
        ["gh", "pr", "close", branch, "--comment", "Superseded by the next dreaming nightly run."],
        cwd=repo,
        check=False,
    )


def prepare_worktree(hub: Hub, repo_info: RepoInfo, branch: str) -> Path:
    worktree = worktree_path(hub)
    run(["git", "worktree", "prune"], cwd=hub.path, check=False)
    if worktree.exists():
        run(["git", "worktree", "remove", "--force", str(worktree)], cwd=hub.path, check=False)
        if worktree.exists():
            shutil.rmtree(worktree)
    worktree.parent.mkdir(parents=True, exist_ok=True)
    log(f"create worktree {worktree} at {branch}")
    run(
        ["git", "worktree", "add", "-B", branch, str(worktree), repo_info.base_ref],
        cwd=hub.path,
        capture=False,
    )
    return worktree


def worktree_path(hub: Hub) -> Path:
    return Path.home() / ".cache" / "dreaming" / "worktrees" / slugify(hub.name)


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-")
    return slug or "hub"


def write_dreaming_inputs(worktree: Path, digest: Digest) -> None:
    dreaming_dir = worktree / "agent-memory" / ".dreaming"
    digest_dir = dreaming_dir / "digest"
    digest_dir.mkdir(parents=True, exist_ok=True)
    report = dreaming_dir / "report.md"
    if report.exists():
        report.unlink()
    (digest_dir / "digest.txt").write_text(digest.text, encoding="utf-8")
    (dreaming_dir / "prompt.md").write_text(build_prompt(), encoding="utf-8")


def build_prompt() -> str:
    return """# dreaming candidate generation

Read `agent-memory/.dreaming/digest/digest.txt`, `agent-memory/MEMORY.md`, and the existing memory
files under `agent-memory/`. Generate only new candidates that are not already recorded in memory,
briefs, rules, or skills.

Mining criteria:

1. User corrections or comments that changed judgment, especially before/after decisions.
2. Questions, mistakes, or workarounds repeated across multiple sessions.
3. Workflows that appear to be converging into a repeatable pattern.

Do not capture one-off debugging history or details that only matter to a single project. Existing
knowledge is an exclusion criterion: write only the missing delta.

Output rules:

- One candidate is one file named `agent-memory/dreaming-<kebab-slug>.md`.
- Each candidate file must have frontmatter with `name`, `description`, `metadata.type`,
  `metadata.n`, and `metadata.sources`.
- The body must summarize the evidence and recommend the level: memory, L0, L1, L2, or rule.
- It is acceptable to output n=1 candidates, but `metadata.n` must make that explicit.
- Write candidate file contents in Japanese (the hubs' documentation language).
- Do not edit `agent-memory/MEMORY.md`; humans will update the index during review.
- Do not use shell or Bash. Use only Read and Write.
- When finished, write `agent-memory/.dreaming/report.md` with the candidate count and a concise
  summary of the generated candidates. If there are no candidates, write a report saying so.
"""


def run_model(worktree: Path, hub: Hub) -> bool:
    session = f"dreaming-{slugify(hub.name)}"
    report = worktree / "agent-memory" / ".dreaming" / "report.md"
    prompt_arg = "agent-memory/.dreaming/prompt.md を読んでその指示に従え"
    command = " ".join(
        shell_quote(part)
        for part in [
            "claude",
            "--model",
            "sonnet",
            "--permission-mode",
            "acceptEdits",
            "--disallowedTools",
            "Bash",
            prompt_arg,
        ]
    )
    run(["tmux", "kill-session", "-t", session], check=False)
    log(f"start tmux session {session}")
    run(["tmux", "new-session", "-d", "-s", session, "-c", str(worktree), command])

    deadline = time.monotonic() + MODEL_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        if report.exists():
            run(["tmux", "kill-session", "-t", session], check=False)
            return True
        time.sleep(POLL_INTERVAL_SECONDS)

    log(f"timeout waiting for report.md for {hub.name}")
    run(["tmux", "kill-session", "-t", session], check=False)
    return False


def shell_quote(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_./:=+-]+", value):
        return value
    return "'" + value.replace("'", "'\"'\"'") + "'"


def commit_and_push(worktree: Path, hub_run: HubRun, branch: str, now: dt.datetime) -> int:
    marker = worktree / "agent-memory" / ".dreaming" / "marker"
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(now.isoformat(timespec="seconds") + "\n", encoding="utf-8")

    paths = ["agent-memory/.dreaming/marker"]
    paths.extend(
        str(path.relative_to(worktree))
        for path in sorted((worktree / "agent-memory").glob("dreaming-*.md"))
    )
    run(["git", "add", "--", *paths], cwd=worktree)
    staged = run(["git", "diff", "--cached", "--quiet"], cwd=worktree, check=False, capture=False)
    if staged.returncode == 0:
        log(f"no changes for {hub_run.hub.name}; skip commit")
        return 0

    candidate_count = count_candidates(worktree)
    run(
        ["git", "commit", "-m", f"dreaming: {now.date().isoformat()} candidates"],
        cwd=worktree,
        capture=False,
    )
    run(["git", "push", "-u", hub_run.repo.remote, branch], cwd=worktree, capture=False)
    create_pr(worktree, hub_run, branch, candidate_count, now)
    return candidate_count


def count_candidates(worktree: Path) -> int:
    return len(list((worktree / "agent-memory").glob("dreaming-*.md")))


def create_pr(worktree: Path, hub_run: HubRun, branch: str, candidate_count: int, now: dt.datetime) -> None:
    if shutil.which("gh") is None:
        log("gh not found; pushed branch without creating PR")
        return
    report = worktree / "agent-memory" / ".dreaming" / "report.md"
    title = f"dreaming: {now.date().isoformat()} 候補 {candidate_count}件"
    proc = run(
        [
            "gh",
            "pr",
            "create",
            "--base",
            hub_run.repo.branch,
            "--head",
            branch,
            "--title",
            title,
            "--body-file",
            str(report),
        ],
        cwd=worktree,
        check=False,
    )
    if proc.returncode != 0:
        log(f"gh pr create failed for {hub_run.hub.name}; branch was pushed")


def cleanup_worktree(hub: Hub) -> None:
    worktree = worktree_path(hub)
    if worktree.exists():
        run(["git", "worktree", "remove", "--force", str(worktree)], cwd=hub.path, check=False)
    run(["git", "worktree", "prune"], cwd=hub.path, check=False)


def print_dry_run(hub_run: HubRun) -> None:
    stats = hub_run.digest.stats
    print()
    print(f"hub: {hub_run.hub.name}")
    print(f"  path: {hub_run.hub.path}")
    print(f"  base: {hub_run.repo.base_ref}")
    print(f"  window: {hub_run.window_start.isoformat(timespec='seconds')} .. {hub_run.window_end.isoformat(timespec='seconds')}")
    print(f"  routed in window: {len(hub_run.transcripts)}")
    print(f"  digest sessions: {stats.included_sessions}/{stats.candidate_sessions}")
    print(f"  digest bytes: {stats.digest_bytes}")
    print(f"  truncated sessions: {stats.truncated_sessions}")
    print(f"  omitted by 2MB limit: {stats.skipped_by_size}")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    home = Path.home()
    all_hubs = parse_hubs(home / ".agents" / "hubs.md")
    run_hubs = all_hubs
    if args.hub:
        run_hubs = resolve_requested_hub(all_hubs, args.hub)

    transcripts, missing_cwd = list_transcripts(home / ".claude" / "projects")
    if missing_cwd:
        log(f"skipped {missing_cwd} transcript(s) without cwd before routing")
    routed = route_transcripts(all_hubs, transcripts)
    now = dt.datetime.now().astimezone()
    date = now.date().isoformat()

    for hub in run_hubs:
        worktree: Path | None = None
        try:
            if not hub.path.exists():
                log(f"skip missing hub path: {hub.name} {hub.path}")
                continue

            repo_info = resolve_repo_info(hub)
            if not args.dry_run:
                fetch_repo(hub.path, repo_info.remote)
            window_start = read_marker(hub.path, repo_info.base_ref, now, args.window_hours)
            if not args.dry_run:
                cleanup_worktree(hub)
                supersede_dreaming_branches(hub.path, repo_info)
            hub_run = build_hub_run(
                hub,
                repo_info,
                routed.get(hub.name, []),
                window_start,
                now,
            )

            if args.dry_run:
                print_dry_run(hub_run)
                continue

            if not hub_run.transcripts:
                log(f"no transcripts in window for {hub.name}; skip")
                continue

            branch = f"dreaming/{date}"
            worktree = prepare_worktree(hub, repo_info, branch)
            write_dreaming_inputs(worktree, hub_run.digest)
            if not run_model(worktree, hub):
                continue
            candidates = commit_and_push(worktree, hub_run, branch, now)
            log(f"completed {hub.name}: {candidates} candidate(s)")
        except FileNotFoundError as exc:
            log(f"error in hub {hub.name}: {exc}")
            continue
        except Exception as exc:
            log(f"error in hub {hub.name}: {type(exc).__name__}: {exc}")
            continue
        finally:
            if worktree is not None:
                try:
                    cleanup_worktree(hub)
                except Exception as exc:
                    log(f"cleanup failed for {hub.name}: {type(exc).__name__}: {exc}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
