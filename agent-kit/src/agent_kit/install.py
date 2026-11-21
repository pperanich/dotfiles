"""agent-kit install, uninstall and doctor for Claude Code, Codex, pi and git.

agent-guard itself is a uv tool installed editable from this checkout. Each
harness then calls it through its own mechanism: a Claude plugin, an entry
merged into Codex's hooks.json, a pi package, and git's core.hooksPath.
"""

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
HOOKS_DIR = KIT / "git-hooks"
PLUGIN_ROOT = KIT / "claude"
PI_PACKAGE = KIT / "pi"
SKILL_DIR = KIT / "skills" / "write-agent-check"
SCRIPTS = ("agent-guard", "agent-kit", "agent-kit-run")
PLUGIN = "agent-kit@agent-kit"
HARNESSES = ("tool", "skill", "claude", "codex", "pi", "git")


class Report:
    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self.problems = 0

    def ok(self, msg: str) -> None:
        print(f"  ok    {msg}")

    def todo(self, msg: str) -> None:
        print(f"  todo  {msg}")

    def bad(self, msg: str) -> None:
        self.problems += 1
        print(f"  FAIL  {msg}")

    def run(self, cmd: list[str], env: dict | None = None) -> bool:
        shown = " ".join(shlex.quote(c) for c in cmd)
        if self.dry_run:
            print(f"  would run: {shown}")
            return True
        result = subprocess.run(cmd, env=env, capture_output=True, text=True)
        if result.returncode != 0:
            self.bad(f"{shown} exited {result.returncode}: {(result.stderr or result.stdout).strip()[:300]}")
            return False
        return True


def _home() -> Path:
    return Path.home()


def _short(path: Path) -> str:
    home = str(_home())
    text = str(path)
    return "~" + text[len(home) :] if text.startswith(home + "/") else text


def tool_bin() -> Path:
    result = subprocess.run(["uv", "tool", "dir", "--bin"], capture_output=True, text=True)
    out = result.stdout.strip()
    return Path(out) if result.returncode == 0 and out else _home() / ".local" / "bin"


def guard_path() -> Path:
    return Path(os.environ.get("AGENT_GUARD") or tool_bin() / "agent-guard")


def codex_command() -> str:
    return f"{shlex.quote(str(guard_path()))} pre-tool --harness codex"


def _read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


# Claude Code: one plugin per profile directory


def claude_dirs(explicit: list[str]) -> list[Path]:
    """Profile directories, one per distinct plugins directory (profiles may share one)."""
    if explicit:
        return [Path(os.path.expanduser(d)) for d in explicit]
    found = [_home() / ".claude", _home() / ".claude-work"]
    if os.environ.get("CLAUDE_CONFIG_DIR"):
        found.append(Path(os.environ["CLAUDE_CONFIG_DIR"]))
    by_plugins: dict[Path, Path] = {}
    for d in found:
        if d.is_dir():
            by_plugins.setdefault((d / "plugins").resolve(), d)
    return list(by_plugins.values())


def _claude_env(profile: Path) -> dict:
    env = dict(os.environ)
    env.pop("CLAUDE_CONFIG_DIR", None)
    if profile.resolve() != (_home() / ".claude").resolve():
        env["CLAUDE_CONFIG_DIR"] = str(profile)
    return env


def _claude_installed(profile: Path) -> dict | None:
    data = _read_json(profile / "plugins" / "installed_plugins.json", {})
    entries = data.get("plugins", {}).get(PLUGIN) or []
    return entries[0] if entries else None


def _cache_stale(install_path: str) -> bool:
    """True when Claude's cached copy of the plugin differs from dotfiles, including files dotfiles dropped."""
    cache = Path(install_path)

    def files(root: Path) -> dict[Path, bytes]:
        found = {}
        for dirpath, _, names in os.walk(root, followlinks=True):
            for name in names:
                path = Path(dirpath) / name
                found[path.relative_to(root)] = path.read_bytes()
        return found

    return not cache.is_dir() or files(cache) != files(PLUGIN_ROOT)


