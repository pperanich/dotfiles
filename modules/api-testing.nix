_: {
  # NixOS system-level API testing support
  flake.modules.nixos.apiTesting = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      # System-level network testing capabilities
      curl
      wget
      wireshark
      tcpdump
      nmap
      netcat-gnu

      # gRPC system tools
      grpc-gateway
      protobuf

      # Load testing infrastructure
      wrk
      siege

      # System monitoring for API performance
      htop
      iotop
      nethogs
    ];

    # Enable system-wide networking features for API testing
    programs.wireshark.enable = true;

    # Firewall rules for local API development
    networking.firewall = {
      allowedTCPPorts = [
        3000 # Common dev server port
        3001 # Alternative dev port
        8080 # Common API port
        8000 # Alternative API port
        9000 # Common mock server port
        4000 # GraphQL playground
        5000 # Common Flask/testing port
      ];

      allowedTCPPortRanges = [
        # Port range for dynamic API testing
        {
          from = 8080;
          to = 8090;
        }
        {
          from = 3000;
          to = 3010;
        }
      ];
    };

    # System-level performance tuning for API testing
    boot.kernel.sysctl = {
      # Increase connection limits for load testing
      "net.core.somaxconn" = 65535;
      "net.ipv4.ip_local_port_range" = "1024 65535";
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.core.netdev_max_backlog" = 5000;
    };
  };

  # Darwin system-level API testing support
  flake.modules.darwin.apiTesting = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      # Darwin-specific network tools
      curl
      wget

      # Protocol buffers
      protobuf

      # System monitoring
      htop
    ];

    # Darwin-specific homebrew packages for API testing
    homebrew = {
      brews = [
        # Native macOS API testing tools
        "grpcui" # gRPC web UI
        "charles" # HTTP proxy/debugger (if using homebrew)
      ];

      casks = [
        "postman" # Popular API testing GUI
        "insomnia" # Alternative API client
        "proxyman" # HTTP debugging proxy
        "wireshark" # Network protocol analyzer
        "mockoon" # API mocking tool
      ];
    };

    # Allow API testing ports through macOS firewall
    system.defaults.alf = {
      allowsignedenabled = 1;
      allowdownloadsignedenabled = 1;
    };
  };

  # Home Manager configuration for API testing tools
  flake.modules.homeModules.apiTesting = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # API testing aliases and functions
    apiAliases = {
      # HTTP client shortcuts
      "http" = "${pkgs.httpie}/bin/http";
      "https" = "${pkgs.httpie}/bin/https";
      "curl-json" = "curl -H 'Content-Type: application/json'";
      "curl-time" = "curl -w '@${pkgs.writeText "curl-format.txt" ''
        time_namelookup:  %{time_namelookup}s\n
        time_connect:     %{time_connect}s\n
        time_appconnect:  %{time_appconnect}s\n
        time_pretransfer: %{time_pretransfer}s\n
        time_redirect:    %{time_redirect}s\n
        time_starttransfer: %{time_starttransfer}s\n
        time_total:       %{time_total}s\n
      ''}'";

      # gRPC shortcuts
      "grpc-ls" = "${pkgs.grpcurl}/bin/grpcurl -plaintext";
      "grpc-desc" = "${pkgs.grpcurl}/bin/grpcurl -plaintext describe";

      # Load testing shortcuts
      "load-test" = "${pkgs.k6}/bin/k6 run";
      "stress-test" = "${pkgs.artillery}/bin/artillery run";
      "quick-bench" = "${pkgs.wrk}/bin/wrk -t12 -c400 -d30s";

      # API documentation
      "api-docs" = "${pkgs.swagger-ui}/bin/swagger-ui-serve";
      "redoc" = "${pkgs.redoc-cli}/bin/redoc-cli";

      # Mock servers
      "mock-api" = "${pkgs.json-server}/bin/json-server --watch";
      "mock-rest" = "${pkgs.json-server}/bin/json-server --routes routes.json --watch";
    };

    # API testing shell functions
    apiShellFunctions = ''
      # Quick API health check
      api_health() {
        local url="''${1:-http://localhost:3000/health}"
        echo "🔍 Checking API health: $url"
        curl -s -f -o /dev/null "$url" && echo "✅ API is healthy" || echo "❌ API is down"
      }

      # Test API endpoint with different methods
      api_test() {
        local url="$1"
        local method="''${2:-GET}"
        local data="''${3:-}"

        echo "🚀 Testing $method $url"
        if [[ -n "$data" ]]; then
          http "$method" "$url" --json --body <<< "$data"
        else
          http "$method" "$url"
        fi
      }

      # Generate API test template
      api_template() {
        local name="''${1:-api-test}"
        cat > "''${name}.http" << 'EOF'
      ### API Test Template
      # Variables
      @baseUrl = http://localhost:3000
      @contentType = application/json

      ### Health Check
      GET {{baseUrl}}/health

      ### List Items
      GET {{baseUrl}}/api/items
      Accept: {{contentType}}

      ### Create Item
      POST {{baseUrl}}/api/items
      Content-Type: {{contentType}}

      {
        "name": "Test Item",
        "description": "Created via API test"
      }

      ### Get Item by ID
      GET {{baseUrl}}/api/items/1
      Accept: {{contentType}}

      ### Update Item
      PUT {{baseUrl}}/api/items/1
      Content-Type: {{contentType}}

      {
        "name": "Updated Item",
        "description": "Modified via API test"
      }

      ### Delete Item
      DELETE {{baseUrl}}/api/items/1
      EOF
        echo "📝 Created API test template: ''${name}.http"
      }

      # Quick load test
      api_load() {
        local url="$1"
        local duration="''${2:-30s}"
        local connections="''${3:-100}"

        echo "⚡ Load testing $url for $duration with $connections connections"
        wrk -t12 -c"$connections" -d"$duration" --latency "$url"
      }

      # GraphQL introspection
      gql_introspect() {
        local url="''${1:-http://localhost:4000/graphql}"
        echo "🔍 GraphQL introspection for: $url"
        curl -X POST \
          -H "Content-Type: application/json" \
          -d '{"query":"query IntrospectionQuery { __schema { queryType { name } mutationType { name } subscriptionType { name } types { ...FullType } directives { name description locations args { ...InputValue } } } } fragment FullType on __Type { kind name description fields(includeDeprecated: true) { name description args { ...InputValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { ...InputValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } fragment InputValue on __InputValue { name description type { ...TypeRef } defaultValue } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }"}' \
          "$url" | jq '.'
      }

      # Create OpenAPI spec template
      openapi_template() {
        local name="''${1:-api}"
        cat > "''${name}-spec.yaml" << 'EOF'
      openapi: 3.0.3
      info:
        title: API Specification
        description: Auto-generated API specification template
        version: 1.0.0
        contact:
          name: API Team
          email: api@example.com
        license:
          name: MIT
          url: https://opensource.org/licenses/MIT

      servers:
        - url: http://localhost:3000
          description: Development server
        - url: https://api.example.com
          description: Production server

      paths:
        /health:
          get:
            summary: Health check endpoint
            operationId: healthCheck
            tags:
              - Health
            responses:
              '200':
                description: API is healthy
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        status:
                          type: string
                          example: healthy
                        timestamp:
                          type: string
                          format: date-time

        /api/items:
          get:
            summary: List all items
            operationId: listItems
            tags:
              - Items
            parameters:
              - name: limit
                in: query
                description: Maximum number of items to return
                schema:
                  type: integer
                  minimum: 1
                  maximum: 100
                  default: 20
            responses:
              '200':
                description: List of items
                content:
                  application/json:
                    schema:
                      type: array
                      items:
                        $ref: '#/components/schemas/Item'

          post:
            summary: Create a new item
            operationId: createItem
            tags:
              - Items
            requestBody:
              required: true
              content:
                application/json:
                  schema:
                    $ref: '#/components/schemas/ItemCreate'
            responses:
              '201':
                description: Item created successfully
                content:
                  application/json:
                    schema:
                      $ref: '#/components/schemas/Item'

      components:
        schemas:
          Item:
            type: object
            required:
              - id
              - name
            properties:
              id:
                type: integer
                example: 1
              name:
                type: string
                example: "Sample Item"
              description:
                type: string
                example: "This is a sample item"
              createdAt:
                type: string
                format: date-time

          ItemCreate:
            type: object
            required:
              - name
            properties:
              name:
                type: string
                example: "New Item"
              description:
                type: string
                example: "Description of the new item"

        responses:
          NotFound:
            description: Resource not found
          BadRequest:
            description: Bad request
          InternalServerError:
            description: Internal server error
      EOF
        echo "📋 Created OpenAPI spec template: ''${name}-spec.yaml"
      }

      # Quick API mock server
      api_mock() {
        local port="''${1:-3000}"
        local file="''${2:-db.json}"

        if [[ ! -f "$file" ]]; then
          cat > "$file" << 'EOF'
      {
        "users": [
          { "id": 1, "name": "John Doe", "email": "john@example.com" },
          { "id": 2, "name": "Jane Smith", "email": "jane@example.com" }
        ],
        "posts": [
          { "id": 1, "title": "Hello World", "author": 1 },
          { "id": 2, "title": "API Testing", "author": 2 }
        ],
        "comments": [
          { "id": 1, "body": "Great post!", "postId": 1 }
        ]
      }
      EOF
          echo "📄 Created mock data file: $file"
        fi

        echo "🚀 Starting mock API server on port $port"
        json-server --watch "$file" --port "$port"
      }

      # WebSocket testing
      ws_test() {
        local url="''${1:-ws://localhost:8080/ws}"
        echo "🔌 Testing WebSocket connection: $url"
        websocat "$url"
      }

      # API performance analysis
      api_perf() {
        local url="$1"
        local requests="''${2:-1000}"
        local concurrency="''${3:-50}"

        echo "📊 Performance testing $url"
        echo "Requests: $requests, Concurrency: $concurrency"

        hey -n "$requests" -c "$concurrency" -m GET "$url"
      }

      # Protocol buffer compilation helper
      proto_compile() {
        local proto_file="$1"
        local output_dir="''${2:-.}"

        if [[ -z "$proto_file" ]]; then
          echo "Usage: proto_compile <proto_file> [output_dir]"
          return 1
        fi

        echo "🔨 Compiling protocol buffer: $proto_file"
        protoc --go_out="$output_dir" --go-grpc_out="$output_dir" "$proto_file"
      }
    '';
  in {
    home.packages = with pkgs;
      [
        # HTTP clients and tools
        httpie # Modern HTTP client
        curl # Traditional HTTP client
        wget # File downloader
        xh # Fast HTTP client (Rust-based)
        curlie # Frontend for curl with httpie syntax
        hurl # HTTP runner with plain text format

        # API testing and automation
        newman # Postman CLI runner
        artillery # Load testing toolkit
        k6 # Modern load testing tool
        wrk # HTTP benchmarking tool

        # GraphQL tools
        graphql-cli # GraphQL command line interface
        # Note: apollo-cli not available in nixpkgs, would need overlay

        # gRPC tools
        grpcurl # cURL for gRPC services
        grpc-gateway # gRPC to REST gateway
        buf # Protocol buffer toolkit

        # OpenAPI/Swagger tools
        openapi-generator-cli # Generate code from OpenAPI specs
        swagger-codegen3 # Alternative OpenAPI code generator

        # Mock servers and testing
        json-server # Create REST API from JSON
        # wiremock - not in nixpkgs, would need custom derivation
        # mockoon-cli - not in nixpkgs, would need custom derivation

        # Load testing tools
        hey # HTTP load generator
        siege # HTTP stress tester
        vegeta # HTTP load testing tool

        # API documentation
        redoc-cli # ReDoc CLI for OpenAPI docs
        # swagger-ui - available as swagger-ui

        # Protocol testing
        protobuf # Protocol buffers compiler
        grpc-tools # Additional gRPC tools

        # WebSocket testing
        websocat # WebSocket client
        # wscat not directly available, but websocat is better

        # Additional utilities
        jq # JSON processor
        yq # YAML/JSON processor
        httpstat # Visualize HTTP request timing

        # Network analysis
        nmap # Network discovery
        netcat-gnu # Network utility
        tcpdump # Network packet analyzer

        # Development servers
        python3 # For simple HTTP servers
        nodejs # For npm-based tools
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific tools
        wireshark # Network protocol analyzer
        iotop # I/O monitoring
        nethogs # Network usage monitor
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific tools may be installed via homebrew in darwin module
      ];

    # Shell integration
    programs.bash.shellAliases = apiAliases;
    programs.zsh.shellAliases = apiAliases;
    programs.fish.shellAliases = apiAliases;

    # Shell functions for all shells
    programs.bash.initExtra = apiShellFunctions;
    programs.zsh.initExtra = apiShellFunctions;

    # Fish shell functions
    programs.fish.functions = {
      api_health = ''
        set url (test -n "$argv[1]"; and echo $argv[1]; or echo "http://localhost:3000/health")
        echo "🔍 Checking API health: $url"
        if curl -s -f -o /dev/null "$url"
          echo "✅ API is healthy"
        else
          echo "❌ API is down"
        end
      '';

      api_test = ''
        set url $argv[1]
        set method (test -n "$argv[2]"; and echo $argv[2]; or echo "GET")
        set data (test -n "$argv[3]"; and echo $argv[3]; or echo "")

        echo "🚀 Testing $method $url"
        if test -n "$data"
          echo $data | http $method $url --json
        else
          http $method $url
        end
      '';
    };

    # VS Code extensions for API development
    programs.vscode.extensions = with pkgs.vscode-extensions; [
      ms-vscode.vscode-json # JSON language support
      redhat.vscode-yaml # YAML language support
      ms-vscode.rest-client # REST client for VS Code
      # Additional extensions would need to be added to nixpkgs or installed manually
    ];

    # Git configuration for API projects
    programs.git.includes = [
      {
        condition = "gitdir:**/api*/";
        contents = {
          core.hooksPath = ".githooks";
          # API-specific git configuration
        };
      }
    ];

    # XDG configuration files
    xdg.configFile = {
      # Hurl configuration
      "hurl/hurl.conf".text = ''
        # Hurl configuration for API testing
        [options]
        verbose = true
        include = true
        location = true
        compressed = true
        max-time = 30
      '';

      # Artillery configuration template
      "artillery/config.yaml".text = ''
        config:
          target: http://localhost:3000
          phases:
            - duration: 60
              arrivalRate: 10
              name: "Warm up"
            - duration: 300
              arrivalRate: 50
              name: "Sustained load"
          defaults:
            headers:
              Content-Type: application/json
        scenarios:
          - name: "API Health Check"
            weight: 10
            flow:
              - get:
                  url: "/health"
                  expect:
                    - statusCode: 200

          - name: "CRUD Operations"
            weight: 90
            flow:
              - get:
                  url: "/api/items"
              - post:
                  url: "/api/items"
                  json:
                    name: "Test Item {{ $randomString() }}"
                    description: "Created during load test"
                  capture:
                    - json: "$.id"
                      as: "itemId"
              - get:
                  url: "/api/items/{{ itemId }}"
              - delete:
                  url: "/api/items/{{ itemId }}"
      '';

      # K6 configuration template
      "k6/config.js".text = ''
        import http from 'k6/http';
        import { check, sleep } from 'k6';

        export let options = {
          stages: [
            { duration: '1m', target: 10 },   // Ramp up
            { duration: '3m', target: 50 },   // Stay at 50 users
            { duration: '1m', target: 100 },  // Ramp to 100 users
            { duration: '3m', target: 100 },  // Stay at 100 users
            { duration: '1m', target: 0 },    // Ramp down
          ],
          thresholds: {
            http_req_duration: ['p(95)<200'], // 95% of requests under 200ms
            http_req_failed: ['rate<0.1'],    // Error rate under 10%
          },
        };

        const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

        export default function() {
          // Health check
          let healthResponse = http.get(`''${BASE_URL}/health`);
          check(healthResponse, {
            'Health check status is 200': (r) => r.status === 200,
          });

          // API operations
          let itemsResponse = http.get(`''${BASE_URL}/api/items`);
          check(itemsResponse, {
            'Items list status is 200': (r) => r.status === 200,
            'Items response time < 100ms': (r) => r.timings.duration < 100,
          });

          sleep(1);
        }
      '';
    };

    # Environment variables for API testing
    home.sessionVariables = {
      # Default API testing configuration
      API_TEST_TIMEOUT = "30";
      API_TEST_RETRIES = "3";
      HURL_CONFIG = "${config.xdg.configHome}/hurl/hurl.conf";
      K6_CONFIG = "${config.xdg.configHome}/k6/config.js";
      ARTILLERY_CONFIG = "${config.xdg.configHome}/artillery/config.yaml";

      # Protocol buffer paths
      PROTOC_INCLUDE_PATH = "${pkgs.protobuf}/include";
    };

    # Development templates
    xdg.dataFile = {
      "templates/api-test/README.md".text = ''
        # API Testing Project Template

        This template provides a comprehensive setup for API testing with various tools.

        ## Available Tools

        - **HTTP Clients**: httpie, curl, xh, curlie, hurl
        - **Load Testing**: k6, artillery, wrk, hey, vegeta, siege
        - **gRPC Testing**: grpcurl, buf, grpc-tools
        - **Mock Servers**: json-server
        - **Documentation**: redoc-cli, openapi-generator

        ## Quick Start

        1. Health check: `api_health http://localhost:3000/health`
        2. Create test template: `api_template my-api`
        3. Start mock server: `api_mock 3000 db.json`
        4. Load test: `api_load http://localhost:3000/api/items`

        ## Configuration Files

        - Hurl: `~/.config/hurl/hurl.conf`
        - K6: `~/.config/k6/config.js`
        - Artillery: `~/.config/artillery/config.yaml`
      '';

      "templates/api-test/package.json".text = ''
        {
          "name": "api-testing-project",
          "version": "1.0.0",
          "description": "API testing project template",
          "scripts": {
            "test": "k6 run tests/load-test.js",
            "test:artillery": "artillery run tests/artillery-config.yaml",
            "mock": "json-server --watch db.json --port 3000",
            "docs": "redoc-cli serve api-spec.yaml"
          },
          "keywords": ["api", "testing", "performance"],
          "author": "",
          "license": "MIT"
        }
      '';
    };
  };
}
