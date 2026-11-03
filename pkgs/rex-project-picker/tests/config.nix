{ runCommand, rex }:
runCommand "rex-project-picker-config-check" { } ''
  export HOME="$TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$XDG_CONFIG_HOME/rex"

  # The source link is part of the Stow deployment, not a filtered Nix share path.
  if ${rex}/bin/rex --autostart=false config check ${../../../home/.config/rex/init.lua} > missing.log 2>&1; then
    echo "Config unexpectedly accepted a missing project-picker source link" >&2
    exit 1
  fi
  grep -F 'rex-project-picker/picker.lua' missing.log
  ln -s ${../.} "$XDG_CONFIG_HOME/rex/rex-project-picker"
  ${rex}/bin/rex --autostart=false config check ${../../../home/.config/rex/init.lua} > present.log 2>&1
  grep -Fx 'bindings: 1' present.log
  grep -Fx 'actions: 2' present.log
  mkdir -p "$out"
  cp missing.log present.log "$out/"
''
