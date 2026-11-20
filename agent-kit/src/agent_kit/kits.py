"""Find, trust and run project kits.

A project's kit lives either in the repository at .agent-kit/ or on this
machine at <config>/projects/<host>/<owner>/<repo>/, keyed by the origin
remote. The global guard runs each one through the agent-kit-run script in the
kit's own .venv, so a kit's dependencies never touch agent-kit's. A kit inside
a repository runs only after `agent-kit trust` records a hash of its files.
"""

import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .kit import config_dir, repo_root

IN_REPO_DIR = ".agent-kit"
_SKIP = {".venv", "__pycache__", ".pytest_cache", ".ruff_cache", ".git"}
_TIMEOUT_S = 8


@dataclass
class KitRef:
    path: Path
    location: str  # "repo" or "user"

    @property
    def runner(self) -> Path:
        return self.path / ".venv" / "bin" / "agent-kit-run"

    @property
    def ready(self) -> bool:
        return self.runner.exists()

    @property
    def trusted(self) -> bool:
        return self.location == "user" or trusted_hash(self.path) == kit_hash(self.path)


def projects_dir() -> Path:
    return config_dir() / "projects"


def _git_config(root: Path) -> Path | None:
    dot_git = root / ".git"
    if dot_git.is_dir():
        return dot_git / "config"
    if dot_git.is_file():
        gitdir = Path(dot_git.read_text().split("gitdir:", 1)[-1].strip())
        gitdir = gitdir if gitdir.is_absolute() else (root / gitdir).resolve()
        common = gitdir / "commondir"
        base = (gitdir / common.read_text().strip()).resolve() if common.exists() else gitdir
        return base / "config"
    return None


def remote_url(root: Path) -> str | None:
    config = _git_config(root)
    if not config or not config.exists():
        return None
    in_origin = False
    for line in config.read_text(errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            in_origin = stripped.replace(" ", "") == '[remote"origin"]'
        elif in_origin and re.match(r"url\s*=", stripped):
            return stripped.split("=", 1)[1].strip()
    return None


def repo_key(url: str | None, root: Path) -> str:
    """host/owner/repo from a remote URL, or local/<dirname> without one."""
    if not url:
        return f"local/{root.name}"
    text = re.sub(r"^[a-z+]+://", "", url)
    text = re.sub(r"^[^@/]+@", "", text)
    text = text.replace(":", "/", 1) if ":" in text.split("/", 1)[0] else text
    return re.sub(r"\.git$", "", text).strip("/")


def user_kit_dir(root: Path) -> Path:
    return projects_dir() / repo_key(remote_url(root), root)


def discover(cwd: str) -> list[KitRef]:
    root = repo_root(cwd)
    if root is None:
        return []
    found = []
    if (root / IN_REPO_DIR / "pyproject.toml").exists():
        found.append(KitRef(root / IN_REPO_DIR, "repo"))
    if projects_dir().is_dir():
        user = user_kit_dir(root)
        if (user / "pyproject.toml").exists():
            found.append(KitRef(user, "user"))
    return found


def all_user_kits() -> list[KitRef]:
    if not projects_dir().is_dir():
        return []
    return [KitRef(p.parent, "user") for p in sorted(projects_dir().glob("*/*/*/pyproject.toml"))] + [
        KitRef(p.parent, "user") for p in sorted(projects_dir().glob("local/*/pyproject.toml"))
    ]


# trust


def kit_hash(path: Path) -> str:
    digest = hashlib.sha256()
    for file in sorted(p for p in path.rglob("*") if p.is_file() and not _SKIP & set(p.relative_to(path).parts)):
        digest.update(str(file.relative_to(path)).encode() + b"\0" + file.read_bytes() + b"\0")
    return digest.hexdigest()


def _trust_file() -> Path:
    return config_dir() / "trusted.json"


def trusted_hash(path: Path) -> str | None:
    try:
        return json.loads(_trust_file().read_text()).get(str(path.resolve()))
    except (OSError, ValueError):
        return None


def record_trust(path: Path) -> None:
    file = _trust_file()
    try:
        data = json.loads(file.read_text())
    except (OSError, ValueError):
        data = {}
    data[str(path.resolve())] = kit_hash(path)
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


# running


def run(ref: KitRef, args: list[str], payload: str = "") -> tuple[int | None, str]:
    """Run the kit's agent-kit-run; (exit code or None on failure to run, stderr)."""
    try:
        result = subprocess.run(
            [str(ref.runner), *args], input=payload, capture_output=True, text=True, timeout=_TIMEOUT_S
        )
    except (OSError, subprocess.TimeoutExpired):
        return None, ""
    return result.returncode, result.stderr