def claude(action: str, profile: Path, r: Report) -> None:
    env = _claude_env(profile)
    settings_file = profile / "settings.json"
    if action != "doctor" and settings_file.is_symlink() and profile.resolve() != (_home() / ".claude").resolve():
        r.todo(
            f"Claude {_short(profile)}: settings.json links to {_short(settings_file.resolve())}; skipped so the plugin CLI cannot replace the link"
        )
        return
    if r.dry_run:
        print(f"  profile {_short(profile)}")
    known = _read_json(profile / "plugins" / "known_marketplaces.json", {})
    installed = _claude_installed(profile)
    stale = bool(installed) and _cache_stale(installed.get("installPath", ""))
    if action == "install":
        if "agent-kit" not in known:
            r.run(["claude", "plugin", "marketplace", "add", str(KIT)], env)
        if installed and not stale:
            r.ok(f"Claude {_short(profile)}: {PLUGIN} already current")
            return
        if "agent-kit" in known:
            r.run(["claude", "plugin", "marketplace", "update", "agent-kit"], env)
        # The cache is versioned "unknown", so update sees nothing new; reinstall to recopy.
        if installed:
            r.run(["claude", "plugin", "uninstall", PLUGIN], env)
        if r.run(["claude", "plugin", "install", PLUGIN, "--scope", "user"], env) and not r.dry_run:
            r.ok(f"Claude {_short(profile)}: {'refreshed' if installed else 'installed'} {PLUGIN}")
    elif action == "uninstall":
        if installed:
            r.run(["claude", "plugin", "uninstall", PLUGIN], env)
        if "agent-kit" in known:
            r.run(["claude", "plugin", "marketplace", "remove", "agent-kit"], env)
    elif not installed:
        r.bad(f"Claude {_short(profile)}: {PLUGIN} is not installed")
    elif _read_json(settings_file, {}).get("enabledPlugins", {}).get(PLUGIN) is False:
        r.bad(f"Claude {_short(profile)}: {PLUGIN} is installed but disabled")
    elif stale:
        r.todo(f"Claude {_short(profile)}: the cached copy is older than dotfiles; run agent-kit install to refresh it")
    else:
        r.ok(f"Claude {_short(profile)}: {PLUGIN} installed and current")


# Codex: an entry merged into hooks.json


def codex_home() -> Path:
    return Path(os.environ.get("CODEX_HOME") or _home() / ".codex")


def _is_ours(group: dict) -> bool:
    return any(
        "agent-guard" in str(h.get("command", "")) and "--harness codex" in str(h.get("command", ""))
        for h in group.get("hooks", [])
    )


def codex(action: str, r: Report) -> None:
    home = codex_home()
    path = home / "hooks.json"
    data = _read_json(path, {}) if path.exists() else {}
    hooks = data.setdefault("hooks", {})
    groups = hooks.get("PreToolUse", [])
    ours = [g for g in groups if _is_ours(g)]
    if action == "doctor":
        if not home.is_dir():
            r.todo(f"Codex: {_short(home)} does not exist; skipped")
        elif not ours:
            r.bad(f"Codex: no agent-kit PreToolUse entry in {_short(path)}")
        elif ours[0]["hooks"][0]["command"] != codex_command():
            r.bad("Codex: the agent-kit entry points somewhere else; rerun install")
        else:
            r.ok(
                f"Codex: PreToolUse entry present in {_short(path)} (Codex runs it only after you approve it in /hooks)"
            )
        return
    if not home.is_dir():
        r.todo(f"Codex: {_short(home)} does not exist; skipped")
        return
    rest = [g for g in groups if not _is_ours(g)]
    if action == "install":
        rest.append({"matcher": "", "hooks": [{"type": "command", "command": codex_command(), "timeout": 10}]})
    if rest:
        hooks["PreToolUse"] = rest
    else:
        hooks.pop("PreToolUse", None)
    text = json.dumps(data, indent=2) + "\n"
    if path.exists() and path.read_text() == text:
        r.ok(f"Codex: {_short(path)} already up to date")
        return
    if r.dry_run:
        print(f"  would write {_short(path)}")
        return
    if path.exists():
        shutil.copy2(path, path.with_name(path.name + ".agent-kit.bak"))
    path.write_text(text)
    r.ok(f"Codex: wrote {_short(path)} (backup beside it)")
    if action == "install":
        r.todo("Codex: open codex and approve the new hook in /hooks; until then Codex does not run it")


# skill: a link in ~/.agents/skills, which pi and Codex read, and one in ~/.claude/skills, since Claude Code
# does not read ~/.agents/skills


