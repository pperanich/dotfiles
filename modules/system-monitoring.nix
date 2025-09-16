_: {
  flake.modules.nixos.systemMonitoring = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # System-level monitoring tools and services
    environment.systemPackages = with pkgs; [
      # Process monitoring
      htop
      btop
      procps # provides ps, top

      # Resource usage monitoring
      iotop
      nethogs
      bandwhich
      iftop

      # Disk analysis
      ncdu
      dust
      duf

      # Network monitoring
      iproute2 # provides ss
      net-tools # provides netstat
      nmap
      tcpdump

      # Performance analysis
      linuxPackages.perf
      strace
      lsof
      pstree

      # System information
      neofetch
      inxi
      pciutils # provides lspci
      usbutils # provides lsusb
      dmidecode # hardware info

      # Log monitoring
      lnav
      multitail

      # GPU monitoring (Linux)
      nvtop # NVIDIA GPUs
      radeontop # AMD GPUs
    ];

    # Enable performance monitoring
    boot.kernel.sysctl = {
      "kernel.perf_event_paranoid" = 1; # Allow perf for regular users
    };

    # System monitoring services
    services.vnstat.enable = true; # Network traffic statistics

    # Enable hardware sensors
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Kernel modules for hardware monitoring
    boot.kernelModules = [
      "coretemp" # CPU temperature
      "k10temp" # AMD CPU temperature
    ];

    # System resource limits for monitoring tools
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "65536";
      }
    ];
  };

  flake.modules.darwin.systemMonitoring = {pkgs, ...}: {
    # macOS system monitoring packages
    environment.systemPackages = with pkgs; [
      # Process monitoring
      htop
      btop

      # Network monitoring
      bandwhich
      nmap

      # Disk analysis
      ncdu
      dust
      duf

      # Performance analysis (macOS compatible)
      lsof
      pstree

      # System information
      neofetch

      # Log monitoring
      lnav
      multitail
    ];

    # macOS-specific monitoring via Homebrew
    homebrew.brews = [
      "iftop" # Network bandwidth usage
      "nethogs" # Per-process network usage
    ];

    homebrew.casks = [
      "activity-monitor" # Enhanced Activity Monitor
      "istats" # System stats in menu bar
    ];
  };

  flake.modules.homeModules.systemMonitoring = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # User-level monitoring tools and configurations
    home.packages = with pkgs;
      [
        # Terminal-based monitoring
        htop
        btop
        bottom # Alternative to htop/btop

        # Disk utilities
        ncdu
        dust
        duf

        # Network monitoring
        bandwhith

        # System information
        neofetch
        fastfetch # Faster alternative to neofetch

        # Log analysis
        lnav
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific monitoring tools
        iotop
        nethogs
        iftop
        nvtop
        radeontop

        # Performance tools
        strace
        pstree

        # System info
        inxi
      ];

    # Shell integration and aliases
    programs.zsh.shellAliases = lib.mkIf (config.programs.zsh.enable or false) {
      # Process monitoring shortcuts
      "top" = "htop";
      "processes" = "htop";
      "cpu" = "htop --sort-key=PERCENT_CPU";
      "mem" = "htop --sort-key=PERCENT_MEM";

      # Disk usage shortcuts
      "disk" = "duf";
      "diskusage" = "ncdu";
      "du-interactive" = "ncdu";
      "disk-tree" = "dust";

      # Network monitoring
      "network" = "bandwhich";
      "netstat-listening" = "ss -tuln";
      "ports" = "ss -tuln";

      # System information
      "sysinfo" = "neofetch";
      "hwinfo" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "inxi -Fxz";

      # Performance analysis
      "openfiles" = "lsof";
      "proctree" = "pstree";
    };

    programs.bash.shellAliases = lib.mkIf (config.programs.bash.enable or false) {
      # Process monitoring shortcuts
      "top" = "htop";
      "processes" = "htop";
      "cpu" = "htop --sort-key=PERCENT_CPU";
      "mem" = "htop --sort-key=PERCENT_MEM";

      # Disk usage shortcuts
      "disk" = "duf";
      "diskusage" = "ncdu";
      "du-interactive" = "ncdu";
      "disk-tree" = "dust";

      # Network monitoring
      "network" = "bandwhich";
      "netstat-listening" = "ss -tuln";
      "ports" = "ss -tuln";

      # System information
      "sysinfo" = "neofetch";
      "hwinfo" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "inxi -Fxz";

      # Performance analysis
      "openfiles" = "lsof";
      "proctree" = "pstree";
    };

    # System monitoring functions
    programs.zsh.initExtra = lib.mkIf (config.programs.zsh.enable or false) ''
      # System status function
      function sysstatus() {
        echo "=== System Status ==="
        echo
        echo "--- CPU & Memory ---"
        ${pkgs.htop}/bin/htop --print-summary 2>/dev/null || echo "htop summary not available"
        echo
        echo "--- Disk Usage ---"
        ${pkgs.duf}/bin/duf
        echo
        echo "--- Network Interfaces ---"
        ${
        if pkgs.stdenv.hostPlatform.isLinux
        then "${pkgs.iproute2}/bin/ss -i"
        else "netstat -i"
      }
        echo
        echo "--- System Load ---"
        uptime
        echo
        echo "--- Top Processes by CPU ---"
        ${pkgs.procps}/bin/ps aux --sort=-%cpu | head -10
      }

      # Performance monitoring function
      function perfmon() {
        local duration=''${1:-30}
        echo "Starting performance monitoring for $duration seconds..."
        echo "Press Ctrl+C to stop early"

        # Start monitoring in background
        ${pkgs.htop}/bin/htop &
        local htop_pid=$!

        # Wait for specified duration or user interrupt
        sleep "$duration" 2>/dev/null || true

        # Clean up
        kill $htop_pid 2>/dev/null || true
      }

      # Network monitoring function
      function netmon() {
        echo "Network Monitoring - Press 'q' to quit each tool"
        echo
        echo "1. Interface statistics:"
        ${pkgs.bandwhich}/bin/bandwhich --no-resolve
      }

      # Quick system health check
      function healthcheck() {
        echo "=== Quick Health Check ==="
        echo
        echo "System Load: $(uptime | awk -F'load average:' '{print $2}')"
        echo "Memory Usage:"
        free -h 2>/dev/null || vm_stat | grep -E 'Pages (free|active|inactive|speculative|wired)'
        echo "Disk Usage:"
        df -h | grep -E '^/dev/'
        echo "Network Status:"
        ${
        if pkgs.stdenv.hostPlatform.isLinux
        then "${pkgs.iproute2}/bin/ss -tuln | wc -l"
        else "netstat -tuln | wc -l"
      } | xargs echo "Active connections:"
      }
    '';

    programs.bash.initExtra = lib.mkIf (config.programs.bash.enable or false) ''
      # System status function
      sysstatus() {
        echo "=== System Status ==="
        echo
        echo "--- CPU & Memory ---"
        ${pkgs.htop}/bin/htop --print-summary 2>/dev/null || echo "htop summary not available"
        echo
        echo "--- Disk Usage ---"
        ${pkgs.duf}/bin/duf
        echo
        echo "--- Network Interfaces ---"
        ${
        if pkgs.stdenv.hostPlatform.isLinux
        then "${pkgs.iproute2}/bin/ss -i"
        else "netstat -i"
      }
        echo
        echo "--- System Load ---"
        uptime
        echo
        echo "--- Top Processes by CPU ---"
        ${pkgs.procps}/bin/ps aux --sort=-%cpu | head -10
      }

      # Performance monitoring function
      perfmon() {
        local duration=''${1:-30}
        echo "Starting performance monitoring for $duration seconds..."
        echo "Press Ctrl+C to stop early"

        # Start monitoring in background
        ${pkgs.htop}/bin/htop &
        local htop_pid=$!

        # Wait for specified duration or user interrupt
        sleep "$duration" 2>/dev/null || true

        # Clean up
        kill $htop_pid 2>/dev/null || true
      }

      # Quick system health check
      healthcheck() {
        echo "=== Quick Health Check ==="
        echo
        echo "System Load: $(uptime | awk -F'load average:' '{print $2}')"
        echo "Memory Usage:"
        free -h 2>/dev/null || vm_stat | grep -E 'Pages (free|active|inactive|speculative|wired)'
        echo "Disk Usage:"
        df -h | grep -E '^/dev/'
        echo "Network Status:"
        ${
        if pkgs.stdenv.hostPlatform.isLinux
        then "${pkgs.iproute2}/bin/ss -tuln | wc -l"
        else "netstat -tuln | wc -l"
      } | xargs echo "Active connections:"
      }
    '';

    # btop configuration
    xdg.configFile."btop/btop.conf".text = ''
      # btop configuration for system monitoring
      color_theme = "Default"
      theme_background = true
      truecolor = true
      force_tty = false
      presets = "cpu:1:default,proc:1:default mem:1:default,proc:1:default,net:1:default,proc:1:default"
      vim_keys = true
      rounded_corners = true
      graph_symbol = "braille"
      shown_boxes = "cpu mem net proc"
      update_ms = 2000
      proc_sorting = "cpu lazy"
      proc_reversed = false
      proc_tree = false
      proc_colors = true
      proc_gradient = true
      proc_per_core = false
      proc_mem_bytes = true
      proc_info_smaps = false
      proc_left = false
      cpu_graph_upper = "total"
      cpu_graph_lower = "total"
      cpu_invert_lower = true
      cpu_single_graph = false
      cpu_bottom = false
      show_uptime = true
      check_temp = true
      show_coretemp = true
      temp_scale = "celsius"
      show_cpu_freq = true
      mem_graphs = true
      mem_below_net = false
      show_swap = true
      swap_disk = true
      show_disks = true
      only_physical = true
      use_fstab = false
      show_io_stat = true
      io_mode = false
      io_graph_combined = false
      io_graph_speeds = ""
      net_download = 100
      net_upload = 100
      net_auto = true
      net_sync = false
      net_color_fixed = false
      bandwidth_switch = false
      proc_filter_kernel = false
      proc_aggregate = false
    '';

    # htop configuration
    xdg.configFile."htop/htoprc".text = ''
      # htop configuration for system monitoring
      fields=0 48 17 18 38 39 2 46 47 49 1
      sort_key=46
      sort_direction=1
      tree_sort_key=0
      tree_sort_direction=1
      hide_kernel_threads=1
      hide_userland_threads=0
      shadow_other_users=0
      show_thread_names=0
      show_program_path=1
      highlight_base_name=0
      highlight_deleted_exe=1
      highlight_megabytes=1
      highlight_threads=1
      highlight_changes=0
      highlight_changes_delay_secs=5
      find_comm_in_cmdline=1
      strip_exe_from_cmdline=1
      show_merged_command=0
      tree_view=0
      tree_view_always_by_pid=0
      all_branches_collapsed=0
      header_margin=1
      detailed_cpu_time=0
      cpu_count_from_one=0
      show_cpu_usage=1
      show_cpu_frequency=0
      show_cpu_temperature=0
      degree_fahrenheit=0
      update_process_names=0
      account_guest_in_cpu_meter=0
      color_scheme=0
      enable_mouse=1
      delay=15
      hide_function_bar=0
      header_layout=two_50_50
      column_meters_0=LeftCPUs Memory Swap
      column_meter_modes_0=1 1 1
      column_meters_1=RightCPUs Tasks LoadAverage Uptime
      column_meter_modes_1=1 2 2 2
    '';
  };
}
