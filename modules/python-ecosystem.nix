_: {
  # NixOS system-level Python ecosystem configuration
  flake.modules.nixos.pythonEcosystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      # Python interpreters
      python3
      python311
      python312

      # System-level development headers and libraries
      python3Packages.pip
      python3Packages.setuptools
      python3Packages.wheel

      # Development libraries for native extensions
      python3Packages.cython
      zlib
      openssl
      libffi
      sqlite

      # System debugging tools
      python3Packages.gdb
    ];

    # System environment variables
    environment.variables = {
      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONUNBUFFERED = "1";
      PIP_DISABLE_PIP_VERSION_CHECK = "1";
    };

    # Enable development tools system-wide
    programs.python3 = {
      enable = true;
      package = pkgs.python3;
    };
  };

  # macOS system-level Python ecosystem configuration
  flake.modules.darwin.pythonEcosystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      # Python interpreters
      python3
      python311
      python312

      # macOS-specific development dependencies
      python3Packages.pip
      python3Packages.setuptools
      python3Packages.wheel

      # Framework dependencies for macOS
      darwin.apple_sdk.frameworks.SystemConfiguration
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.Security

      # Development libraries
      zlib
      openssl
      libffi
      sqlite
    ];

    # System environment variables
    environment.variables = {
      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONUNBUFFERED = "1";
      PIP_DISABLE_PIP_VERSION_CHECK = "1";
      # macOS-specific Python framework paths
      DYLD_FRAMEWORK_PATH = lib.makeSearchPath "lib" [
        pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
        pkgs.darwin.apple_sdk.frameworks.Security
      ];
    };

    # Homebrew Python versions (complementary to Nix)
    homebrew.brews = [
      "python@3.11"
      "python@3.12"
      "pyenv"
    ];
  };

  # Home Manager Python ecosystem configuration (cross-platform)
  flake.modules.homeModules.pythonEcosystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # Package managers
        python3Packages.pip
        python3Packages.pipx
        poetry
        uv
        pdm

        # Virtual environment management
        python3Packages.virtualenv
        python3Packages.pipenv

        # Code formatting and linting
        python3Packages.black
        ruff
        python3Packages.isort
        python3Packages.mypy
        python3Packages.flake8
        python3Packages.pylint
        python3Packages.autopep8
        python3Packages.yapf

        # Jupyter ecosystem
        python3Packages.jupyter
        python3Packages.jupyterlab
        python3Packages.notebook
        python3Packages.ipython
        python3Packages.ipywidgets
        python3Packages.nbconvert
        python3Packages.nbformat

        # Testing frameworks
        python3Packages.pytest
        python3Packages.pytest-cov
        python3Packages.pytest-mock
        python3Packages.pytest-xdist
        python3Packages.tox
        python3Packages.coverage

        # Documentation tools
        python3Packages.sphinx
        python3Packages.mkdocs
        python3Packages.mkdocs-material
        python3Packages.pdoc3

        # Debugging tools
        python3Packages.ipdb
        python3Packages.pudb
        python3Packages.pdb-clone

        # Development utilities
        python3Packages.pre-commit
        python3Packages.bandit
        python3Packages.safety
        python3Packages.twine
        python3Packages.build

        # Data science essentials (commonly used)
        python3Packages.numpy
        python3Packages.pandas
        python3Packages.matplotlib
        python3Packages.requests
        python3Packages.pyyaml
        python3Packages.toml
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific Python packages
        python3Packages.python-dbus
        python3Packages.pygobject3
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific Python packages
        python3Packages.pyobjc
        python3Packages.pyobjc-core
      ];

    # Python-related programs configuration
    programs = {
      # Configure pip
      # Note: Home Manager doesn't have direct pip support, handled via shell config

      # Configure Poetry if using shell integration
      zsh.initExtra = lib.mkAfter ''
        # Poetry shell completion
        if command -v poetry >/dev/null 2>&1; then
          eval "$(poetry completions zsh)"
        fi

        # pipx shell completion
        if command -v pipx >/dev/null 2>&1; then
          eval "$(register-python-argcomplete pipx)"
        fi
      '';

      bash.initExtra = lib.mkAfter ''
        # Poetry shell completion
        if command -v poetry >/dev/null 2>&1; then
          eval "$(poetry completions bash)"
        fi

        # pipx shell completion
        if command -v pipx >/dev/null 2>&1; then
          eval "$(register-python-argcomplete pipx)"
        fi
      '';
    };

    # Shell aliases for common Python operations
    home.shellAliases = {
      # Python version management
      "py" = "python3";
      "py3" = "python3";
      "python" = "python3";

      # Package management
      "pip" = "python3 -m pip";
      "pipi" = "python3 -m pip install";
      "pipu" = "python3 -m pip install --upgrade";
      "pipun" = "python3 -m pip uninstall";
      "pipls" = "python3 -m pip list";
      "pipshow" = "python3 -m pip show";
      "pipfreeze" = "python3 -m pip freeze";

      # Virtual environment shortcuts
      "venv" = "python3 -m venv";
      "activate" = "source ./venv/bin/activate || source ./.venv/bin/activate";
      "deactivate" = "deactivate";

      # Poetry shortcuts
      "poe" = "poetry";
      "poerun" = "poetry run";
      "poesh" = "poetry shell";
      "poeins" = "poetry install";
      "poeadd" = "poetry add";
      "poerm" = "poetry remove";

      # Testing shortcuts
      "pytest" = "python3 -m pytest";
      "pyt" = "python3 -m pytest";
      "pytv" = "python3 -m pytest -v";
      "pytcov" = "python3 -m pytest --cov";

      # Code quality
      "black" = "python3 -m black";
      "isort" = "python3 -m isort";
      "mypy" = "python3 -m mypy";
      "flake8" = "python3 -m flake8";
      "ruff" = "ruff";

      # Jupyter shortcuts
      "jlab" = "jupyter lab";
      "jnb" = "jupyter notebook";
      "ipy" = "ipython";

      # Documentation
      "mkdocs" = "python3 -m mkdocs";
      "sphinx" = "python3 -m sphinx";
    };

    # Environment variables for Python development
    home.sessionVariables = {
      # Python behavior
      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONUNBUFFERED = "1";
      PIP_DISABLE_PIP_VERSION_CHECK = "1";
      PIP_USER = "1";

      # Virtual environment discovery
      PIPENV_VENV_IN_PROJECT = "1";
      POETRY_VENV_IN_PROJECT = "true";

      # Development paths
      PYTHONPATH = "$HOME/.local/lib/python3.11/site-packages:$HOME/.local/lib/python3.12/site-packages";

      # Jupyter configuration
      JUPYTER_CONFIG_DIR = "$HOME/.config/jupyter";
      JUPYTERLAB_DIR = "$HOME/.local/share/jupyter/lab";

      # IPython configuration
      IPYTHONDIR = "$HOME/.config/ipython";
    };

    # XDG configuration for Python tools
    xdg.configFile = {
      # pip configuration
      "pip/pip.conf".text = ''
        [global]
        user = true
        disable-pip-version-check = true

        [install]
        user = true
      '';

      # Poetry configuration
      "pypoetry/config.toml".text = ''
        [virtualenvs]
        create = true
        in-project = true
        path = "{project-dir}/.venv"

        [repositories]
      '';

      # IPython configuration
      "ipython/profile_default/ipython_config.py".text = ''
        # IPython configuration
        c.InteractiveShell.autoindent = True
        c.InteractiveShell.colors = 'Linux'
        c.InteractiveShell.confirm_exit = False
        c.InteractiveShell.editor = 'nvim'
        c.InteractiveShell.xmode = 'Context'

        # Auto-reload modules
        c.InteractiveShellApp.extensions = ['autoreload']
        c.InteractiveShellApp.exec_lines = ['%autoreload 2']

        # History
        c.HistoryManager.hist_file = '~/.config/ipython/profile_default/history.sqlite'
      '';

      # Jupyter Lab configuration
      "jupyter/jupyter_lab_config.py".text = ''
        # Jupyter Lab configuration
        c.ServerApp.ip = '127.0.0.1'
        c.ServerApp.open_browser = True
        c.ServerApp.root_dir = '~/Projects'
        c.ServerApp.notebook_dir = '~/Projects'

        # Extensions
        c.LabApp.collaborative = False
      '';

      # pytest configuration
      "pytest/pytest.ini".text = ''
        [tool:pytest]
        minversion = 6.0
        addopts = -ra -q --strict-markers --strict-config
        testpaths = tests
        python_files = test_*.py *_test.py
        python_classes = Test*
        python_functions = test_*
        markers =
            slow: marks tests as slow (deselect with '-m "not slow"')
            integration: marks tests as integration tests
            unit: marks tests as unit tests
      '';

      # mypy configuration
      "mypy/config".text = ''
        [mypy]
        python_version = 3.11
        warn_return_any = True
        warn_unused_configs = True
        disallow_untyped_defs = True
        disallow_incomplete_defs = True
        check_untyped_defs = True
        disallow_untyped_decorators = True
        no_implicit_optional = True
        warn_redundant_casts = True
        warn_unused_ignores = True
        warn_no_return = True
        warn_unreachable = True
        strict_equality = True
      '';

      # ruff configuration
      "ruff/ruff.toml".text = ''
        # Ruff configuration
        line-length = 88
        target-version = "py311"

        [lint]
        select = [
            "E",  # pycodestyle errors
            "W",  # pycodestyle warnings
            "F",  # pyflakes
            "I",  # isort
            "B",  # flake8-bugbear
            "C4", # flake8-comprehensions
            "UP", # pyupgrade
        ]
        ignore = [
            "E501",  # line too long, handled by black
            "B008",  # do not perform function calls in argument defaults
            "C901",  # too complex
        ]

        [lint.per-file-ignores]
        "__init__.py" = ["F401"]

        [format]
        quote-style = "double"
        indent-style = "space"
        skip-source-first-line = false
        line-ending = "auto"
      '';
    };

    # Create commonly used project structure helpers
    home.file = {
      # Python project template script
      ".local/bin/mkpyproject" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # Create a new Python project structure

          if [ $# -eq 0 ]; then
              echo "Usage: mkpyproject <project-name>"
              exit 1
          fi

          PROJECT_NAME="$1"

          mkdir -p "$PROJECT_NAME"/{src/"$PROJECT_NAME",tests,docs}
          cd "$PROJECT_NAME"

          # Initialize git
          git init

          # Create basic files
          touch README.md
          touch .gitignore
          touch requirements.txt
          touch requirements-dev.txt

          # Create pyproject.toml
          cat > pyproject.toml << EOF
          [build-system]
          requires = ["setuptools>=61.0", "wheel"]
          build-backend = "setuptools.build_meta"

          [project]
          name = "$PROJECT_NAME"
          version = "0.1.0"
          description = ""
          authors = [{name = "Your Name", email = "your.email@example.com"}]
          license = {text = "MIT"}
          readme = "README.md"
          requires-python = ">=3.11"
          dependencies = []

          [project.optional-dependencies]
          dev = [
              "pytest>=7.0",
              "pytest-cov",
              "black",
              "ruff",
              "mypy",
          ]

          [tool.setuptools.packages.find]
          where = ["src"]

          [tool.setuptools.package-dir]
          "" = "src"
          EOF

          # Create basic package structure
          touch "src/$PROJECT_NAME/__init__.py"
          echo 'def main():' > "src/$PROJECT_NAME/main.py"
          echo '    """Main entry point."""' >> "src/$PROJECT_NAME/main.py"
          echo '    pass' >> "src/$PROJECT_NAME/main.py"

          # Create basic test
          echo 'def test_main():' > "tests/test_main.py"
          echo '    """Test main function."""' >> "tests/test_main.py"
          echo '    pass' >> "tests/test_main.py"

          # Create .gitignore
          cat > .gitignore << EOF
          # Python
          __pycache__/
          *.py[cod]
          *$py.class
          *.so
          .Python
          build/
          develop-eggs/
          dist/
          downloads/
          eggs/
          .eggs/
          lib/
          lib64/
          parts/
          sdist/
          var/
          wheels/
          *.egg-info/
          .installed.cfg
          *.egg
          MANIFEST

          # Virtual environments
          .env
          .venv
          env/
          venv/
          ENV/
          env.bak/
          venv.bak/

          # IDEs
          .vscode/
          .idea/
          *.swp
          *.swo
          *~

          # Testing
          .coverage
          .pytest_cache/
          .tox/
          .nox/
          htmlcov/

          # Jupyter
          .ipynb_checkpoints

          # mypy
          .mypy_cache/
          .dmypy.json
          dmypy.json
          EOF

          echo "Created Python project: $PROJECT_NAME"
          echo "Next steps:"
          echo "1. cd $PROJECT_NAME"
          echo "2. python -m venv .venv"
          echo "3. source .venv/bin/activate"
          echo "4. pip install -e .[dev]"
        '';
      };

      # Virtual environment activation helper
      ".local/bin/venvactivate" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # Smart virtual environment activation

          # Look for virtual environment in common locations
          if [ -d ".venv" ]; then
              source .venv/bin/activate
              echo "Activated .venv"
          elif [ -d "venv" ]; then
              source venv/bin/activate
              echo "Activated venv"
          elif [ -d "env" ]; then
              source env/bin/activate
              echo "Activated env"
          elif [ -f "poetry.lock" ] || [ -f "pyproject.toml" ]; then
              poetry shell
          else
              echo "No virtual environment found in current directory"
              echo "Available options:"
              echo "  - .venv/"
              echo "  - venv/"
              echo "  - env/"
              echo "  - Poetry project"
              exit 1
          fi
        '';
      };
    };
  };
}
