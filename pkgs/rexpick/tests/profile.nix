# Model both Home Manager's full environment and the outer OS user profile.
# Checking only the inner environment misses environment.pathsToLink filtering.
{
  runCommand,
  buildEnv,
  rex,
  rexpick,
  profilePaths,
}:
let
  homeEnvironment = buildEnv {
    name = "rexpick-test-home-environment";
    paths = [
      rex
      rexpick
    ];
    pathsToLink = [ "/" ];
  };
  userProfile = buildEnv {
    name = "rexpick-test-user-profile";
    paths = [ homeEnvironment ];
    pathsToLink = profilePaths;
  };
  binOnlyProfile = buildEnv {
    name = "rexpick-test-bin-only-profile";
    paths = [ homeEnvironment ];
    pathsToLink = [ "/bin" ];
  };
  luaConfig = ../../../home/.config/rex/init.lua;
in
runCommand "rexpick-profile-check" { } ''
  export HOME="$TMPDIR/home"
  export USER=rexpick-profile-test
  mkdir -p "$HOME"

  # Reproduce the old failure: the package and both binaries exist, but the
  # outer profile hides the launcher. Config validation must reject this.
  test -r ${homeEnvironment}/share/rexpick/float.lua
  test -x ${binOnlyProfile}/bin/rex
  test -x ${binOnlyProfile}/bin/rexpick
  test ! -e ${binOnlyProfile}/share/rexpick/float.lua
  ln -s ${binOnlyProfile} "$HOME/.nix-profile"
  if ${binOnlyProfile}/bin/rex --autostart=false config check ${luaConfig} > negative.log 2>&1; then
    echo "Config unexpectedly accepted a profile without its launcher" >&2
    exit 1
  fi
  grep -F "activate the Nix configuration first" negative.log
  rm "$HOME/.nix-profile"

  # Use the real host's link policy, not a fixture that exposes all of share/.
  test -x ${userProfile}/bin/rex
  test -x ${userProfile}/bin/rexpick
  if ! test -r ${userProfile}/share/rexpick/float.lua; then
    echo "Host profile link policy hides share/rexpick/float.lua" >&2
    exit 1
  fi
  ln -s ${userProfile} "$HOME/.nix-profile"
  ${userProfile}/bin/rex --autostart=false config check ${luaConfig} > positive.log 2>&1
  grep -Fx "bindings: 1" positive.log
  grep -Fx "actions: 2" positive.log
  mkdir -p "$out"
  cp negative.log positive.log "$out/"
''
