# Database management and development tools module
# Provides comprehensive database clients, admin tools, and utilities
# Supports PostgreSQL, MySQL, SQLite, Redis, MongoDB, and more
_: {
  # NixOS system-level database tools and optional servers
  flake.modules.nixos.databaseTools = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.databaseTools;
  in {
    options.features.databaseTools = {
      enableServers = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable database servers (PostgreSQL, MySQL, Redis)";
      };

      postgresql = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.postgresql_16;
          description = "PostgreSQL package to use";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 5432;
          description = "PostgreSQL port";
        };
      };

      mysql = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.mysql80;
          description = "MySQL package to use";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 3306;
          description = "MySQL port";
        };
      };

      redis = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 6379;
          description = "Redis port";
        };
      };
    };

    config = {
      # System-level database packages
      environment.systemPackages = with pkgs; [
        # SQL clients and tools
        postgresql_16
        mysql80
        sqlite

        # CLI database tools
        pgcli
        mycli
        litecli

        # Migration tools
        flyway
        liquibase
        dbmate

        # Redis tools
        redis

        # NoSQL tools
        mongodb-tools

        # Data processing tools
        miller
        xsv
        csvkit

        # Database utilities
        sqlitebrowser
        adminer
      ];

      # Optional database servers
      services = lib.mkIf cfg.enableServers {
        postgresql = {
          enable = true;
          inherit (cfg.postgresql) package;
          inherit (cfg.postgresql) port;
          authentication = pkgs.lib.mkOverride 10 ''
            local all all trust
            host all all 127.0.0.1/32 trust
            host all all ::1/128 trust
          '';
          initialScript = pkgs.writeText "backend-initScript" ''
            CREATE ROLE dev WITH LOGIN PASSWORD 'dev' CREATEDB;
            CREATE DATABASE dev;
            GRANT ALL PRIVILEGES ON DATABASE dev TO dev;
          '';
        };

        mysql = {
          enable = true;
          inherit (cfg.mysql) package;
          inherit (cfg.mysql) port;
          initialScript = pkgs.writeText "mysql-init" ''
            CREATE USER IF NOT EXISTS 'dev'@'localhost' IDENTIFIED BY 'dev';
            CREATE DATABASE IF NOT EXISTS dev;
            GRANT ALL PRIVILEGES ON dev.* TO 'dev'@'localhost';
            FLUSH PRIVILEGES;
          '';
        };

        redis.servers."" = {
          enable = true;
          inherit (cfg.redis) port;
          bind = "127.0.0.1";
        };
      };

      # Firewall configuration for database servers
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.enableServers [
        cfg.postgresql.port
        cfg.mysql.port
        cfg.redis.port
      ];
    };
  };

  # Darwin system-level database tools and Homebrew casks
  flake.modules.darwin.databaseTools = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      # Core database clients
      postgresql_16
      mysql80
      sqlite

      # CLI tools
      pgcli
      mycli
      litecli

      # Migration tools
      flyway
      liquibase
      dbmate

      # Redis tools
      redis

      # NoSQL tools
      mongodb-tools

      # Data processing
      miller
      xsv
      csvkit
    ];

    homebrew = {
      # Database GUI applications via Homebrew
      casks = [
        "dbeaver-community"
        "pgadmin4"
        "sequel-pro"
        "mongodb-compass"
        "redis-pro"
        "tableplus"
        "querious"
        "sqlitestudio"
      ];

      # Additional database tools from Homebrew
      brews = [
        "mongosh"
        "cassandra"
        "cassandra-cpp-driver"
        "redli"
      ];
    };

    # macOS-specific environment variables
    environment.variables = {
      PGHOST = "localhost";
      PGUSER = "postgres";
      MYSQL_HOST = "127.0.0.1";
      REDIS_URL = "redis://127.0.0.1:6379";
    };
  };

  # Home Manager user-level database configuration and tools
  flake.modules.homeModules.databaseTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # Command-line database clients
        postgresql_16
        mysql80
        sqlite

        # Enhanced CLI clients
        pgcli
        mycli
        litecli

        # Migration and schema tools
        flyway
        liquibase
        dbmate

        # Redis CLI tools
        redis
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        sqlitebrowser
        dbeaver

        # Additional Linux database tools
        usql
        mdbtools
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific packages
        mongosh-bin
      ];

    # Database connection helper scripts
    home.file.".local/bin/db-connect" = {
      text = ''
        #!/usr/bin/env bash
        # Database connection helper
        set -euo pipefail

        show_help() {
          cat << EOF
        Database Connection Helper

        Usage: db-connect [OPTIONS] <database_type> [database_name]

        Database Types:
          pg, postgres    Connect to PostgreSQL
          my, mysql       Connect to MySQL
          sqlite          Connect to SQLite file
          redis           Connect to Redis
          mongo           Connect to MongoDB

        Options:
          -h, --help      Show this help
          -u, --user      Database user (default: current user)
          -p, --port      Database port (uses defaults)
          -H, --host      Database host (default: localhost)

        Examples:
          db-connect pg mydb
          db-connect mysql -u root
          db-connect sqlite ./data.db
          db-connect redis
        EOF
        }

        # Default values
        DB_USER="''${USER}"
        DB_HOST="localhost"
        DB_PORT=""

        # Parse arguments
        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help)
              show_help
              exit 0
              ;;
            -u|--user)
              DB_USER="$2"
              shift 2
              ;;
            -p|--port)
              DB_PORT="$2"
              shift 2
              ;;
            -H|--host)
              DB_HOST="$2"
              shift 2
              ;;
            pg|postgres)
              DB_TYPE="postgres"
              shift
              ;;
            my|mysql)
              DB_TYPE="mysql"
              shift
              ;;
            sqlite)
              DB_TYPE="sqlite"
              shift
              ;;
            redis)
              DB_TYPE="redis"
              shift
              ;;
            mongo)
              DB_TYPE="mongo"
              shift
              ;;
            *)
              if [[ -z "''${DB_TYPE:-}" ]]; then
                echo "Error: Unknown database type: $1"
                exit 1
              else
                DB_NAME="$1"
              fi
              shift
              ;;
          esac
        done

        if [[ -z "''${DB_TYPE:-}" ]]; then
          echo "Error: Database type required"
          show_help
          exit 1
        fi

        # Set default ports if not specified
        case $DB_TYPE in
          postgres)
            DB_PORT="''${DB_PORT:-5432}"
            if command -v pgcli >/dev/null 2>&1; then
              exec pgcli -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "''${DB_NAME:-}"
            else
              exec psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "''${DB_NAME:-}"
            fi
            ;;
          mysql)
            DB_PORT="''${DB_PORT:-3306}"
            if command -v mycli >/dev/null 2>&1; then
              exec mycli -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "''${DB_NAME:-}"
            else
              exec mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "''${DB_NAME:-}"
            fi
            ;;
          sqlite)
            if [[ -z "''${DB_NAME:-}" ]]; then
              echo "Error: SQLite database file required"
              exit 1
            fi
            if command -v litecli >/dev/null 2>&1; then
              exec litecli "$DB_NAME"
            else
              exec sqlite3 "$DB_NAME"
            fi
            ;;
          redis)
            DB_PORT="''${DB_PORT:-6379}"
            if command -v redli >/dev/null 2>&1; then
              exec redli -h "$DB_HOST" -p "$DB_PORT"
            else
              exec redis-cli -h "$DB_HOST" -p "$DB_PORT"
            fi
            ;;
          mongo)
            DB_PORT="''${DB_PORT:-27017}"
            if command -v mongosh >/dev/null 2>&1; then
              exec mongosh "mongodb://$DB_HOST:$DB_PORT/''${DB_NAME:-}"
            else
              exec mongo "mongodb://$DB_HOST:$DB_PORT/''${DB_NAME:-}"
            fi
            ;;
        esac
      '';
      executable = true;
    };

    # Database backup helper script
    home.file.".local/bin/db-backup" = {
      text = ''
        #!/usr/bin/env bash
        # Database backup helper
        set -euo pipefail

        show_help() {
          cat << EOF
        Database Backup Helper

        Usage: db-backup [OPTIONS] <database_type> <database_name> [output_file]

        Database Types:
          pg, postgres    Backup PostgreSQL database
          my, mysql       Backup MySQL database
          sqlite          Copy SQLite database file

        Options:
          -h, --help      Show this help
          -u, --user      Database user (default: current user)
          -p, --port      Database port (uses defaults)
          -H, --host      Database host (default: localhost)
          -c, --compress  Compress output (gzip)

        Examples:
          db-backup pg mydb
          db-backup mysql -u root mydb backup.sql
          db-backup sqlite ./data.db ./backup.db
        EOF
        }

        # Default values
        DB_USER="''${USER}"
        DB_HOST="localhost"
        DB_PORT=""
        COMPRESS=false

        # Parse arguments
        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help)
              show_help
              exit 0
              ;;
            -u|--user)
              DB_USER="$2"
              shift 2
              ;;
            -p|--port)
              DB_PORT="$2"
              shift 2
              ;;
            -H|--host)
              DB_HOST="$2"
              shift 2
              ;;
            -c|--compress)
              COMPRESS=true
              shift
              ;;
            pg|postgres)
              DB_TYPE="postgres"
              shift
              ;;
            my|mysql)
              DB_TYPE="mysql"
              shift
              ;;
            sqlite)
              DB_TYPE="sqlite"
              shift
              ;;
            *)
              if [[ -z "''${DB_TYPE:-}" ]]; then
                echo "Error: Unknown database type: $1"
                exit 1
              elif [[ -z "''${DB_NAME:-}" ]]; then
                DB_NAME="$1"
              else
                OUTPUT_FILE="$1"
              fi
              shift
              ;;
          esac
        done

        if [[ -z "''${DB_TYPE:-}" ]] || [[ -z "''${DB_NAME:-}" ]]; then
          echo "Error: Database type and name required"
          show_help
          exit 1
        fi

        # Generate output filename if not provided
        if [[ -z "''${OUTPUT_FILE:-}" ]]; then
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          case $DB_TYPE in
            postgres)
              OUTPUT_FILE="''${DB_NAME}_''${TIMESTAMP}.sql"
              ;;
            mysql)
              OUTPUT_FILE="''${DB_NAME}_''${TIMESTAMP}.sql"
              ;;
            sqlite)
              OUTPUT_FILE="''${DB_NAME}_''${TIMESTAMP}.db"
              ;;
          esac

          if [[ "$COMPRESS" == true ]]; then
            OUTPUT_FILE="''${OUTPUT_FILE}.gz"
          fi
        fi

        echo "Backing up $DB_TYPE database '$DB_NAME' to '$OUTPUT_FILE'..."

        # Perform backup
        case $DB_TYPE in
          postgres)
            DB_PORT="''${DB_PORT:-5432}"
            if [[ "$COMPRESS" == true ]]; then
              pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" | gzip > "$OUTPUT_FILE"
            else
              pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$OUTPUT_FILE"
            fi
            ;;
          mysql)
            DB_PORT="''${DB_PORT:-3306}"
            if [[ "$COMPRESS" == true ]]; then
              mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" | gzip > "$OUTPUT_FILE"
            else
              mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" > "$OUTPUT_FILE"
            fi
            ;;
          sqlite)
            if [[ "$COMPRESS" == true ]]; then
              gzip -c "$DB_NAME" > "$OUTPUT_FILE"
            else
              cp "$DB_NAME" "$OUTPUT_FILE"
            fi
            ;;
        esac

        echo "Backup completed: $OUTPUT_FILE"
        ls -lh "$OUTPUT_FILE"
      '';
      executable = true;
    };

    # Shell aliases for database operations
    programs.bash.shellAliases = {
      # PostgreSQL aliases
      "pg-start" = "pg_ctl -D ~/postgresql/data -l ~/postgresql/logfile start";
      "pg-stop" = "pg_ctl -D ~/postgresql/data stop";
      "pg-status" = "pg_ctl -D ~/postgresql/data status";
      "pg-logs" = "tail -f ~/postgresql/logfile";

      # MySQL aliases
      "mysql-start" = "brew services start mysql || sudo systemctl start mysql";
      "mysql-stop" = "brew services stop mysql || sudo systemctl stop mysql";
      "mysql-status" = "brew services list mysql || systemctl status mysql";

      # Redis aliases
      "redis-start" = "brew services start redis || sudo systemctl start redis";
      "redis-stop" = "brew services stop redis || sudo systemctl stop redis";
      "redis-cli-local" = "redis-cli -h 127.0.0.1";

      # MongoDB aliases
      "mongo-start" = "brew services start mongodb-community || sudo systemctl start mongod";
      "mongo-stop" = "brew services stop mongodb-community || sudo systemctl stop mongod";

      # Database connection shortcuts
      "pglocal" = "db-connect pg";
      "mylocal" = "db-connect mysql";
      "redislocal" = "db-connect redis";
    };

    programs.zsh.shellAliases = {
      # PostgreSQL aliases
      "pg-start" = "pg_ctl -D ~/postgresql/data -l ~/postgresql/logfile start";
      "pg-stop" = "pg_ctl -D ~/postgresql/data stop";
      "pg-status" = "pg_ctl -D ~/postgresql/data status";
      "pg-logs" = "tail -f ~/postgresql/logfile";

      # MySQL aliases
      "mysql-start" = "brew services start mysql || sudo systemctl start mysql";
      "mysql-stop" = "brew services stop mysql || sudo systemctl stop mysql";
      "mysql-status" = "brew services list mysql || systemctl status mysql";

      # Redis aliases
      "redis-start" = "brew services start redis || sudo systemctl start redis";
      "redis-stop" = "brew services stop redis || sudo systemctl stop redis";
      "redis-cli-local" = "redis-cli -h 127.0.0.1";

      # MongoDB aliases
      "mongo-start" = "brew services start mongodb-community || sudo systemctl start mongod";
      "mongo-stop" = "brew services stop mongodb-community || sudo systemctl stop mongod";

      # Database connection shortcuts
      "pglocal" = "db-connect pg";
      "mylocal" = "db-connect mysql";
      "redislocal" = "db-connect redis";
    };

    # Environment variables for database connections
    home.sessionVariables = {
      # PostgreSQL
      PGHOST = "localhost";
      PGPORT = "5432";
      PGUSER = config.home.username;

      # MySQL
      MYSQL_HOST = "127.0.0.1";
      MYSQL_TCP_PORT = "3306";

      # Redis
      REDIS_URL = "redis://127.0.0.1:6379";

      # MongoDB
      MONGODB_URI = "mongodb://127.0.0.1:27017";
    };

    # Database configuration files
    xdg.configFile = {
      # pgcli configuration
      "pgcli/config" = {
        text = ''
          [main]
          # Multi-line queries
          multi_line = True

          # Syntax highlighting
          syntax_style = native

          # Auto-completion
          smart_completion = True

          # History
          history_file = ~/.local/share/pgcli/history

          # Pager
          enable_pager = True

          [colors]
          # Color scheme
          Token.Menu.Completions.Completion.Current = 'bg:#ffffff #000000'
          Token.Menu.Completions.Completion = 'bg:#008888 #ffffff'
          Token.Menu.Completions.Meta.Current = 'bg:#44aaaa #000000'
          Token.Menu.Completions.Meta = 'bg:#448888 #ffffff'
          Token.Menu.Completions.MultiColumnMeta = 'bg:#aaffff #000000'
        '';
      };

      # mycli configuration
      "mycli/myclirc" = {
        text = ''
          [main]
          # Multi-line queries
          multi_line = True

          # Syntax highlighting
          syntax_style = native

          # Auto-completion
          smart_completion = True

          # History
          history_file = ~/.local/share/mycli/history

          # Pager
          enable_pager = True

          # Timing
          timing = True

          [colors]
          # Color scheme for MySQL
          Token.Menu.Completions.Completion.Current = 'bg:#ffffff #000000'
          Token.Menu.Completions.Completion = 'bg:#008888 #ffffff'
        '';
      };

      # litecli (SQLite) configuration
      "litecli/config" = {
        text = ''
          [main]
          # Multi-line queries
          multi_line = True

          # Syntax highlighting
          syntax_style = native

          # Auto-completion
          smart_completion = True

          # History
          history_file = ~/.local/share/litecli/history

          # Show table format
          table_format = fancy_grid

          # Timing
          timing = True
        '';
      };
    };

    # Database utility functions for interactive shells
    programs.bash.initExtra = ''
      # Database utility functions
      db_quick_setup() {
        echo "Setting up local development databases..."

        # PostgreSQL setup
        if command -v initdb >/dev/null 2>&1; then
          if [[ ! -d ~/postgresql/data ]]; then
            mkdir -p ~/postgresql
            initdb -D ~/postgresql/data
            echo "PostgreSQL data directory initialized"
          fi
        fi

        echo "Database setup complete!"
        echo "Use aliases: pg-start, mysql-start, redis-start"
      }

      db_migrate() {
        local tool="''${1:-flyway}"
        local action="''${2:-migrate}"

        case $tool in
          flyway)
            if [[ -f flyway.conf ]]; then
              flyway "$action"
            else
              echo "No flyway.conf found in current directory"
              return 1
            fi
            ;;
          liquibase)
            if [[ -f liquibase.properties ]]; then
              liquibase "$action"
            else
              echo "No liquibase.properties found in current directory"
              return 1
            fi
            ;;
          dbmate)
            dbmate "$action"
            ;;
          *)
            echo "Unsupported migration tool: $tool"
            echo "Supported: flyway, liquibase, dbmate"
            return 1
            ;;
        esac
      }
    '';

    programs.zsh.initExtra = ''
      # Database utility functions
      db_quick_setup() {
        echo "Setting up local development databases..."

        # PostgreSQL setup
        if command -v initdb >/dev/null 2>&1; then
          if [[ ! -d ~/postgresql/data ]]; then
            mkdir -p ~/postgresql
            initdb -D ~/postgresql/data
            echo "PostgreSQL data directory initialized"
          fi
        fi

        echo "Database setup complete!"
        echo "Use aliases: pg-start, mysql-start, redis-start"
      }

      db_migrate() {
        local tool="''${1:-flyway}"
        local action="''${2:-migrate}"

        case $tool in
          flyway)
            if [[ -f flyway.conf ]]; then
              flyway "$action"
            else
              echo "No flyway.conf found in current directory"
              return 1
            fi
            ;;
          liquibase)
            if [[ -f liquibase.properties ]]; then
              liquibase "$action"
            else
              echo "No liquibase.properties found in current directory"
              return 1
            fi
            ;;
          dbmate)
            dbmate "$action"
            ;;
          *)
            echo "Unsupported migration tool: $tool"
            echo "Supported: flyway, liquibase, dbmate"
            return 1
            ;;
        esac
      }
    '';
  };
}
