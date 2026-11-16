# The real router and NAS configs, checked for the Borg tier's structure.
{ config, lib, ... }:
let
  routerBackupEval = config.flake.nixosConfigurations.pp-router1;
  nasBackupEval = config.flake.nixosConfigurations.pp-nas1;

  nasRepo = nasBackupEval.config.services.borgbackup.repos.pp-router1;

  assertionsPassed =
    lib.assertMsg (
      routerBackupEval.config.services.borgbackup.jobs ? remote
    ) "router Borg job 'remote' is missing"
    && lib.assertMsg (nasRepo.authorizedKeysAppendOnly != [ ]) "NAS Borg repo has no append-only keys"
    && lib.assertMsg (nasRepo.authorizedKeys == [ ]) "NAS Borg repo grants full-access keys"
    && lib.assertMsg (
      nasBackupEval.config.systemd.services.borgbackup-repo-pp-router1.unitConfig.RequiresMountsFor == [
        "/tank/backups/borg/pp-router1"
      ]
    ) "NAS Borg repo unit does not require the repository mount";

  evalSummary = builtins.unsafeDiscardStringContext (
    builtins.toJSON {
      inherit assertionsPassed;
      routerToplevel = routerBackupEval.config.system.build.toplevel.drvPath;
      nasToplevel = nasBackupEval.config.system.build.toplevel.drvPath;
    }
  );
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        backup-module-eval =
          assert assertionsPassed;
          pkgs.runCommand "backup-module-eval"
            {
              passAsFile = [ "summary" ];
              summary = evalSummary;
            }
            ''
              cp "$summaryPath" "$out"
            '';

        sqlite-snapshot-test =
          pkgs.runCommand "sqlite-snapshot-test"
            {
              nativeBuildInputs = [
                (pkgs.callPackage ../../pkgs/sqlite-snapshot { })
                pkgs.sqlite
              ];
            }
            ''
              set -euo pipefail
              fail() { echo "FAIL: $*" >&2; exit 1; }
              cd "$(mktemp -d)"

              # The quote in the directory name exercises quoting of the VACUUM INTO target.
              snap="out'dir"
              src="$PWD/src.db"
              sqlite3 "$src" "CREATE TABLE t(v TEXT); INSERT INTO t VALUES('hello');"

              sqlite-snapshot --out-dir "$snap" app="$src"
              [ "$(sqlite3 "$snap/app.sqlite3" 'PRAGMA integrity_check')" = ok ] || fail "integrity_check after first run"
              [ "$(sqlite3 "$snap/app.sqlite3" 'SELECT v FROM t')" = hello ] || fail "row missing from snapshot"

              if sqlite-snapshot --out-dir missing-out missing="$PWD/nope.db" 2>err; then
                fail "missing source exited 0"
              fi
              grep -qF "expected SQLite database for 'missing' not found at $PWD/nope.db" err || fail "missing-source message: $(cat err)"
              [ ! -e missing-out/missing.sqlite3 ] || fail "output created for missing source"

              sqlite-snapshot --out-dir "$snap" app="$src" &
              bg=$!
              sqlite-snapshot --out-dir "$snap" app="$src" || fail "foreground concurrent run"
              wait "$bg" || fail "background concurrent run"
              [ "$(sqlite3 "$snap/app.sqlite3" 'PRAGMA integrity_check')" = ok ] || fail "integrity_check after concurrent runs"

              leftovers=$(find "$snap" missing-out -name '*.tmp')
              [ -z "$leftovers" ] || fail "temporary files left: $leftovers"

              touch "$out"
            '';
      };
    };
}
