{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "cf";
  version = "0.2.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./main.go
      ./dns.go
      ./tunnel.go
    ];
  };

  vendorHash = "sha256-+SKQ3b8wtCTueReVW/QnUjk7jkrpbP0RHgO4B5P7eSA=";

  meta = with lib; {
    description = "Unified Cloudflare CLI for DNS sync and tunnel provisioning";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "cf";
  };
}
