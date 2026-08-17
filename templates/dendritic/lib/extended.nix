# nixpkgs lib + lib.my.* — imported directly (not via a module argument) so
# that handing it to nixosSystem/darwinSystem as a specialArg can't create a
# cycle back through the flake-parts config.
{ nixpkgs }:
nixpkgs.lib.extend (
  _self: _super: {
    my = import ./. { inherit (nixpkgs) lib; };
  }
)
