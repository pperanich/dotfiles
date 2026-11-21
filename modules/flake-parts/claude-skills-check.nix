# Claude Code does not read ~/.agents/skills, so each shared skill needs its own
# link in home/.claude/skills. The dev-* skills reach Claude as /dev:* commands.
{ lib, ... }:
let
  hub = builtins.readDir ../../home/.agents/skills;
  claude = builtins.readDir ../../home/.claude/skills;

  shared = lib.filter (name: hub.${name} == "directory" && !lib.hasPrefix "dev-" name) (
    lib.attrNames hub
  );
  unlinked = lib.filter (name: claude.${name} or null != "symlink") shared;
  orphaned = lib.filter (name: hub.${name} or null != "directory") (lib.attrNames claude);

  linked =
    lib.assertMsg (unlinked == [ ])
      "home/.claude/skills has no link for ${lib.concatStringsSep ", " unlinked}; add one per skill, e.g. ln -s ../../.agents/skills/<name> home/.claude/skills/<name>"
    &&
      lib.assertMsg (orphaned == [ ])
        "home/.claude/skills links to skills missing from home/.agents/skills: ${lib.concatStringsSep ", " orphaned}";
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.claude-skills-linked =
        assert linked;
        pkgs.runCommand "claude-skills-linked" { } "touch $out";
    };
}
