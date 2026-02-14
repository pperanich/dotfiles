{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "cf-dns";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./main.go
    ];
  };

  vendorHash = "sha256-rpg1fAC7KH5jtAO28iNsyADnZ1H1teKlg7CHVaGLUvk=";

  meta = with lib; {
    description = "Declarative Cloudflare DNS record sync tool";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "cf-dns";
  };
}
