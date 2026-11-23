# Claude Code and Antigravity get one link per shared skill, so skills made for
# one agent stay out of ~/.agents/skills. The dev-* skills reach Claude as /dev:* commands.
{ lib, ... }:
let
  hub = builtins.readDir ../../home/.agents/skills;
  skills = lib.filter (name: hub.${name} == "directory") (lib.attrNames hub);

  linkedFrom =
    agentDir: wanted:
    let
      links = builtins.readDir agentDir;
      unlinked = lib.filter (name: links.${name} or null != "symlink") wanted;
      orphaned = lib.filter (name: hub.${name} or null != "directory") (lib.attrNames links);
      rel = lib.removePrefix "${toString ../../home}/" (toString agentDir);
    in
    lib.assertMsg (unlinked == [ ])
      "home/${rel} has no link for ${lib.concatStringsSep ", " unlinked}; add one per skill pointing at home/.agents/skills/<name>"
    &&
      lib.assertMsg (orphaned == [ ])
        "home/${rel} links to skills missing from home/.agents/skills: ${lib.concatStringsSep ", " orphaned}";

  claudeLinked = linkedFrom ../../home/.claude/skills (
    lib.filter (name: !lib.hasPrefix "dev-" name) skills
  );
  geminiLinked = linkedFrom ../../home/.gemini/config/skills skills;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.claude-skills-linked =
        assert claudeLinked;
        pkgs.runCommand "claude-skills-linked" { } "touch $out";
      checks.antigravity-skills-linked =
        assert geminiLinked;
        pkgs.runCommand "antigravity-skills-linked" { } "touch $out";
    };
}