def skills_dirs() -> list[Path]:
    dirs = [_home() / ".agents" / "skills"]
    if (_home() / ".claude").is_dir():
        dirs.append(_home() / ".claude" / "skills")
    return dirs


def skill(action: str, r: Report) -> None:
    """Link write-agent-check into each skills directory, the convention in dotfiles' home/.agents/skills/README.md."""
    old_codex = codex_home() / "skills" / SKILL_DIR.name  # earlier installs linked it here; Codex reads both
    if action != "doctor" and old_codex.is_symlink() and old_codex.resolve() == SKILL_DIR.resolve() and not r.dry_run:
        old_codex.unlink()
        r.ok(f"skill: removed the old link {_short(old_codex)}")
    for skills in skills_dirs():
        _skill_link(action, skills, r)


def _skill_link(action: str, skills: Path, r: Report) -> None:
    link = skills / SKILL_DIR.name
    ours = link.is_symlink() and link.resolve() == SKILL_DIR.resolve()
    if action == "install":
        if ours:
            r.ok(f"skill: {SKILL_DIR.name} already linked in {_short(skills)}")
        elif skills.is_symlink():
            r.bad(
                f"skill: {_short(skills)} is itself a link (a folded stow directory); unfold it before linking into it"
            )
        elif link.exists() or link.is_symlink():
            r.bad(f"skill: {_short(link)} exists and is not agent-kit's skill; left alone")
        elif r.dry_run:
            print(f"  would link {_short(link)} -> {_short(SKILL_DIR)}")
        else:
            skills.mkdir(parents=True, exist_ok=True)
            link.symlink_to(SKILL_DIR)
            r.ok(f"skill: linked {_short(link)}")
    elif action == "uninstall":
        if ours and not r.dry_run:
            link.unlink()
    elif ours:
        r.ok(f"skill: {SKILL_DIR.name} linked in {_short(skills)}")
    else:
        r.bad(f"skill: {SKILL_DIR.name} is not linked in {_short(skills)}")


# pi: a package entry in each profile's settings.json


def pi_dirs(explicit: list[str]) -> list[Path]:
    if explicit:
        return [Path(os.path.expanduser(d)) for d in explicit]
    found = [_home() / ".pi" / "agent"]
    if os.environ.get("PI_CODING_AGENT_DIR"):
        found.append(Path(os.environ["PI_CODING_AGENT_DIR"]))
    return list(dict.fromkeys(d for d in found if d.is_dir()))


def _pi_entry(profile: Path) -> str | None:
    """The package entry in this profile that resolves to agent-kit's pi package."""
    settings = _read_json(profile / "settings.json", {})
    for entry in settings.get("packages", []):
        source = entry.get("source") if isinstance(entry, dict) else entry
        if isinstance(source, str) and not source.startswith(("npm:", "git:", "http")):
            target = Path(os.path.expanduser(source))
            if not target.is_absolute():
                target = profile / target
            if target.resolve() == PI_PACKAGE.resolve():
                return source
    return None


def _pi_has_kit(profile: Path) -> bool:
    return _pi_entry(profile) is not None


def _pi_tilde_entry(profile: Path, r: Report) -> None:
    """pi install stores a path relative to the settings file; rewrite it as ~/..., which works from any profile."""
    entry, want = _pi_entry(profile), _short(PI_PACKAGE)
    if entry is None or entry == want or r.dry_run:
        return
    settings = profile / "settings.json"
    text = settings.read_text()
    old = json.dumps(entry)
    if text.count(old) == 1:
        settings.write_text(text.replace(old, json.dumps(want)))  # writes through a symlinked settings file
        r.ok(f"pi {_short(profile)}: entry written as {want}")


def pi(action: str, profile: Path, r: Report) -> None:
    env = {**os.environ, "PI_CODING_AGENT_DIR": str(profile)}
    present = _pi_has_kit(profile)
    if action == "install":
        if present:
            r.ok(f"pi {_short(profile)}: package already listed")
        elif r.run(["pi", "install", str(PI_PACKAGE)], env) and not r.dry_run:
            r.ok(f"pi {_short(profile)}: package added")
        _pi_tilde_entry(profile, r)
    elif action == "uninstall":
        if present:
            r.run(["pi", "remove", str(PI_PACKAGE)], env)
    elif present and _pi_entry(profile) != _short(PI_PACKAGE):
        r.todo(
            f"pi {_short(profile)}: listed as {_pi_entry(profile)}; rerun install to write it as {_short(PI_PACKAGE)}"
        )
    elif present:
        r.ok(f"pi {_short(profile)}: package listed as {_short(PI_PACKAGE)}")
    else:
        r.bad(f"pi {_short(profile)}: package not listed in settings.json")


