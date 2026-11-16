# Schemas for the outputs Determinate Nix has no built-in schema for. Without one,
# `nix flake check` lists the output as unchecked and `nix flake show` cannot describe it.
{ inputs, ... }:
{
  flake.schemas = inputs.flake-schemas.exportedSchemas // {
    deploy = {
      version = 1;
      doc = "The `deploy` flake output defines the deploy-rs nodes and their rollback settings.";
      inventory = output: {
        children.nodes.children = builtins.mapAttrs (_: node: {
          what = "deploy-rs node";
          shortDescription = node.hostname;
          evalChecks.hasSystemProfile = node.profiles ? system;
        }) output.nodes;
      };
    };

    # nixpkgs' lib is merged in and throws on its removed aliases, so only lib.my is listed.
    lib = {
      version = 1;
      doc = "The `lib` flake output is nixpkgs' `lib` with this repository's helpers under `lib.my`.";
      inventory = output: {
        children.my.children = builtins.mapAttrs (_: value: {
          what = if builtins.isFunction value then "library function" else "library data";
        }) output.my;
      };
    };

    modules = {
      version = 1;
      doc = "The `modules` flake output holds the modules exported per class: `nixos`, `darwin` and `homeManager`.";
      inventory = output: {
        children = builtins.mapAttrs (class: classModules: {
          children = builtins.mapAttrs (_: module: {
            what = "${class} module";
            evalChecks.isFunctionOrAttrs = builtins.isFunction module || builtins.isAttrs module;
          }) classModules;
        }) output;
      };
    };
  };
}
