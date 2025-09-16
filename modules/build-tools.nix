# Comprehensive build systems and compilation tools module
# Provides cross-platform build tools, compilers, and development toolchains
# Supports NixOS, Darwin, and Home Manager configurations
_: {
  # NixOS system configuration for build tools
  flake.modules.nixos.buildTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # System-wide build tools and compilers
    environment.systemPackages = with pkgs;
      [
        # Build systems
        cmake
        meson
        ninja
        autoconf
        automake
        libtool
        pkg-config
        gnumake

        # Compilers and toolchains
        gcc
        clang
        llvm
        binutils

        # Cross-compilation support
        crossenv
        qemu

        # Debugging tools
        gdb
        lldb
        valgrind
        strace
        ltrace

        # Profiling and analysis
        perf-tools
        flamegraph
        cppcheck
        clang-tools

        # Modern make alternatives
        just
        taskfile-go

        # Additional build utilities
        ccache
        distcc
        bear # Generate compilation database
        compiledb
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific build tools
        patchelf
        chrpath
        elfutils
      ];

    # Enable cross-compilation support
    boot.binfmt.emulatedSystems = [
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
      "i686-linux"
    ];

    # System-wide environment for build tools
    environment.variables = {
      # Compiler flags for optimization
      CFLAGS = "-O2 -pipe";
      CXXFLAGS = "-O2 -pipe";

      # Make parallel builds default
      MAKEFLAGS = "-j$(nproc)";

      # Enable ccache by default
      CC = lib.mkDefault "ccache gcc";
      CXX = lib.mkDefault "ccache g++";
    };

    # Configure ccache
    programs.ccache = {
      enable = true;
      cacheDir = "/var/cache/ccache";
    };

    # Kernel modules for profiling
    boot.kernelModules = ["perf_event"];

    # Allow users to use performance counters
    security.wrappers.perf = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin,cap_sys_ptrace+ep";
      source = "${pkgs.linuxPackages.perf}/bin/perf";
    };
  };

  # Home Manager user configuration for build tools
  flake.modules.homeModules.buildTools = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.home) homeDirectory;
  in {
    home.packages = with pkgs;
      [
        # Build systems
        cmake
        meson
        ninja
        autoconf
        automake
        libtool
        pkg-config
        gnumake

        # Compilers (user-space versions)
        gcc
        clang
        llvm

        # Modern make alternatives
        just
        taskfile-go

        # Python-based build tools
        (python3.withPackages (ps:
          with ps; [
            invoke # Python task execution
            scons # Python-based build system
          ]))

        # Analysis and profiling tools
        cppcheck
        clang-tools
        flamegraph
        bear
        compiledb

        # Package managers and dependency tools
        conan
        cmake-language-server

        # Cross-compilation utilities
        crossenv

        # Build optimization
        ccache

        # Documentation generators
        doxygen
        sphinx
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific user tools
        gdb
        valgrind
        strace
        ltrace
        elfutils
        patchelf
        perf-tools
        hotspot # GUI for perf
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific debugging tools
        lldb
        # Note: dtrace available system-wide on macOS
      ];

    # Build tool environment configuration
    home = {
      sessionVariables = {
        # Parallel build configuration
        MAKEFLAGS = "-j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)";

        # Compiler optimization flags
        CFLAGS = "-O2 -pipe";
        CXXFLAGS = "-O2 -pipe";

        # PKG_CONFIG path for local builds
        PKG_CONFIG_PATH = "${homeDirectory}/.local/lib/pkgconfig:${homeDirectory}/.local/share/pkgconfig";

        # CMake configuration
        CMAKE_EXPORT_COMPILE_COMMANDS = "ON";
        CMAKE_BUILD_TYPE = "RelWithDebInfo";

        # ccache configuration
        CCACHE_DIR = "${homeDirectory}/.cache/ccache";
        CCACHE_MAXSIZE = "5G";

        # Conan configuration
        CONAN_USER_HOME = "${homeDirectory}/.conan";
      };

      sessionPath = [
        "${homeDirectory}/.local/bin"
        "${homeDirectory}/.cargo/bin" # For cargo-installed build tools
      ];
    };

    # Shell aliases for build operations
    home.shellAliases = {
      # CMake shortcuts
      "cmake-debug" = "cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON";
      "cmake-release" = "cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON";
      "cmake-clean" = "rm -rf build/ && mkdir build";

      # Meson shortcuts
      "meson-setup" = "meson setup build";
      "meson-compile" = "meson compile -C build";
      "meson-test" = "meson test -C build";

      # Make shortcuts
      "make-clean" = "make clean && make distclean 2>/dev/null || true";
      "make-parallel" = "make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)";

      # Analysis shortcuts
      "cppcheck-strict" = "cppcheck --enable=all --inconclusive --std=c++17";
      "clang-format-fix" = "find . -name '*.cpp' -o -name '*.h' -o -name '*.c' | xargs clang-format -i";

      # Debugging shortcuts
      "gdb-quiet" = "gdb -q";
      "lldb-quiet" = "lldb -o 'settings set prompt.format \"(lldb) \"'";

      # Profiling shortcuts
      "perf-record" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "perf record -g";
      "perf-report" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "perf report -g";
      "flamegraph-perf" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "perf record -g ./your_program && perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg";

      # Cross-compilation helpers
      "cross-aarch64" = "export CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++";
      "cross-arm" = "export CC=arm-linux-gnueabihf-gcc CXX=arm-linux-gnueabihf-g++";

      # Build system detection and execution
      "build" = ''
        if [ -f "Cargo.toml" ]; then
          cargo build
        elif [ -f "CMakeLists.txt" ]; then
          mkdir -p build && cd build && cmake .. && make -j$(nproc 2>/dev/null || echo 4) && cd ..
        elif [ -f "meson.build" ]; then
          meson setup build 2>/dev/null || true && meson compile -C build
        elif [ -f "Makefile" ]; then
          make -j$(nproc 2>/dev/null || echo 4)
        elif [ -f "justfile" ]; then
          just
        elif [ -f "Taskfile.yml" ] || [ -f "taskfile.yml" ]; then
          task
        else
          echo "No recognized build system found"
        fi
      '';

      # Clean build artifacts
      "clean-build" = ''
        rm -rf build/ dist/ target/ __pycache__/ *.egg-info/ .pytest_cache/ node_modules/
        find . -name "*.o" -o -name "*.so" -o -name "*.dylib" -o -name "*.a" | head -20 | xargs rm -f 2>/dev/null || true
      '';
    };

    # Build tool shell functions
    programs.zsh.initExtra = lib.mkIf (config.programs.zsh.enable or false) ''
      # Function to set up a new C++ project with CMake
      setup_cpp_project() {
        local project_name=''${1:-"cpp_project"}
        mkdir -p "$project_name"/{src,include,tests,build}

        cat > "$project_name/CMakeLists.txt" << 'EOF'
      cmake_minimum_required(VERSION 3.20)
      project(''${project_name} VERSION 1.0.0)

      set(CMAKE_CXX_STANDARD 17)
      set(CMAKE_CXX_STANDARD_REQUIRED ON)
      set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

      include_directories(include)

      add_executable(''${project_name} src/main.cpp)

      # Tests
      enable_testing()
      add_subdirectory(tests)
      EOF

        cat > "$project_name/src/main.cpp" << 'EOF'
      #include <iostream>

      int main() {
          std::cout << "Hello, World!" << std::endl;
          return 0;
      }
      EOF

        echo "Created C++ project: $project_name"
        echo "Run: cd $project_name && mkdir build && cd build && cmake .. && make"
      }

      # Function to benchmark build times
      build_benchmark() {
        echo "Benchmarking build system..."
        if [ -f "CMakeLists.txt" ]; then
          echo "CMake build:"
          time (mkdir -p build && cd build && cmake .. && make -j$(nproc 2>/dev/null || echo 4))
        elif [ -f "meson.build" ]; then
          echo "Meson build:"
          time (meson setup build 2>/dev/null || true && meson compile -C build)
        elif [ -f "Makefile" ]; then
          echo "Make build:"
          time make -j$(nproc 2>/dev/null || echo 4)
        fi
      }

      # Function to generate compilation database
      gen_compile_commands() {
        if [ -f "CMakeLists.txt" ]; then
          mkdir -p build && cd build && cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .. && cd ..
          ln -sf build/compile_commands.json .
        elif [ -f "Makefile" ]; then
          bear -- make
        else
          echo "No supported build system found for compilation database generation"
        fi
      }
    '';

    # Configure ccache for user builds
    xdg.configFile."ccache/ccache.conf".text = ''
      max_size = 5.0G
      compression = true
      compression_level = 6
      cache_dir = ${homeDirectory}/.cache/ccache
      stats = true
    '';

    # Conan configuration
    xdg.configFile."conan/global.conf".text = ''
      tools.system.package_manager:mode=install
      tools.system.package_manager:sudo=True
    '';
  };

  # Darwin (macOS) system configuration for build tools
  flake.modules.darwin.buildTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Install development tools via Nix that work well on macOS
    environment.systemPackages = with pkgs; [
      # Core build tools
      cmake
      meson
      ninja
      pkg-config
      gnumake
      autoconf
      automake
      libtool

      # LLVM toolchain (Apple's preferred)
      llvm
      clang
      clang-tools

      # Cross-platform tools
      just
      taskfile-go

      # Analysis tools
      cppcheck

      # Build optimization
      ccache

      # macOS-specific debugging
      lldb
    ];

    # Homebrew for tools that integrate better via Homebrew
    homebrew = {
      brews = [
        # Xcode command line tools are installed separately
        "gcc" # GNU compiler as alternative to clang

        # Package managers
        "conan"

        # Additional development tools
        "bear" # May have better macOS integration via homebrew
      ];

      casks = [
        "xcode" # Full Xcode IDE (optional)
        # "visual-studio-code" # Popular IDE for cross-platform development
      ];
    };

    # macOS-specific build environment
    environment.variables = {
      # Prefer clang on macOS
      CC = lib.mkDefault "clang";
      CXX = lib.mkDefault "clang++";

      # macOS SDK configuration
      MACOSX_DEPLOYMENT_TARGET = "10.15";

      # Build flags optimized for Apple Silicon and Intel
      CFLAGS = "-O2 -pipe";
      CXXFLAGS = "-O2 -pipe";

      # Parallel builds
      MAKEFLAGS = "-j$(sysctl -n hw.ncpu)";

      # PKG_CONFIG paths for Homebrew and Nix integration
      PKG_CONFIG_PATH = lib.concatStringsSep ":" [
        "${pkgs.openssl.dev}/lib/pkgconfig"
        "${pkgs.libiconv}/lib/pkgconfig"
        "/opt/homebrew/lib/pkgconfig"
        "/usr/local/lib/pkgconfig"
      ];

      # Library and include paths
      LIBRARY_PATH = lib.concatStringsSep ":" [
        "${pkgs.libiconv}/lib"
        "${pkgs.openssl.out}/lib"
        "/opt/homebrew/lib"
        "/usr/local/lib"
      ];

      CPATH = lib.concatStringsSep ":" [
        "${pkgs.libiconv}/include"
        "${pkgs.openssl.dev}/include"
        "/opt/homebrew/include"
        "/usr/local/include"
      ];
    };

    # System-wide configuration for development
    system = {
      # Allow installation of packages from anywhere
      defaults.GlobalPreferences."com.apple.security.quarantine" = false;

      # Reduce Gatekeeper restrictions for development
      defaults.LaunchServices.LSQuarantine = false;
    };

    # Configure build-related launch daemons if needed
    launchd.daemons = lib.mkIf false {
      # Disabled by default
      ccache-cleanup = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.ccache}/bin/ccache"
            "--cleanup"
          ];
          StartCalendarInterval = {
            Hour = 2;
            Minute = 0;
          };
          StandardOutPath = "/var/log/ccache-cleanup.log";
          StandardErrorPath = "/var/log/ccache-cleanup.log";
        };
      };
    };

    # Ensure Xcode license is accepted for command line tools
    system.activationScripts.extraActivation.text = ''
      if xcode-select -p >/dev/null 2>&1 && ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        echo "Note: Xcode license may need to be accepted. Run: sudo xcodebuild -license accept"
      fi
    '';
  };
}
