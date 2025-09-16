_: {
  flake.modules.homeModules.aiAssistants = {pkgs, ...}: {
    home.packages = with pkgs; [
      heygpt # A simple command-line interface for ChatGPT API
      shell-gpt # Access ChatGPT from your terminal
      # ai-buddy # AI assistant for projects
      # devai # Command Agent runner to accelerate production coding
    ];
  };
}
