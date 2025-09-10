# NixOS Anywhere command

```
nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./hosts/pperanich-orin1/hardware-configuration.nix --flake .#pperanich-orin1 --target-host root@ubuntu.local --build-on-remote
```