# git: core.hooksPath in the global config file


def _git_config_file() -> Path:
    legacy = _home() / ".gitconfig"
    if legacy.exists():
        return legacy.resolve()
    xdg = Path(os.environ.get("XDG_CONFIG_HOME") or _home() / ".config")
    return (xdg / "git" / "config").resolve()


def _hooks_value() -> str:
    return _short(HOOKS_DIR)


def _current_hooks_path() -> str:
    result = subprocess.run(["git", "config", "--global", "--get", "core.hooksPath"], capture_output=True, text=True)
    return result.stdout.strip()


def _same_dir(value: str) -> bool:
    return bool(value) and Path(os.path.expanduser(value)).resolve() == HOOKS_DIR.resolve()


def git(action: str, r: Report, force: bool) -> None:
    current = _current_hooks_path()
    target = _git_config_file()
    if action == "doctor":
        if _same_dir(current):
            r.ok(f"git: core.hooksPath = {current}")
        else:
            r.bad(f"git: core.hooksPath is {current or 'unset'}, not {_hooks_value()}")
        return
    if action == "install":
        if _same_dir(current):
            r.ok(f"git: core.hooksPath already {current}")
        elif current and not force:
            r.bad(f"git: core.hooksPath is already {current}; pass --force to replace it")
        elif r.run(["git", "config", "--file", str(target), "core.hooksPath", _hooks_value()]) and not r.dry_run:
            r.ok(f"git: set core.hooksPath in {_short(target)}")
    elif _same_dir(current):
        if r.run(["git", "config", "--file", str(target), "--unset", "core.hooksPath"]) and not r.dry_run:
            r.ok(f"git: removed core.hooksPath from {_short(target)}")


# uv tool: agent-guard and agent-kit on PATH, editable from this checkout


def _tool_source() -> str | None:
    """The checkout an installed agent-kit tool runs from, or None when it is not installed editable."""
    result = subprocess.run(["uv", "tool", "dir"], capture_output=True, text=True)
    if result.returncode != 0:
        return None
    venv = Path(result.stdout.strip()) / "agent-kit"
    for direct in venv.glob("lib/python*/site-packages/agent_kit-*.dist-info/direct_url.json"):
        data = _read_json(direct, {})
        if data.get("dir_info", {}).get("editable") and data.get("url", "").startswith("file://"):
            return data["url"][len("file://") :]
    return None


def tool(action: str, r: Report) -> None:
    source = _tool_source()
    scripts = all((tool_bin() / name).exists() for name in SCRIPTS)
    current = bool(source) and Path(source).resolve() == KIT and scripts
    if action == "install":
        if current:
            r.ok(f"uv tool: agent-kit already installed editable from {_short(KIT)}")
        elif r.run(["uv", "tool", "install", "--editable", "--force", str(KIT)]) and not r.dry_run:
            r.ok(f"uv tool: installed agent-kit editable from {_short(KIT)}")
    elif action == "uninstall":
        if source:
            r.run(["uv", "tool", "uninstall", "agent-kit"])
    elif not current:
        where = f"installed from {source}" if source else "not installed editable"
        r.bad(f"uv tool: agent-kit is {where}; run agent-kit install --only tool")
    elif shutil.which("agent-guard") != str(guard_path()):
        r.todo(f"uv tool: installed, but {_short(tool_bin())} is not first on PATH; the hooks call it by full path")
    else:
        r.ok(f"uv tool: agent-guard at {_short(guard_path())}, editable from {_short(KIT)}")


# doctor's end-to-end check


