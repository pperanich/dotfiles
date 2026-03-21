{
  stdenv,
  bun2nix,
  personal-site-src,
}:
stdenv.mkDerivation {
  pname = "personal-site";
  version = "0.0.1";
  src = personal-site-src;

  nativeBuildInputs = [ bun2nix.hook ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = "${personal-site-src}/bun.nix";
  };

  buildPhase = ''
    bun run build --minify
  '';

  installPhase = ''
    cp -r ./dist $out
  '';
}
