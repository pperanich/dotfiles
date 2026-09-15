# Optional replacement for upstream's fixed provider list. Read only the
# plaintext field names in SOPS YAML; no decryption or build is needed.
# Supports one flat api_keys mapping as written by sops, with unquoted names
# that can become shell variables and single-line ENC[...] values.
{ inputs, ... }:
let
  inherit (inputs.upstream) lib;
  lines = lib.splitString "\n" (builtins.readFile ../../sops/secrets.yaml);
  invalid = throw "apiKeys: expected a flat api_keys mapping in sops/secrets.yaml with unique unquoted shell-variable names and single-line SOPS ENC[...] values; see docs/upstream-contract.md";
  step =
    acc: rawLine:
    let
      line = lib.removeSuffix "\r" rawLine;
      header = builtins.match "api_keys: *([#].*)?" line != null;
      empty = builtins.match "api_keys: *[{][}] *([#].*)?" line != null;
      mentionsSection = builtins.match "[\"']?api_keys[\"']? *:.*" line != null;
      ignored = builtins.match "[[:space:]]*([#].*)?" line != null;
      topLevel = builtins.match "[^[:space:]].*" line != null;
      child = builtins.match "( +)([A-Za-z_][A-Za-z0-9_]*): +(ENC[[][^]]*[]]) *" line;
      indent = builtins.elemAt child 0;
      name = builtins.elemAt child 1;
    in
    if ignored then
      acc
    else if mentionsSection then
      if acc.seen || !(header || empty) then
        invalid
      else
        acc
        // {
          active = header;
          seen = true;
        }
    else if topLevel then
      acc // { active = false; }
    else if !acc.active then
      acc
    else if
      child == null || (acc.indent != null && indent != acc.indent) || lib.elem name acc.names
    then
      invalid
    else
      acc
      // {
        inherit indent;
        names = acc.names ++ [ name ];
      };
  parsed = builtins.foldl' step {
    active = false;
    seen = false;
    indent = null;
    names = [ ];
  } lines;
in
{
  flake.modules.homeManager.apiKeys = {
    sops.secrets = lib.genAttrs (map (name: "api_keys/${name}") parsed.names) (_: { });
  };
}
