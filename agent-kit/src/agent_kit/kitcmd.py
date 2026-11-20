"""agent-kit new, update-kits, trust and kits: project kits made from the Copier template."""

import re
import subprocess
import sys
from pathlib import Path

from . import kits
from .kit import repo_root, show_path

KIT = Path(__file__).resolve().parents[2]
TEMPLATE_REPO = KIT.parent  # Copier versions a template only from a repository root; see copier.yml there
TEMPLATE_URL = "https://github.com/pperanich/dotfiles.git"
COPIER = "copier==9.19.1"
_LOCAL_IDENTITY = ["-c", "user.name=agent-kit", "-c", "user.email=agent-kit@localhost"]
_CONFLICT = "<<<<<<< before updating"


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9-]+", "-", name.lower()).strip("-") or "kit"


def _git(path: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(path), *_LOCAL_IDENTITY, *args], capture_output=True, text=True)


def _repo_kit(cwd: str) -> kits.KitRef | None:
    root = repo_root(cwd)
    if root and (root / kits.IN_REPO_DIR / "pyproject.toml").exists():
        return kits.KitRef(root / kits.IN_REPO_DIR, "repo")
    return None


def new(location: str, name: str | None, source: str | None, cwd: str) -> int:
    root = repo_root(cwd)
    if root is None:
        print(f"agent-kit new: {cwd} is not inside a git repository", file=sys.stderr)
        return 1
    dest = root / kits.IN_REPO_DIR if location == "repo" else kits.user_kit_dir(root)
    if dest.exists():
        print(f"agent-kit new: {show_path(dest)} already exists; edit that kit instead", file=sys.stderr)
        return 1
    kit_name = _slug(name or root.name)
    agent_kit_source = {"git": "git", "local": str(KIT)}.get(source or "", "git" if location == "repo" else str(KIT))
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["uvx", "--from", COPIER, "copier", "copy", "--trust", "--defaults", "--data", f"kit_name={kit_name}"]
    cmd += ["--data", f"agent_kit_source={agent_kit_source}", str(TEMPLATE_REPO), str(dest)]
    if subprocess.run(cmd).returncode != 0:
        print("agent-kit new: Copier failed; nothing was kept", file=sys.stderr)
        return 1
    package = f"{kit_name.replace('-', '_')}_kit"
    if location == "repo":
        answers = dest / ".copier-answers.yml"
        answers.write_text(re.sub(r"^_src_path: .*$", f"_src_path: {TEMPLATE_URL}", answers.read_text(), flags=re.M))
        print(f"\nCreated {show_path(dest)} (in-repo kit). Commit it with the repository.")
        print(f"It runs only after you approve it in a terminal: agent-kit trust {dest}")
    else:
        _git(dest, "init", "-q", "-b", "main")
        _git(dest, "add", "-A")
        _git(dest, "commit", "-q", "-m", "chore: create kit from the agent-kit template")
        print(f"\nCreated {show_path(dest)} (user-side kit for {kits.repo_key(kits.remote_url(root), root)}).")
    print(f"Add rules in src/{package}/checks.py and cases in tests/test_checks.py, then `uv run pytest` there.")
    return 0


def update_kits(cwd: str) -> int:
    refs = kits.all_user_kits() + [r for r in [_repo_kit(cwd)] if r]
    if not refs:
        print("No kits to update.")
        return 0
    failed = 0
    for ref in refs:
        print(f"{show_path(ref.path)}")
        cmd = ["uvx", "--from", COPIER, "copier", "update", "--trust", "--defaults"]
        result = subprocess.run(cmd, cwd=ref.path, capture_output=True, text=True)
        if result.returncode != 0:
            failed += 1
            print(f"  FAIL  {(result.stderr or result.stdout).strip().splitlines()[-1:]}")
            continue
        conflicted = [p for p in ref.path.rglob("*") if p.is_file() and ".venv" not in p.parts and _has_conflict(p)]
        if conflicted:
            failed += 1
            print(
                f"  todo  resolve the conflict markers in: {', '.join(str(p.relative_to(ref.path)) for p in conflicted)}"
            )
        elif ref.location == "user" and _git(ref.path, "status", "--porcelain").stdout.strip():
            _git(ref.path, "add", "-A")
            _git(ref.path, "commit", "-q", "-m", "chore: update kit from the agent-kit template")
            print("  ok    updated and committed")
        else:
            print(
                "  ok    up to date"
                if ref.location == "user"
                else "  ok    updated; review and commit with the repository"
            )
    return 1 if failed else 0


def _has_conflict(path: Path) -> bool:
    try:
        return _CONFLICT in path.read_text(errors="ignore")
    except OSError:
        return False


def trust(path: str | None, cwd: str) -> int:
    ref = kits.KitRef(Path(path).resolve(), "repo") if path else _repo_kit(cwd)
    if ref is None or not (ref.path / "pyproject.toml").exists():
        print("agent-kit trust: no kit here; pass its path", file=sys.stderr)
        return 1
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print(
            f"agent-kit trust needs a terminal, so an agent cannot approve a kit. Run it yourself: agent-kit trust {ref.path}",
            file=sys.stderr,
        )
        return 1
    files = sorted(
        str(p.relative_to(ref.path))
        for p in ref.path.rglob("*")
        if p.is_file() and not kits._SKIP & set(p.relative_to(ref.path).parts)
    )
    print(f"{show_path(ref.path)}: {len(files)} files\n  " + "\n  ".join(files))
    answer = input("Run this kit's code before every agent tool call in this repository? [y/N] ")
    if answer.strip().lower() != "y":
        print("Not trusted.")
        return 1
    kits.record_trust(ref.path)
    print("Trusted. A change to any of these files needs trust again.")
    return 0


def _rules(ref: kits.KitRef) -> str:
    if not ref.ready:
        return "not synced (run `uv sync` in the kit)"
    result = subprocess.run([str(ref.runner), "list"], capture_output=True, text=True)
    return "; ".join(result.stdout.split("\n")).strip("; ") or "(no rules)"


def list_kits(cwd: str) -> int:
    here = kits.discover(cwd)
    others = [r for r in kits.all_user_kits() if r.path not in {h.path for h in here}]
    if not here and not others:
        print("No kits. Create one with: agent-kit new")
        return 0
    if here:
        print(f"Running in {show_path(repo_root(cwd) or Path(cwd))}:")
    for ref in here:
        state = "trusted" if ref.trusted else "NOT TRUSTED (agent-kit trust)"
        print(f"  {ref.location:4}  {show_path(ref.path)}  {state}\n        {_rules(ref)}")
    if others:
        print("Other user-side kits:")
        for ref in others:
            print(f"  {show_path(ref.path)}  {_rules(ref)}")
    return 0


def doctor(report) -> None:
    for ref in kits.all_user_kits() + [r for r in [_repo_kit(".")] if r]:
        if not ref.ready:
            report.bad(f"kit {show_path(ref.path)}: not synced; run `uv sync` there")
        elif not ref.trusted:
            report.todo(f"kit {show_path(ref.path)}: not trusted, so it does not run; agent-kit trust {ref.path}")
        else:
            report.ok(f"kit {show_path(ref.path)}: ready")
