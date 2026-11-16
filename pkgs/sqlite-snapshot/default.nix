# Consistent, lock-guarded SQLite snapshots for backup jobs.
{
  lib,
  writeShellApplication,
  coreutils,
  sqlite,
  flock,
}:
(writeShellApplication {
  name = "sqlite-snapshot";
  runtimeInputs = [
    coreutils
    sqlite
    flock
  ];
  text = builtins.readFile ./sqlite-snapshot.sh;
})
// {
  meta = with lib; {
    description = "Snapshot SQLite databases with VACUUM INTO under a lock and a timeout";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "sqlite-snapshot";
  };
}