def _self_test(r: Report) -> None:
    guard = guard_path()
    if not guard.exists():
        r.bad(f"{_short(guard)} does not exist; run agent-kit install --only tool")
        return
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "sed -i '' s/a/b/ f"}, "cwd": "/"})
    start = time.perf_counter()
    result = subprocess.run(
        [str(guard), "pre-tool", "--harness", "claude"], input=payload, capture_output=True, text=True
    )
    elapsed = (time.perf_counter() - start) * 1000
    if result.returncode == 2 and "gnu-tools" in result.stderr:
        r.ok(f"guard blocks a known-bad command ({elapsed:.0f} ms)")
    else:
        r.bad(f"guard self-test exited {result.returncode}: {result.stderr.strip()[:200]}")


def _harness_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--only", default=",".join(HARNESSES), help="comma-separated subset of: " + ", ".join(HARNESSES))
    p.add_argument("--claude-dir", action="append", default=[], help="Claude profile directory (repeatable)")
    p.add_argument("--pi-dir", action="append", default=[], help="pi profile directory (repeatable)")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--force", action="store_true", help="replace an existing core.hooksPath")


def _harnesses(args, parser) -> int:
    only = {h.strip() for h in args.only.split(",") if h.strip()}
    unknown = only - set(HARNESSES)
    if unknown:
        parser.error(f"unknown step: {', '.join(sorted(unknown))}")
    r = Report(dry_run=args.dry_run)
    if "tool" in only:
        print("uv tool")
        tool(args.cmd, r)
    if "skill" in only:
        print("skill")
        skill(args.cmd, r)
    if "claude" in only:
        print("Claude Code")
        for profile in claude_dirs(args.claude_dir):
            claude(args.cmd, profile, r)
    if "codex" in only:
        print("Codex")
        codex(args.cmd, r)
    if "pi" in only:
        print("pi")
        for profile in pi_dirs(args.pi_dir):
            pi(args.cmd, profile, r)
    if "git" in only:
        print("git")
        git(args.cmd, r, args.force)
    if args.cmd == "doctor":
        from . import kitcmd

        print("kits")
        kitcmd.doctor(r)
        print("guard")
        _self_test(r)
    return 1 if r.problems else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="agent-kit", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name, text in (
        ("install", "wire agent-guard into every harness"),
        ("uninstall", "remove it again"),
        ("doctor", "report what is live"),
    ):
        _harness_args(sub.add_parser(name, help=text))
    fixtures = sub.add_parser("fixtures", help="turn AGENT_KIT_LOG_DIR logs into fixtures for the built-in rules")
    fixtures.add_argument("logs", nargs="+", type=Path)
    new = sub.add_parser("new", help="create a project kit from the Copier template")
    new.add_argument(
        "--repo", action="store_true", help="create .agent-kit/ inside the repository instead of a user-side kit"
    )
    new.add_argument("--name", help="kit name (default: the repository's directory name)")
    new.add_argument(
        "--source",
        choices=["git", "local"],
        help="where the kit gets agent-kit (default: local for user-side, git for --repo)",
    )
    sub.add_parser("update-kits", help="bring template changes into every kit with copier update")
    trust = sub.add_parser("trust", help="approve an in-repo kit to run (needs a terminal)")
    trust.add_argument("path", nargs="?")
    sub.add_parser("kits", help="list the kits that run here")
    check = sub.add_parser("check", help="run a shell command through the guard without running it")
    check.add_argument("command")
    check.add_argument("--cwd", default=".")
    check.add_argument("--harness", default="claude", choices=["claude", "codex", "pi"])
    args = parser.parse_args(argv)

    if args.cmd in ("install", "uninstall", "doctor"):
        return _harnesses(args, parser)
    if args.cmd == "fixtures":
        from .fixtures import import_logs

        for path in import_logs(args.logs):
            print(f"  wrote {path.relative_to(KIT)}")
        return 0
    if args.cmd == "check":
        from .guard import evaluate

        payload = {"tool_name": "Bash", "tool_input": {"command": args.command}, "cwd": str(Path(args.cwd).resolve())}
        lines = evaluate(payload, args.harness)
        print("\n".join(lines) if lines else "allowed")
        return 2 if lines else 0
    from . import kitcmd

    if args.cmd == "new":
        return kitcmd.new("repo" if args.repo else "user", args.name, args.source, os.getcwd())
    if args.cmd == "update-kits":
        return kitcmd.update_kits(os.getcwd())
    if args.cmd == "trust":
        return kitcmd.trust(args.path, os.getcwd())
    return kitcmd.list_kits(os.getcwd())


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
