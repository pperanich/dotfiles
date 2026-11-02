{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "rexpick";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./cmd
      ./internal
    ];
  };

  vendorHash = "sha256-uwBJAqN4sIepiiJf9lCDumLqfKJEowQO2tOiSWD3Fig=";

  subPackages = [ "cmd/rexpick" ];

  # Share the tested argv-only launcher with the normal, Stow-managed Lua config.
  postInstall = ''
    install -Dm644 ${./examples/float.lua} "$out/share/rexpick/float.lua"
  '';

  meta = with lib; {
    description = "Rex terminal picker for sessions, projects and agent status";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "rexpick";
  };
}
