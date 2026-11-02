# Rex appearance

`themes/Catppuccin Mocha` is a copy of the theme bundled with Ghostty, matching
`theme = Catppuccin Mocha` in `home/.config/ghostty/config`. It includes the 16 ANSI
colors, foreground/background, cursor colors, and selection colors.

Rex can import Ghostty theme files directly. Its selected theme and imported
palette are saved in the macOS app's preferences, separately from the server's
`init.lua`. Stow deploys the source file; it does not automatically import or
select it, and `rex config reload` does not apply theme-file changes.

After Stow deployment, identify the app with `rex --autostart=false client ls`,
then import and select the theme (replace `CLIENT` with that app's ID or label):

```sh
rex --autostart=false -C CLIENT do client.theme.import \
  path="$HOME/.config/rex/themes/Catppuccin Mocha"
```

Before deployment, the same action accepts the repository copy at
`$HOME/dotfiles/home/.config/rex/themes/Catppuccin Mocha`.
Once imported, it can also be selected through Rex's theme picker.

On 2026-11-02 this palette was imported and selected as Rex's dark theme. The
stored 16 ANSI colors and six named colors were checked against the Ghostty file.
Font family/size and the existing light theme were left unchanged. Ghostty's
Display P3 setting and other rendering differences are not reproduced by this
palette import; matching color values does not promise pixel-identical rendering.

## Font and selection

The macOS app preferences use **Iosevka Nerd Font** (not the Mono variant) and
**copy on selection**. The existing font size remains **14 pt**; Ghostty's 20 pt
size was not carried over. These are app preferences, not `init.lua` options.

To save these preferences on another Mac with the font installed:

```sh
defaults write com.superlogical.rex Workspace.terminalFontName -string 'Iosevka Nerd Font'
defaults write com.superlogical.rex Workspace.terminalCopyOnSelect -bool true
```

The keys were confirmed in Rex Beta 0.1.0 (1696), and both saved values were
verified on 2026-11-02. This is a manual setup step, not a Stow activation hook.
No app/server restart was performed, and live font rendering and mouse-selection
clipboard behavior were not tested. If an already-open app does not pick up the
preferences, quit and reopen the app when convenient.

Copy on selection does not grant terminal programs permission to read the
clipboard; clipboard-access permissions were left unchanged.
