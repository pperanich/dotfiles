;;; config.el -*- lexical-binding: t; -*-

(setq user-full-name "Preston Peranich"
      user-mail-address "pperanich@gmail.com")

;; (setq auth-sources '((substitute-in-file-name "$XDG_DATA_HOME/authinfo.gpg"))
;;       auth-source-cache-expiry nil) ; default is 7200 (2h)

(setq-default
 delete-by-moving-to-trash t                      ; Delete files to trash
 window-combination-resize t                      ; take new window space from all other windows (not just current)
 x-stretch-cursor t)                              ; Stretch cursor to the glyph width

(setq undo-limit 80000000                         ; Raise undo-limit to 80Mb
      evil-want-fine-undo t                       ; By default while in insert all changes are one big blob. Be more granular
      auto-save-default t                         ; Nobody likes to loose work, I certainly don't
      truncate-string-ellipsis "…"                ; Unicode ellispis are nicer than "...", and also save /precious/ space
      password-cache-expiry nil                   ; I can trust my computers ... can't I?
      ;; scroll-preserve-screen-position 'always     ; Don't have `point' jump around
      scroll-margin 2                             ; It's nice to maintain a little margin
      display-time-default-load-average nil)      ; I don't think I've ever found this useful

(display-time-mode 1)                             ; Enable time in the mode-line

(unless (string-match-p "^Power N/A" (battery))   ; On laptops...
  (display-battery-mode 1))                       ; it's nice to know how much power you have

(global-subword-mode 1)                           ; Iterate through CamelCase words

(add-to-list 'default-frame-alist '(height . 24))
(add-to-list 'default-frame-alist '(width . 80))

(setq-default custom-file (expand-file-name ".custom.el" doom-private-dir))
(when (file-exists-p custom-file)
  (load custom-file))

(setq evil-vsplit-window-right t
      evil-split-window-below t)

(defadvice! prompt-for-buffer (&rest _)
  :after '(evil-window-split evil-window-vsplit)
  (consult-buffer))

(map! :map evil-window-map
      "SPC" #'rotate-layout
      ;; Navigation
      "<left>"     #'evil-window-left
      "<down>"     #'evil-window-down
      "<up>"       #'evil-window-up
      "<right>"    #'evil-window-right
      ;; Swapping windows
      "C-<left>"       #'+evil/window-move-left
      "C-<down>"       #'+evil/window-move-down
      "C-<up>"         #'+evil/window-move-up
      "C-<right>"      #'+evil/window-move-right)

(map! :leader :desc "Switch to window 1" "1" #'winum-select-window-1)
(map! :leader :desc "Switch to window 2" "2" #'winum-select-window-2)
(map! :leader :desc "Switch to window 4" "3" #'winum-select-window-3)
(map! :leader :desc "Switch to window 4" "4" #'winum-select-window-4)
(map! :leader :desc "Switch to window 5" "5" #'winum-select-window-5)
(map! :leader :desc "Switch to window 6" "6" #'winum-select-window-6)
(map! :leader :desc "Switch to window 7" "7" #'winum-select-window-7)
(map! :leader :desc "Switch to window 8" "8" #'winum-select-window-8)
(map! :leader :desc "Switch to window 9" "9" #'winum-select-window-9)

(setq flymake-allowed-file-name-masks nil)

(setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 24)
      doom-big-font (font-spec :family "Iosevka Nerd Font Mono" :size 36)
      doom-variable-pitch-font (font-spec :family "Iosevka Nerd Font" :size 26)
      doom-unicode-font (font-spec :family "Iosevka Nerd Font Mono")
      doom-emoji-font (font-spec :family "Twitter Color Emoji")
      doom-serif-font (font-spec :family "Iosevka Nerd Font" :size 22 :weight 'light))

(setq doom-theme 'modus-vivendi-tinted)

(delq! t custom-theme-load-path)

;; (remove-hook 'window-setup-hook #'doom-init-theme-h)
;; (add-hook 'after-init-hook #'doom-init-theme-h 'append)

(setq display-line-numbers-type 'relative)

(use-package! emacs-everywhere
  :if (daemonp)
  :config
  (require 'spell-fu)
  (setq emacs-everywhere-major-mode-function #'org-mode
        emacs-everywhere-frame-name-format "Edit ∷ %s — %s")
  (defadvice! emacs-everywhere-raise-frame ()
    :after #'emacs-everywhere-set-frame-name
    (setq emacs-everywhere-frame-name (format emacs-everywhere-frame-name-format
                                (emacs-everywhere-app-class emacs-everywhere-current-app)
                                (truncate-string-to-width
                                 (emacs-everywhere-app-title emacs-everywhere-current-app)
                                 45 nil nil "…")))
    ;; need to wait till frame refresh happen before really set
    (run-with-timer 0.1 nil #'emacs-everywhere-raise-frame-1))
  (defun emacs-everywhere-raise-frame-1 ()
    (call-process "wmctrl" nil nil nil "-a" emacs-everywhere-frame-name)))

(setq which-key-idle-delay 0.5) ;; I need the help, I really do

(setq which-key-allow-multiple-replacements t)
(after! which-key
  (pushnew!
   which-key-replacement-alist
   '(("" . "\\`+?evil[-:]?\\(?:a-\\)?\\(.*\\)") . (nil . "◂\\1"))
   '(("\\`g s" . "\\`evilem--?motion-\\(.*\\)") . (nil . "◃\\1"))
   ))

(add-hook 'doom-first-buffer-hook
          (defun +abbrev-file-name ()
            (setq-default abbrev-mode t)
            (setq abbrev-file-name (expand-file-name "abbrev.el" doom-private-dir))))

(use-package! vlf-setup
  :defer-incrementally vlf-tune vlf-base vlf-write
  vlf-search vlf-occur vlf-follow vlf-ediff vlf
  :commands vlf vlf-mode
  :init
  (defadvice! +files--ask-about-large-file-vlf (size op-type filename offer-raw)
  "Like `files--ask-user-about-large-file', but with support for `vlf'."
  :override #'files--ask-user-about-large-file
  (if (eq vlf-application 'dont-ask)
      (progn (vlf filename) (error ""))
    (let ((prompt (format "File %s is large (%s), really %s?"
                          (file-name-nondirectory filename)
                          (funcall byte-count-to-string-function size) op-type)))
      (if (not offer-raw)
          (if (y-or-n-p prompt) nil 'abort)
        (let ((choice
               (car
                (read-multiple-choice
                 prompt '((?y "yes")
                          (?n "no")
                          (?l "literally")
                          (?v "vlf"))
                 (files--ask-user-about-large-file-help-text
                  op-type (funcall byte-count-to-string-function size))))))
          (cond ((eq choice ?y) nil)
                ((eq choice ?l) 'raw)
                ((eq choice ?v)
                 (vlf filename)
                 (error ""))
                (t 'abort)))))))
  :config
  (advice-remove 'abort-if-file-too-large #'ad-Advice-abort-if-file-too-large)
  (defvar-local +vlf-cumulative-linenum '((0 . 0))
  "An alist keeping track of the cumulative line number.")

(defun +vlf-update-linum ()
  "Update the line number offset."
  (let ((linenum-offset (alist-get vlf-start-pos +vlf-cumulative-linenum)))
    (setq display-line-numbers-offset (or linenum-offset 0))
    (when (and linenum-offset (not (assq vlf-end-pos +vlf-cumulative-linenum)))
      (push (cons vlf-end-pos (+ linenum-offset
                                 (count-lines (point-min) (point-max))))
            +vlf-cumulative-linenum))))

(add-hook 'vlf-after-chunk-update-hook #'+vlf-update-linum)

;; Since this only works with absolute line numbers, let's make sure we use them.
(add-hook! 'vlf-mode-hook (setq-local display-line-numbers t))
  (defun +vlf-next-chunk-or-start ()
  (if (= vlf-file-size vlf-end-pos)
      (vlf-jump-to-chunk 1)
    (vlf-next-batch 1))
  (goto-char (point-min)))

(defun +vlf-last-chunk-or-end ()
  (if (= 0 vlf-start-pos)
      (vlf-end-of-file)
    (vlf-prev-batch 1))
  (goto-char (point-max)))

(defun +vlf-isearch-wrap ()
  (if isearch-forward
      (+vlf-next-chunk-or-start)
    (+vlf-last-chunk-or-end)))

(add-hook! 'vlf-mode-hook (setq-local isearch-wrap-function #'+vlf-isearch-wrap)))

(setq eros-eval-result-prefix "⟹ ") ; default =>

(after! evil
  (setq evil-ex-substitute-global t     ; I like my s/../.. to by global by default
        evil-kill-on-visual-paste nil)) ; Don't put overwritten text in the kill ring

(after! consult
  (set-face-attribute 'consult-file nil :inherit 'consult-buffer)
  (setf (plist-get (alist-get 'perl consult-async-split-styles-alist) :initial) ";"))

(defvar +magit-project-commit-templates-alist nil
  "Alist of toplevel dirs and template hf strings/functions.")
(after! magit
  (defun +magit-fill-in-commit-template ()
  "Insert template from `+magit-fill-in-commit-template' if applicable."
  (when-let ((template (and (save-excursion (goto-char (point-min)) (string-match-p "\\`\\s-*$" (thing-at-point 'line)))
                            (cdr (assoc (file-name-base (directory-file-name (magit-toplevel)))
                                        +magit-project-commit-templates-alist)))))
    (goto-char (point-min))
    (insert (if (stringp template) template (funcall template)))
    (goto-char (point-min))
    (end-of-line)))
(add-hook 'git-commit-setup-hook #'+magit-fill-in-commit-template 90)
(defun +org-commit-message-template ()
  "Create a skeleton for an Org commit message based on the staged diff."
  (let (change-data last-file file-changes temp-point)
    (with-temp-buffer
      (apply #'call-process magit-git-executable
             nil t nil
             (append
              magit-git-global-arguments
              (list "diff" "--cached")))
      (goto-char (point-min))
      (while (re-search-forward "^@@\\|^\\+\\+\\+ b/" nil t)
        (if (looking-back "^\\+\\+\\+ b/" (line-beginning-position))
            (progn
              (push (list last-file file-changes) change-data)
              (setq last-file (buffer-substring-no-properties (point) (line-end-position))
                    file-changes nil))
          (setq temp-point (line-beginning-position))
          (re-search-forward "^\\+\\|^-" nil t)
          (end-of-line)
          (cond
           ((string-match-p "\\.el$" last-file)
            (when (re-search-backward "^\\(?:[+-]? *\\|@@[ +-\\d,]+@@ \\)(\\(?:cl-\\)?\\(?:defun\\|defvar\\|defmacro\\|defcustom\\)" temp-point t)
              (re-search-forward "\\(?:cl-\\)?\\(?:defun\\|defvar\\|defmacro\\|defcustom\\) " nil t)
              (add-to-list 'file-changes (buffer-substring-no-properties (point) (forward-symbol 1)))))
           ((string-match-p "\\.org$" last-file)
            (when (re-search-backward "^[+-]\\*+ \\|^@@[ +-\\d,]+@@ \\*+ " temp-point t)
              (re-search-forward "@@ \\*+ " nil t)
              (add-to-list 'file-changes (buffer-substring-no-properties (point) (line-end-position)))))))))
    (push (list last-file file-changes) change-data)
    (setq change-data (delete '(nil nil) change-data))
    (concat
     (if (= 1 (length change-data))
         (replace-regexp-in-string "^.*/\\|.[a-z]+$" "" (caar change-data))
       "?")
     ": \n\n"
     (mapconcat
      (lambda (file-changes)
        (if (cadr file-changes)
            (format "* %s (%s): "
                    (car file-changes)
                    (mapconcat #'identity (cadr file-changes) ", "))
          (format "* %s: " (car file-changes))))
      change-data
      "\n\n"))))

(add-to-list '+magit-project-commit-templates-alist (cons "org" #'+org-commit-message-template)))

(defun smerge-repeatedly ()
  "Perform smerge actions again and again"
  (interactive)
  (smerge-mode 1)
  (smerge-transient))
(after! transient
  (transient-define-prefix smerge-transient ()
    [["Move"
      ("n" "next" (lambda () (interactive) (ignore-errors (smerge-next)) (smerge-repeatedly)))
      ("p" "previous" (lambda () (interactive) (ignore-errors (smerge-prev)) (smerge-repeatedly)))]
     ["Keep"
      ("b" "base" (lambda () (interactive) (ignore-errors (smerge-keep-base)) (smerge-repeatedly)))
      ("u" "upper" (lambda () (interactive) (ignore-errors (smerge-keep-upper)) (smerge-repeatedly)))
      ("l" "lower" (lambda () (interactive) (ignore-errors (smerge-keep-lower)) (smerge-repeatedly)))
      ("a" "all" (lambda () (interactive) (ignore-errors (smerge-keep-all)) (smerge-repeatedly)))
      ("RET" "current" (lambda () (interactive) (ignore-errors (smerge-keep-current)) (smerge-repeatedly)))]
     ["Diff"
      ("<" "upper/base" (lambda () (interactive) (ignore-errors (smerge-diff-base-upper)) (smerge-repeatedly)))
      ("=" "upper/lower" (lambda () (interactive) (ignore-errors (smerge-diff-upper-lower)) (smerge-repeatedly)))
      (">" "base/lower" (lambda () (interactive) (ignore-errors (smerge-diff-base-lower)) (smerge-repeatedly)))
      ("R" "refine" (lambda () (interactive) (ignore-errors (smerge-refine)) (smerge-repeatedly)))
      ("E" "ediff" (lambda () (interactive) (ignore-errors (smerge-ediff)) (smerge-repeatedly)))]
     ["Other"
      ("c" "combine" (lambda () (interactive) (ignore-errors (smerge-combine-with-next)) (smerge-repeatedly)))
      ("r" "resolve" (lambda () (interactive) (ignore-errors (smerge-resolve)) (smerge-repeatedly)))
      ("k" "kill current" (lambda () (interactive) (ignore-errors (smerge-kill-current)) (smerge-repeatedly)))
      ("q" "quit" (lambda () (interactive) (smerge-auto-leave)))]]))

(after! company
  (setq company-idle-delay 0.5
        company-minimum-prefix-length 2)
  (setq company-show-numbers t)
  (add-hook 'evil-normal-state-entry-hook #'company-abort)) ;; make aborting less annoying.

(setq-default history-length 1000)
(setq-default prescient-history-length 1000)

(set-company-backend!
  '(text-mode
    markdown-mode
    gfm-mode)
  '(:seperate
    company-ispell
    company-files
    company-yasnippet))

(set-company-backend! 'ess-r-mode '(company-R-args company-R-objects company-dabbrev-code :separate))

(setq projectile-ignored-projects
      (list "~/" "/tmp" (expand-file-name "straight/repos" doom-local-dir)))
(defun projectile-ignored-project-function (filepath)
  "Return t if FILEPATH is within any of `projectile-ignored-projects'"
  (or (mapcar (lambda (p) (s-starts-with-p p filepath)) projectile-ignored-projects)))

(setq ispell-dictionary "en-custom")

(setq ispell-personal-dictionary
      (expand-file-name "misc/ispell_personal" doom-private-dir))

(after! tramp
  (setenv "SHELL" "/bin/zsh")
  (setq tramp-shell-prompt-pattern "\\(?:^\\|\n\\|\x0d\\)[^]#$%>\n]*#?[]#$%>] *\\(\e\\[[0-9;]*[a-zA-Z] *\\)*")) ;; default + 

(after! tramp
  (appendq! tramp-remote-path
            '("~/.guix-profile/bin" "~/.guix-profile/sbin"
              "/run/current-system/profile/bin"
              "/run/current-system/profile/sbin")))

(after! tramp
  (appendq! tramp-remote-path
            '("~/.nix-profile/bin" "~/.nix-profile/sbin"
              "/run/current-system/profile/bin"
              "/run/current-system/profile/sbin")))

(use-package! aas
  :commands aas-mode)

(use-package! screenshot
  :defer t
  :config (setq screenshot-upload-fn "upload %s 2>/dev/null"))

(use-package! etrace
  :after elp)

(setq yas-triggers-in-field t)

(use-package! string-inflection
  :commands (string-inflection-all-cycle
             string-inflection-toggle
             string-inflection-camelcase
             string-inflection-lower-camelcase
             string-inflection-kebab-case
             string-inflection-underscore
             string-inflection-capital-underscore
             string-inflection-upcase)
  :init
  (map! :leader :prefix ("c~" . "naming convention")
        :desc "cycle" "~" #'string-inflection-all-cycle
        :desc "toggle" "t" #'string-inflection-toggle
        :desc "CamelCase" "c" #'string-inflection-camelcase
        :desc "downCase" "d" #'string-inflection-lower-camelcase
        :desc "kebab-case" "k" #'string-inflection-kebab-case
        :desc "under_score" "_" #'string-inflection-underscore
        :desc "Upper_Score" "u" #'string-inflection-capital-underscore
        :desc "UP_CASE" "U" #'string-inflection-upcase)
  (after! evil
    (evil-define-operator evil-operator-string-inflection (beg end _type)
      "Define a new evil operator that cycles symbol casing."
      :move-point nil
      (interactive "<R>")
      (string-inflection-all-cycle)
      (setq evil-repeat-info '([?g ?~])))
    (define-key evil-normal-state-map (kbd "g~") 'evil-operator-string-inflection)))

(sp-local-pair
 '(org-mode)
 "<<" ">>"
 :actions '(insert))

(use-package! info-colors
  :commands (info-colors-fontify-node))

(add-hook 'Info-selection-hook 'info-colors-fontify-node)

(use-package! theme-magic
  :commands theme-magic-from-emacs
  :config
  (defadvice! theme-magic--auto-extract-16-doom-colors ()
    :override #'theme-magic--auto-extract-16-colors
    (list
     (face-attribute 'default :background)
     (doom-color 'error)
     (doom-color 'success)
     (doom-color 'type)
     (doom-color 'keywords)
     (doom-color 'constants)
     (doom-color 'functions)
     (face-attribute 'default :foreground)
     (face-attribute 'shadow :foreground)
     (doom-blend 'base8 'error 0.1)
     (doom-blend 'base8 'success 0.1)
     (doom-blend 'base8 'type 0.1)
     (doom-blend 'base8 'keywords 0.1)
     (doom-blend 'base8 'constants 0.1)
     (doom-blend 'base8 'functions 0.1)
     (face-attribute 'default :foreground))))

(setq emojify-emoji-set "twemoji-v2")

(defvar emojify-disabled-emojis
  '(;; Org
    "◼" "☑" "☸" "⚙" "⏩" "⏪" "⬆" "⬇" "❓" "↔"
    ;; Terminal powerline
    "✔"
    ;; Box drawing
    "▶" "◀"
    ;; I just want to see this as text
    "©" "™")
  "Characters that should never be affected by `emojify-mode'.")

(defadvice! emojify-delete-from-data ()
  "Ensure `emojify-disabled-emojis' don't appear in `emojify-emojis'."
  :after #'emojify-set-emoji-data
  (dolist (emoji emojify-disabled-emojis)
    (remhash emoji emojify-emojis)))

(defun emojify--replace-text-with-emoji (orig-fn emoji text buffer start end &optional target)
  "Modify `emojify--propertize-text-for-emoji' to replace ascii/github emoticons with unicode emojis, on the fly."
  (if (or (not emoticon-to-emoji) (= 1 (length text)))
      (funcall orig-fn emoji text buffer start end target)
    (delete-region start end)
    (insert (ht-get emoji "unicode"))))

(define-minor-mode emoticon-to-emoji
  "Write ascii/gh emojis, and have them converted to unicode live."
  :global nil
  :init-value nil
  (if emoticon-to-emoji
      (progn
        (setq-local emojify-emoji-styles '(ascii github unicode))
        (advice-add 'emojify--propertize-text-for-emoji :around #'emojify--replace-text-with-emoji)
        (unless emojify-mode
          (emojify-turn-on-emojify-mode)))
    (setq-local emojify-emoji-styles (default-value 'emojify-emoji-styles))
    (advice-remove 'emojify--propertize-text-for-emoji #'emojify--replace-text-with-emoji)))

(add-hook! '(mu4e-compose-mode org-msg-edit-mode circe-channel-mode) (emoticon-to-emoji 1))

(custom-set-faces!
  '(doom-modeline-buffer-modified :foreground "orange"))

(setq doom-modeline-height 45)

(defun doom-modeline-conditional-buffer-encoding ()
  "We expect the encoding to be LF UTF-8, so only show the modeline when this is not the case"
  (setq-local doom-modeline-buffer-encoding
              (unless (and (memq (plist-get (coding-system-plist buffer-file-coding-system) :category)
                                 '(coding-category-undecided coding-category-utf-8))
                           (not (memq (coding-system-eol-type buffer-file-coding-system) '(1 2))))
                t)))

(add-hook 'after-change-major-mode-hook #'doom-modeline-conditional-buffer-encoding)

(defvar micro-clock-hour-hand-ratio 0.45
  "Length of the hour hand as a proportion of the radius.")
(defvar micro-clock-minute-hand-ratio 0.7
  "Length of the minute hand as a proportion of the radius.")

(defun micro-clock-svg (hour minute radius color)
  "Construct an SVG clock showing the time HOUR:MINUTE.
The clock will be of the specified RADIUS and COLOR."
  (let ((hour-x (* radius (sin (* (- 6 hour (/ minute 60.0)) (/ float-pi 6)))
                   micro-clock-hour-hand-ratio))
        (hour-y (* radius (cos (* (- 6 hour (/ minute 60.0)) (/ float-pi 6)))
                   micro-clock-hour-hand-ratio))
        (minute-x (* radius (sin (* (- 30 minute) (/ float-pi 30)))
                     micro-clock-minute-hand-ratio))
        (minute-y (* radius (cos (* (- 30 minute) (/ float-pi 30)))
                     micro-clock-minute-hand-ratio))
        (svg (svg-create (* 2 radius) (* 2 radius) :stroke color)))
    (svg-circle svg radius radius (1- radius) :fill "none" :stroke-width 2)
    (svg-circle svg radius radius 1 :fill color :stroke "none")
    (svg-line svg radius radius (+ radius hour-x) (+ radius hour-y)
              :stroke-width 2)
    (svg-line svg radius radius (+ radius minute-x) (+ radius minute-y)
              :stroke-width 1.5)
    svg))

(require 'svg)

(defvar +doom-modeline-micro-clock-minute-resolution 1
  "The clock will be updated every this many minutes, truncating.")
(defvar +doom-modeline-micro-clock-inverse-size 4.8
  "The size of the clock, as an inverse proportion to the mode line height.")

(defvar +doom-modeline-micro-clock--cache nil)

(defvar +doom-modeline-clock-text-format "%c")

(defun +doom-modeline--clock-text (&optional _window _object _pos)
  (format-time-string +doom-modeline-clock-text-format))

(defun +doom-modeline-micro-clock ()
  "Return a string containing an current analogue clock."
  (cdr
   (if (equal (truncate (float-time)
                        (* +doom-modeline-micro-clock-minute-resolution 60))
              (car +doom-modeline-micro-clock--cache))
       +doom-modeline-micro-clock--cache
     (setq +doom-modeline-micro-clock--cache
           (cons (truncate (float-time)
                           (* +doom-modeline-micro-clock-minute-resolution 60))
                 (with-temp-buffer
                   (svg-insert-image
                    (micro-clock-svg
                     (string-to-number (format-time-string "%-I")) ; hour
                     (* (truncate (string-to-number (format-time-string "%-M"))
                                  +doom-modeline-micro-clock-minute-resolution)
                        +doom-modeline-micro-clock-minute-resolution) ; minute
                     (/ doom-modeline-height +doom-modeline-micro-clock-inverse-size) ; radius
                     "currentColor"))
                   (propertize
                    " "
                    'display
                    (append (get-text-property 0 'display (buffer-string))
                            '(:ascent center))
                    'face 'doom-modeline-time
                    'help-echo #'+doom-modeline--clock-text)))))))

(use-package! gif-screencast
  :commands gif-screencast-mode
  :config
  (map! :map gif-screencast-mode-map
        :g "<f8>" #'gif-screencast-toggle-pause
        :g "<f9>" #'gif-screencast-stop)
  (setq gif-screencast-program "maim"
        gif-screencast-args `("--quality" "3" "-i" ,(string-trim-right
                                                     (shell-command-to-string
                                                      "xdotool getactivewindow")))
        gif-screencast-optimize-args '("--batch" "--optimize=3" "--usecolormap=/tmp/doom-color-theme"))
  (defun gif-screencast-write-colormap ()
    (f-write-text
     (replace-regexp-in-string
      "\n+" "\n"
      (mapconcat (lambda (c) (if (listp (cdr c))
                                 (cadr c))) doom-themes--colors "\n"))
     'utf-8
     "/tmp/doom-color-theme" ))
  (gif-screencast-write-colormap)
  (add-hook 'doom-load-theme-hook #'gif-screencast-write-colormap))

(defvar mixed-pitch-modes '(org-mode LaTeX-mode markdown-mode gfm-mode Info-mode)
  "Modes that `mixed-pitch-mode' should be enabled in, but only after UI initialisation.")
(defun init-mixed-pitch-h ()
  "Hook `mixed-pitch-mode' into each mode in `mixed-pitch-modes'.
Also immediately enables `mixed-pitch-modes' if currently in one of the modes."
  (when (memq major-mode mixed-pitch-modes)
    (mixed-pitch-mode 1))
  (dolist (hook mixed-pitch-modes)
    (add-hook (intern (concat (symbol-name hook) "-hook")) #'mixed-pitch-mode)))
(add-hook 'doom-init-ui-hook #'init-mixed-pitch-h)

(autoload #'mixed-pitch-serif-mode "mixed-pitch"
  "Change the default face of the current buffer to a serifed variable pitch, while keeping some faces fixed pitch." t)

(setq! variable-pitch-serif-font (font-spec :family "Iosevka Nerd Font" :size 27))

(after! mixed-pitch
  (setq mixed-pitch-set-height t)
  (set-face-attribute 'variable-pitch-serif nil :font variable-pitch-serif-font)
  (defun mixed-pitch-serif-mode (&optional arg)
    "Change the default face of the current buffer to a serifed variable pitch, while keeping some faces fixed pitch."
    (interactive)
    (let ((mixed-pitch-face 'variable-pitch-serif))
      (mixed-pitch-mode (or arg 'toggle)))))

(set-char-table-range composition-function-table ?f '(["\\(?:ff?[fijlt]\\)" 0 font-shape-gstring]))
(set-char-table-range composition-function-table ?T '(["\\(?:Th\\)" 0 font-shape-gstring]))

(defface variable-pitch-serif
    '((t (:family "serif")))
    "A variable-pitch face with serifs."
    :group 'basic-faces)

(defcustom variable-pitch-serif-font (font-spec :family "serif")
  "The font face used for `variable-pitch-serif'."
  :group 'basic-faces
  :set (lambda (symbol value)
         (set-face-attribute 'variable-pitch-serif nil :font value)
         (set-default-toplevel-value symbol value)))

(after! marginalia
  (setq marginalia-censor-variables nil)

  (defadvice! +marginalia--anotate-local-file-colorful (cand)
    "Just a more colourful version of `marginalia--anotate-local-file'."
    :override #'marginalia--annotate-local-file
    (when-let (attrs (file-attributes (substitute-in-file-name
                                       (marginalia--full-candidate cand))
                                      'integer))
      (marginalia--fields
       ((marginalia--file-owner attrs)
        :width 12 :face 'marginalia-file-owner)
       ((marginalia--file-modes attrs))
       ((+marginalia-file-size-colorful (file-attribute-size attrs))
        :width 7)
       ((+marginalia--time-colorful (file-attribute-modification-time attrs))
        :width 12))))

  (defun +marginalia--time-colorful (time)
    (let* ((seconds (float-time (time-subtract (current-time) time)))
           (color (doom-blend
                   (face-attribute 'marginalia-date :foreground nil t)
                   (face-attribute 'marginalia-documentation :foreground nil t)
                   (/ 1.0 (log (+ 3 (/ (+ 1 seconds) 345600.0)))))))
      ;; 1 - log(3 + 1/(days + 1)) % grey
      (propertize (marginalia--time time) 'face (list :foreground color))))

  (defun +marginalia-file-size-colorful (size)
    (let* ((size-index (/ (log10 (+ 1 size)) 7.0))
           (color (if (< size-index 10000000) ; 10m
                      (doom-blend 'orange 'green size-index)
                    (doom-blend 'red 'orange (- size-index 1)))))
      (propertize (file-size-human-readable size) 'face (list :foreground color)))))

;; (after! centaur-tabs
;;   (centaur-tabs-mode -1)
;;   (setq centaur-tabs-height 36
;;         centaur-tabs-set-icons t
;;         centaur-tabs-modified-marker "o"
;;         centaur-tabs-close-button "×"
;;         centaur-tabs-set-bar 'above
;;         centaur-tabs-gray-out-icons 'buffer)
;;   (centaur-tabs-change-fonts "P22 Underground Book" 160))
;; (setq x-underline-at-descent-line t)

(after! nerd-icons
  (setcdr (assoc "m" nerd-icons-extension-icon-alist)
          (cdr (assoc "matlab" nerd-icons-extension-icon-alist))))

(use-package! page-break-lines
  :commands page-break-lines-mode
  :init
  (autoload 'turn-on-page-break-lines-mode "page-break-lines")
  :config
  (setq page-break-lines-max-width fill-column)
  (map! :prefix "g"
        :desc "Prev page break" :nv "[" #'backward-page
        :desc "Next page break" :nv "]" #'forward-page))

(setq +zen-text-scale 0.8)

(defvar +zen-serif-p t
  "Whether to use a serifed font with `mixed-pitch-mode'.")
(defvar +zen-org-starhide t
  "The value `org-modern-hide-stars' is set to.")

(after! writeroom-mode
  (defvar-local +zen--original-org-indent-mode-p nil)
  (defvar-local +zen--original-mixed-pitch-mode-p nil)
  (defun +zen-enable-mixed-pitch-mode-h ()
    "Enable `mixed-pitch-mode' when in `+zen-mixed-pitch-modes'."
    (when (apply #'derived-mode-p +zen-mixed-pitch-modes)
      (if writeroom-mode
          (progn
            (setq +zen--original-mixed-pitch-mode-p mixed-pitch-mode)
            (funcall (if +zen-serif-p #'mixed-pitch-serif-mode #'mixed-pitch-mode) 1))
        (funcall #'mixed-pitch-mode (if +zen--original-mixed-pitch-mode-p 1 -1)))))
  (defun +zen-prose-org-h ()
    "Reformat the current Org buffer appearance for prose."
    (when (eq major-mode 'org-mode)
      (setq display-line-numbers nil
            visual-fill-column-width 60
            org-adapt-indentation nil)
      (when (featurep 'org-modern)
        (setq-local org-modern-star '("🙘" "🙙" "🙚" "🙛")
                    ;; org-modern-star '("🙐" "🙑" "🙒" "🙓" "🙔" "🙕" "🙖" "🙗")
                    org-modern-hide-stars +zen-org-starhide)
        (org-modern-mode -1)
        (org-modern-mode 1))
      (setq
       +zen--original-org-indent-mode-p org-indent-mode)
      (org-indent-mode -1)))
  (defun +zen-nonprose-org-h ()
    "Reverse the effect of `+zen-prose-org'."
    (when (eq major-mode 'org-mode)
      (when (bound-and-true-p org-modern-mode)
        (org-modern-mode -1)
        (org-modern-mode 1))
      (when +zen--original-org-indent-mode-p (org-indent-mode 1))))
  (pushnew! writeroom--local-variables
            'display-line-numbers
            'visual-fill-column-width
            'org-adapt-indentation
            'org-modern-mode
            'org-modern-star
            'org-modern-hide-stars)
  (add-hook 'writeroom-mode-enable-hook #'+zen-prose-org-h)
  (add-hook 'writeroom-mode-disable-hook #'+zen-nonprose-org-h))

(after! treemacs
  (defvar treemacs-file-ignore-extensions '()
    "File extension which `treemacs-ignore-filter' will ensure are ignored")
  (defvar treemacs-file-ignore-globs '()
    "Globs which will are transformed to `treemacs-file-ignore-regexps' which `treemacs-ignore-filter' will ensure are ignored")
  (defvar treemacs-file-ignore-regexps '()
    "RegExps to be tested to ignore files, generated from `treeemacs-file-ignore-globs'")
  (defun treemacs-file-ignore-generate-regexps ()
    "Generate `treemacs-file-ignore-regexps' from `treemacs-file-ignore-globs'"
    (setq treemacs-file-ignore-regexps (mapcar 'dired-glob-regexp treemacs-file-ignore-globs)))
  (if (equal treemacs-file-ignore-globs '()) nil (treemacs-file-ignore-generate-regexps))
  (defun treemacs-ignore-filter (file full-path)
    "Ignore files specified by `treemacs-file-ignore-extensions', and `treemacs-file-ignore-regexps'"
    (or (member (file-name-extension file) treemacs-file-ignore-extensions)
        (let ((ignore-file nil))
          (dolist (regexp treemacs-file-ignore-regexps ignore-file)
            (setq ignore-file (or ignore-file (if (string-match-p regexp full-path) t nil)))))))
  (add-to-list 'treemacs-ignored-file-predicates #'treemacs-ignore-filter))

(setq treemacs-file-ignore-extensions
      '(;; LaTeX
        "aux"
        "ptc"
        "fdb_latexmk"
        "fls"
        "synctex.gz"
        "toc"
        ;; LaTeX - glossary
        "glg"
        "glo"
        "gls"
        "glsdefs"
        "ist"
        "acn"
        "acr"
        "alg"
        ;; LaTeX - pgfplots
        "mw"
        ;; LaTeX - pdfx
        "pdfa.xmpi"
        ))
(setq treemacs-file-ignore-globs
      '(;; LaTeX
        "*/_minted-*"
        ;; AucTeX
        "*/.auctex-auto"
        "*/_region_.log"
        "*/_region_.tex"))

(use-package! xkcd
  :commands (xkcd-get-json
             xkcd-download xkcd-get
             ;; now for funcs from my extension of this pkg
             +xkcd-find-and-copy +xkcd-find-and-view
             +xkcd-fetch-info +xkcd-select)
  :config
  (setq xkcd-cache-dir (expand-file-name "xkcd/" doom-cache-dir)
        xkcd-cache-latest (concat xkcd-cache-dir "latest"))
  (unless (file-exists-p xkcd-cache-dir)
    (make-directory xkcd-cache-dir))
  (after! evil-snipe
    (add-to-list 'evil-snipe-disabled-modes 'xkcd-mode))
  :general (:states 'normal
            :keymaps 'xkcd-mode-map
            "<right>" #'xkcd-next
            "n"       #'xkcd-next ; evil-ish
            "<left>"  #'xkcd-prev
            "N"       #'xkcd-prev ; evil-ish
            "r"       #'xkcd-rand
            "a"       #'xkcd-rand ; because image-rotate can interfere
            "t"       #'xkcd-alt-text
            "q"       #'xkcd-kill-buffer
            "o"       #'xkcd-open-browser
            "e"       #'xkcd-open-explanation-browser
            ;; extras
            "s"       #'+xkcd-find-and-view
            "/"       #'+xkcd-find-and-view
            "y"       #'+xkcd-copy))

(after! xkcd
  (require 'emacsql-sqlite)

  (defun +xkcd-select ()
    "Prompt the user for an xkcd using `completing-read' and `+xkcd-select-format'. Return the xkcd number or nil"
    (let* (prompt-lines
           (-dummy (maphash (lambda (key xkcd-info)
                              (push (+xkcd-select-format xkcd-info) prompt-lines))
                            +xkcd-stored-info))
           (num (completing-read (format "xkcd (%s): " xkcd-latest) prompt-lines)))
      (if (equal "" num) xkcd-latest
        (string-to-number (replace-regexp-in-string "\\([0-9]+\\).*" "\\1" num)))))

  (defun +xkcd-select-format (xkcd-info)
    "Creates each completing-read line from an xkcd info plist. Must start with the xkcd number"
    (format "%-4s  %-30s %s"
            (propertize (number-to-string (plist-get xkcd-info :num))
                        'face 'counsel-key-binding)
            (plist-get xkcd-info :title)
            (propertize (plist-get xkcd-info :alt)
                        'face '(variable-pitch font-lock-comment-face))))

  (defun +xkcd-fetch-info (&optional num)
    "Fetch the parsed json info for comic NUM. Fetches latest when omitted or 0"
    (require 'xkcd)
    (when (or (not num) (= num 0))
      (+xkcd-check-latest)
      (setq num xkcd-latest))
    (let ((res (or (gethash num +xkcd-stored-info)
                   (puthash num (+xkcd-db-read num) +xkcd-stored-info))))
      (unless res
        (+xkcd-db-write
         (let* ((url (format "https://xkcd.com/%d/info.0.json" num))
                (json-assoc
                 (if (gethash num +xkcd-stored-info)
                     (gethash num +xkcd-stored-info)
                   (json-read-from-string (xkcd-get-json url num)))))
           json-assoc))
        (setq res (+xkcd-db-read num)))
      res))

  ;; since we've done this, we may as well go one little step further
  (defun +xkcd-find-and-copy ()
    "Prompt for an xkcd using `+xkcd-select' and copy url to clipboard"
    (interactive)
    (+xkcd-copy (+xkcd-select)))

  (defun +xkcd-copy (&optional num)
    "Copy a url to xkcd NUM to the clipboard"
    (interactive "i")
    (let ((num (or num xkcd-cur)))
      (gui-select-text (format "https://xkcd.com/%d" num))
      (message "xkcd.com/%d copied to clipboard" num)))

  (defun +xkcd-find-and-view ()
    "Prompt for an xkcd using `+xkcd-select' and view it"
    (interactive)
    (xkcd-get (+xkcd-select))
    (switch-to-buffer "*xkcd*"))

  (defvar +xkcd-latest-max-age (* 60 60) ; 1 hour
    "Time after which xkcd-latest should be refreshed, in seconds")

  ;; initialise `xkcd-latest' and `+xkcd-stored-info' with latest xkcd
  (add-transient-hook! '+xkcd-select
    (require 'xkcd)
    (+xkcd-fetch-info xkcd-latest)
    (setq +xkcd-stored-info (+xkcd-db-read-all)))

  (add-transient-hook! '+xkcd-fetch-info
    (xkcd-update-latest))

  (defun +xkcd-check-latest ()
    "Use value in `xkcd-cache-latest' as long as it isn't older thabn `+xkcd-latest-max-age'"
    (unless (and (file-exists-p xkcd-cache-latest)
                 (< (- (time-to-seconds (current-time))
                       (time-to-seconds (file-attribute-modification-time (file-attributes xkcd-cache-latest))))
                    +xkcd-latest-max-age))
      (let* ((out (xkcd-get-json "http://xkcd.com/info.0.json" 0))
             (json-assoc (json-read-from-string out))
             (latest (cdr (assoc 'num json-assoc))))
        (when (/= xkcd-latest latest)
          (+xkcd-db-write json-assoc)
          (with-current-buffer (find-file xkcd-cache-latest)
            (setq xkcd-latest latest)
            (erase-buffer)
            (insert (number-to-string latest))
            (save-buffer)
            (kill-buffer (current-buffer)))))
      (shell-command (format "touch %s" xkcd-cache-latest))))

  (defvar +xkcd-stored-info (make-hash-table :test 'eql)
    "Basic info on downloaded xkcds, in the form of a hashtable")

  (defadvice! xkcd-get-json--and-cache (url &optional num)
    "Fetch the Json coming from URL.
If the file NUM.json exists, use it instead.
If NUM is 0, always download from URL.
The return value is a string."
    :override #'xkcd-get-json
    (let* ((file (format "%s%d.json" xkcd-cache-dir num))
           (cached (and (file-exists-p file) (not (eq num 0))))
           (out (with-current-buffer (if cached
                                         (find-file file)
                                       (url-retrieve-synchronously url))
                  (goto-char (point-min))
                  (unless cached (re-search-forward "^$"))
                  (prog1
                      (buffer-substring-no-properties (point) (point-max))
                    (kill-buffer (current-buffer))))))
      (unless (or cached (eq num 0))
        (xkcd-cache-json num out))
      out))

  (defadvice! +xkcd-get (num)
    "Get the xkcd number NUM."
    :override 'xkcd-get
    (interactive "nEnter comic number: ")
    (xkcd-update-latest)
    (get-buffer-create "*xkcd*")
    (switch-to-buffer "*xkcd*")
    (xkcd-mode)
    (let (buffer-read-only)
      (erase-buffer)
      (setq xkcd-cur num)
      (let* ((xkcd-data (+xkcd-fetch-info num))
             (num (plist-get xkcd-data :num))
             (img (plist-get xkcd-data :img))
             (safe-title (plist-get xkcd-data :safe-title))
             (alt (plist-get xkcd-data :alt))
             title file)
        (message "Getting comic...")
        (setq file (xkcd-download img num))
        (setq title (format "%d: %s" num safe-title))
        (insert (propertize title
                            'face 'outline-1))
        (center-line)
        (insert "\n")
        (xkcd-insert-image file num)
        (if (eq xkcd-cur 0)
            (setq xkcd-cur num))
        (setq xkcd-alt alt)
        (message "%s" title))))

  (defconst +xkcd-db--sqlite-available-p
    (with-demoted-errors "+org-xkcd initialization: %S"
      (emacsql-sqlite-ensure-binary)
      t))

  (defvar +xkcd-db--connection (make-hash-table :test #'equal)
    "Database connection to +org-xkcd database.")

  (defun +xkcd-db--get ()
    "Return the sqlite db file."
    (expand-file-name "xkcd.db" xkcd-cache-dir))

  (defun +xkcd-db--get-connection ()
    "Return the database connection, if any."
    (gethash (file-truename xkcd-cache-dir)
             +xkcd-db--connection))

  (defconst +xkcd-db--table-schema
    '((xkcds
       [(num integer :unique :primary-key)
        (year        :not-null)
        (month       :not-null)
        (link        :not-null)
        (news        :not-null)
        (safe_title  :not-null)
        (title       :not-null)
        (transcript  :not-null)
        (alt         :not-null)
        (img         :not-null)])))

  (defun +xkcd-db--init (db)
    "Initialize database DB with the correct schema and user version."
    (emacsql-with-transaction db
      (pcase-dolist (`(,table . ,schema) +xkcd-db--table-schema)
        (emacsql db [:create-table $i1 $S2] table schema))))

  (defun +xkcd-db ()
    "Entrypoint to the +org-xkcd sqlite database.
Initializes and stores the database, and the database connection.
Performs a database upgrade when required."
    (unless (and (+xkcd-db--get-connection)
                 (emacsql-live-p (+xkcd-db--get-connection)))
      (let* ((db-file (+xkcd-db--get))
             (init-db (not (file-exists-p db-file))))
        (make-directory (file-name-directory db-file) t)
        (let ((conn (emacsql-sqlite db-file)))
          (set-process-query-on-exit-flag (emacsql-process conn) nil)
          (puthash (file-truename xkcd-cache-dir)
                   conn
                   +xkcd-db--connection)
          (when init-db
            (+xkcd-db--init conn)))))
    (+xkcd-db--get-connection))

  (defun +xkcd-db-query (sql &rest args)
    "Run SQL query on +org-xkcd database with ARGS.
SQL can be either the emacsql vector representation, or a string."
    (if  (stringp sql)
        (emacsql (+xkcd-db) (apply #'format sql args))
      (apply #'emacsql (+xkcd-db) sql args)))

  (defun +xkcd-db-read (num)
    (when-let ((res
                (car (+xkcd-db-query [:select * :from xkcds
                                      :where (= num $s1)]
                                     num
                                     :limit 1))))
      (+xkcd-db-list-to-plist res)))

  (defun +xkcd-db-read-all ()
    (let ((xkcd-table (make-hash-table :test 'eql :size 4000)))
      (mapcar (lambda (xkcd-info-list)
                (puthash (car xkcd-info-list) (+xkcd-db-list-to-plist xkcd-info-list) xkcd-table))
              (+xkcd-db-query [:select * :from xkcds]))
      xkcd-table))

  (defun +xkcd-db-list-to-plist (xkcd-datalist)
    `(:num ,(nth 0 xkcd-datalist)
      :year ,(nth 1 xkcd-datalist)
      :month ,(nth 2 xkcd-datalist)
      :link ,(nth 3 xkcd-datalist)
      :news ,(nth 4 xkcd-datalist)
      :safe-title ,(nth 5 xkcd-datalist)
      :title ,(nth 6 xkcd-datalist)
      :transcript ,(nth 7 xkcd-datalist)
      :alt ,(nth 8 xkcd-datalist)
      :img ,(nth 9 xkcd-datalist)))

  (defun +xkcd-db-write (data)
    (+xkcd-db-query [:insert-into xkcds
                     :values $v1]
                    (list (vector
                           (cdr (assoc 'num        data))
                           (cdr (assoc 'year       data))
                           (cdr (assoc 'month      data))
                           (cdr (assoc 'link       data))
                           (cdr (assoc 'news       data))
                           (cdr (assoc 'safe_title data))
                           (cdr (assoc 'title      data))
                           (cdr (assoc 'transcript data))
                           (cdr (assoc 'alt        data))
                           (cdr (assoc 'img        data))
                           )))))

(use-package! spray
  :commands spray-mode
  :config
  (setq spray-wpm 600
        spray-height 800)
  (defun spray-mode-hide-cursor ()
    "Hide or unhide the cursor as is appropriate."
    (if spray-mode
        (setq-local spray--last-evil-cursor-state evil-normal-state-cursor
                    evil-normal-state-cursor '(nil))
      (setq-local evil-normal-state-cursor spray--last-evil-cursor-state)))
  (add-hook 'spray-mode-hook #'spray-mode-hide-cursor)
  (map! :map spray-mode-map
        "<return>" #'spray-start/stop
        "f" #'spray-faster
        "s" #'spray-slower
        "t" #'spray-time
        "<right>" #'spray-forward-word
        "h" #'spray-forward-word
        "<left>" #'spray-backward-word
        "l" #'spray-backward-word
        "q" #'spray-quit))

(use-package! elcord
  :commands elcord-mode
  :config
  (setq elcord-use-major-mode-as-main-icon t))

(use-package! systemd
  :defer t)

(use-package! calibredb
  :commands calibredb
  :config
  (setq calibredb-root-dir "~/Documents/Ebooks"
        calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
  (map! :map calibredb-show-mode-map
        :ne "?" #'calibredb-entry-dispatch
        :ne "o" #'calibredb-find-file
        :ne "O" #'calibredb-find-file-other-frame
        :ne "V" #'calibredb-open-file-with-default-tool
        :ne "s" #'calibredb-set-metadata-dispatch
        :ne "e" #'calibredb-export-dispatch
        :ne "q" #'calibredb-entry-quit
        :ne "." #'calibredb-open-dired
        :ne [tab] #'calibredb-toggle-view-at-point
        :ne "M-t" #'calibredb-set-metadata--tags
        :ne "M-a" #'calibredb-set-metadata--author_sort
        :ne "M-A" #'calibredb-set-metadata--authors
        :ne "M-T" #'calibredb-set-metadata--title
        :ne "M-c" #'calibredb-set-metadata--comments)
  (map! :map calibredb-search-mode-map
        :ne [mouse-3] #'calibredb-search-mouse
        :ne "RET" #'calibredb-find-file
        :ne "?" #'calibredb-dispatch
        :ne "a" #'calibredb-add
        :ne "A" #'calibredb-add-dir
        :ne "c" #'calibredb-clone
        :ne "d" #'calibredb-remove
        :ne "D" #'calibredb-remove-marked-items
        :ne "j" #'calibredb-next-entry
        :ne "k" #'calibredb-previous-entry
        :ne "l" #'calibredb-virtual-library-list
        :ne "L" #'calibredb-library-list
        :ne "n" #'calibredb-virtual-library-next
        :ne "N" #'calibredb-library-next
        :ne "p" #'calibredb-virtual-library-previous
        :ne "P" #'calibredb-library-previous
        :ne "s" #'calibredb-set-metadata-dispatch
        :ne "S" #'calibredb-switch-library
        :ne "o" #'calibredb-find-file
        :ne "O" #'calibredb-find-file-other-frame
        :ne "v" #'calibredb-view
        :ne "V" #'calibredb-open-file-with-default-tool
        :ne "." #'calibredb-open-dired
        :ne "b" #'calibredb-catalog-bib-dispatch
        :ne "e" #'calibredb-export-dispatch
        :ne "r" #'calibredb-search-refresh-and-clear-filter
        :ne "R" #'calibredb-search-clear-filter
        :ne "q" #'calibredb-search-quit
        :ne "m" #'calibredb-mark-and-forward
        :ne "f" #'calibredb-toggle-favorite-at-point
        :ne "x" #'calibredb-toggle-archive-at-point
        :ne "h" #'calibredb-toggle-highlight-at-point
        :ne "u" #'calibredb-unmark-and-forward
        :ne "i" #'calibredb-edit-annotation
        :ne "DEL" #'calibredb-unmark-and-backward
        :ne [backtab] #'calibredb-toggle-view
        :ne [tab] #'calibredb-toggle-view-at-point
        :ne "M-n" #'calibredb-show-next-entry
        :ne "M-p" #'calibredb-show-previous-entry
        :ne "/" #'calibredb-search-live-filter
        :ne "M-t" #'calibredb-set-metadata--tags
        :ne "M-a" #'calibredb-set-metadata--author_sort
        :ne "M-A" #'calibredb-set-metadata--authors
        :ne "M-T" #'calibredb-set-metadata--title
        :ne "M-c" #'calibredb-set-metadata--comments))

(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (map! :map nov-mode-map
        :n "RET" #'nov-scroll-up)

  (defun doom-modeline-segment--nov-info ()
    (concat
     " "
     (propertize
      (cdr (assoc 'creator nov-metadata))
      'face 'doom-modeline-project-parent-dir)
     " "
     (cdr (assoc 'title nov-metadata))
     " "
     (propertize
      (format "%d/%d"
              (1+ nov-documents-index)
              (length nov-documents))
      'face 'doom-modeline-info)))

  (advice-add 'nov-render-title :override #'ignore)

  (defun +nov-mode-setup ()
    "Tweak nov-mode to our liking."
    (face-remap-add-relative 'variable-pitch
                             :family "Merriweather"
                             :height 1.4
                             :width 'semi-expanded)
    (face-remap-add-relative 'default :height 1.3)
    (setq-local line-spacing 0.2
                next-screen-context-lines 4
                shr-use-colors nil)
    (require 'visual-fill-column nil t)
    (setq-local visual-fill-column-center-text t
                visual-fill-column-width 81
                nov-text-width 80)
    (visual-fill-column-mode 1)
    (hl-line-mode -1)
    ;; Re-render with new display settings
    (nov-render-document)
    ;; Look up words with the dictionary.
    (add-to-list '+lookup-definition-functions #'+lookup/dictionary-definition)
    ;; Customise the mode-line to make it more minimal and relevant.
    (setq-local
     mode-line-format
     `((:eval
        (doom-modeline-segment--workspace-name))
       (:eval
        (doom-modeline-segment--window-number))
       (:eval
        (doom-modeline-segment--nov-info))
       ,(propertize
         " %P "
         'face 'doom-modeline-buffer-minor-mode)
       ,(propertize
         " "
         'face (if (doom-modeline--active) 'mode-line 'mode-line-inactive)
         'display `((space
                     :align-to
                     (- (+ right right-fringe right-margin)
                        ,(* (let ((width (doom-modeline--font-width)))
                              (or (and (= width 1) 1)
                                  (/ width (frame-char-width) 1.0)))
                            (string-width
                             (format-mode-line (cons "" '(:eval (doom-modeline-segment--major-mode))))))))))
       (:eval (doom-modeline-segment--major-mode)))))

  (add-hook 'nov-mode-hook #'+nov-mode-setup))

(use-package! calctex
  :commands calctex-mode
  :init
  (add-hook 'calc-mode-hook #'calctex-mode)
  :config
  (setq calctex-additional-latex-packages "
\\usepackage[usenames]{xcolor}
\\usepackage{soul}
\\usepackage{adjustbox}
\\usepackage{amsmath}
\\usepackage{amssymb}
\\usepackage{siunitx}
\\usepackage{cancel}
\\usepackage{mathtools}
\\usepackage{mathalpha}
\\usepackage{xparse}
\\usepackage{arevmath}"
        calctex-additional-latex-macros
        (concat calctex-additional-latex-macros
                "\n\\let\\evalto\\Rightarrow"))
  (defadvice! no-messaging-a (orig-fn &rest args)
    :around #'calctex-default-dispatching-render-process
    (let ((inhibit-message t) message-log-max)
      (apply orig-fn args)))
  ;; Fix hardcoded dvichop path (whyyyyyyy)
  (let ((vendor-folder (concat (file-truename doom-local-dir)
                               "straight/"
                               (format "build-%s" emacs-version)
                               "/calctex/vendor/")))
    (setq calctex-dvichop-sty (concat vendor-folder "texd/dvichop")
          calctex-dvichop-bin (concat vendor-folder "texd/dvichop")))
  (unless (file-exists-p calctex-dvichop-bin)
    (message "CalcTeX: Building dvichop binary")
    (let ((default-directory (file-name-directory calctex-dvichop-bin)))
      (call-process "make" nil nil nil))))

(setq calc-angle-mode 'rad  ; radians are rad
      calc-symbolic-mode t) ; keeps expressions like \sqrt{2} irrational for as long as possible

(map! :map calc-mode-map
      :after calc
      :localleader
      :desc "Embedded calc (toggle)" "e" #'calc-embedded)
(map! :map org-mode-map
      :after org
      :localleader
      :desc "Embedded calc (toggle)" "E" #'calc-embedded)
(map! :map latex-mode-map
      :after latex
      :localleader
      :desc "Embedded calc (toggle)" "e" #'calc-embedded)

(defvar calc-embedded-trail-window nil)
(defvar calc-embedded-calculator-window nil)

(defadvice! calc-embedded-with-side-pannel (&rest _)
  :after #'calc-do-embedded
  (when calc-embedded-trail-window
    (ignore-errors
      (delete-window calc-embedded-trail-window))
    (setq calc-embedded-trail-window nil))
  (when calc-embedded-calculator-window
    (ignore-errors
      (delete-window calc-embedded-calculator-window))
    (setq calc-embedded-calculator-window nil))
  (when (and calc-embedded-info
             (> (* (window-width) (window-height)) 1200))
    (let ((main-window (selected-window))
          (vertical-p (> (window-width) 80)))
      (select-window
       (setq calc-embedded-trail-window
             (if vertical-p
                 (split-window-horizontally (- (max 30 (/ (window-width) 3))))
               (split-window-vertically (- (max 8 (/ (window-height) 4)))))))
      (switch-to-buffer "*Calc Trail*")
      (select-window
       (setq calc-embedded-calculator-window
             (if vertical-p
                 (split-window-vertically -6)
               (split-window-horizontally (- (/ (window-width) 2))))))
      (switch-to-buffer "*Calculator*")
      (select-window main-window))))

(after! circe
  (setq-default circe-use-tls t)
  (setq circe-notifications-alert-icon "/usr/share/icons/breeze/actions/24/network-connect.svg"
        lui-logging-directory (expand-file-name "irc" doom-etc-dir)
        lui-logging-file-format "{buffer}/%Y/%m-%d.txt"
        circe-format-self-say "{nick:+13s} ┃ {body}")

  (custom-set-faces!
    '(circe-my-message-face :weight unspecified))

  (enable-lui-logging-globally)
  (enable-circe-display-images)

  (defun lui-org-to-irc ()
    "Examine a buffer with simple org-mode formatting, and converts the empasis:
  *bold*, /italic/, and _underline_ to IRC semi-standard escape codes.
  =code= is converted to inverse (highlighted) text."
    (goto-char (point-min))
    (while (re-search-forward "\\_<\\(?1:[*/_=]\\)\\(?2:[^[:space:]]\\(?:.*?[^[:space:]]\\)?\\)\\1\\_>" nil t)
      (replace-match
       (concat (pcase (match-string 1)
                 ("*" "")
                 ("/" "")
                 ("_" "")
                 ("=" ""))
               (match-string 2)
               "") nil nil)))
  
  (add-hook 'lui-pre-input-hook #'lui-org-to-irc)

  (defun lui-ascii-to-emoji ()
    (goto-char (point-min))
    (while (re-search-forward "\\( \\)?::?\\([^[:space:]:]+\\):\\( \\)?" nil t)
      (replace-match
       (concat
        (match-string 1)
        (or (cdr (assoc (match-string 2) lui-emojis-alist))
            (concat ":" (match-string 2) ":"))
        (match-string 3))
       nil nil)))
  
  (defun lui-emoticon-to-emoji ()
    (dolist (emoticon lui-emoticons-alist)
      (goto-char (point-min))
      (while (re-search-forward (concat " " (car emoticon) "\\( \\)?") nil t)
        (replace-match (concat " "
                               (cdr (assoc (cdr emoticon) lui-emojis-alist))
                               (match-string 1))))))
  
  (define-minor-mode lui-emojify
    "Replace :emojis: and ;) emoticons with unicode emoji chars."
    :global t
    :init-value t
    (if lui-emojify
        (add-hook! lui-pre-input #'lui-ascii-to-emoji #'lui-emoticon-to-emoji)
      (remove-hook! lui-pre-input #'lui-ascii-to-emoji #'lui-emoticon-to-emoji)))
  (defvar lui-emojis-alist
    '(("grinning"                      . "😀")
      ("smiley"                        . "😃")
      ("smile"                         . "😄")
      ("grin"                          . "😁")
      ("laughing"                      . "😆")
      ("sweat_smile"                   . "😅")
      ("joy"                           . "😂")
      ("rofl"                          . "🤣")
      ("relaxed"                       . "☺️")
      ("blush"                         . "😊")
      ("innocent"                      . "😇")
      ("slight_smile"                  . "🙂")
      ("upside_down"                   . "🙃")
      ("wink"                          . "😉")
      ("relieved"                      . "😌")
      ("heart_eyes"                    . "😍")
      ("yum"                           . "😋")
      ("stuck_out_tongue"              . "😛")
      ("stuck_out_tongue_closed_eyes"  . "😝")
      ("stuck_out_tongue_wink"         . "😜")
      ("zanzy"                         . "🤪")
      ("raised_eyebrow"                . "🤨")
      ("monocle"                       . "🧐")
      ("nerd"                          . "🤓")
      ("cool"                          . "😎")
      ("star_struck"                   . "🤩")
      ("party"                         . "🥳")
      ("smirk"                         . "😏")
      ("unamused"                      . "😒")
      ("disapointed"                   . "😞")
      ("pensive"                       . "😔")
      ("worried"                       . "😟")
      ("confused"                      . "😕")
      ("slight_frown"                  . "🙁")
      ("frown"                         . "☹️")
      ("persevere"                     . "😣")
      ("confounded"                    . "😖")
      ("tired"                         . "😫")
      ("weary"                         . "😩")
      ("pleading"                      . "🥺")
      ("tear"                          . "😢")
      ("cry"                           . "😢")
      ("sob"                           . "😭")
      ("triumph"                       . "😤")
      ("angry"                         . "😠")
      ("rage"                          . "😡")
      ("exploding_head"                . "🤯")
      ("flushed"                       . "😳")
      ("hot"                           . "🥵")
      ("cold"                          . "🥶")
      ("scream"                        . "😱")
      ("fearful"                       . "😨")
      ("disapointed"                   . "😰")
      ("relieved"                      . "😥")
      ("sweat"                         . "😓")
      ("thinking"                      . "🤔")
      ("shush"                         . "🤫")
      ("liar"                          . "🤥")
      ("blank_face"                    . "😶")
      ("neutral"                       . "😐")
      ("expressionless"                . "😑")
      ("grimace"                       . "😬")
      ("rolling_eyes"                  . "🙄")
      ("hushed"                        . "😯")
      ("frowning"                      . "😦")
      ("anguished"                     . "😧")
      ("wow"                           . "😮")
      ("astonished"                    . "😲")
      ("sleeping"                      . "😴")
      ("drooling"                      . "🤤")
      ("sleepy"                        . "😪")
      ("dizzy"                         . "😵")
      ("zipper_mouth"                  . "🤐")
      ("woozy"                         . "🥴")
      ("sick"                          . "🤢")
      ("vomiting"                      . "🤮")
      ("sneeze"                        . "🤧")
      ("mask"                          . "😷")
      ("bandaged_head"                 . "🤕")
      ("money_face"                    . "🤑")
      ("cowboy"                        . "🤠")
      ("imp"                           . "😈")
      ("ghost"                         . "👻")
      ("alien"                         . "👽")
      ("robot"                         . "🤖")
      ("clap"                          . "👏")
      ("thumpup"                       . "👍")
      ("+1"                            . "👍")
      ("thumbdown"                     . "👎")
      ("-1"                            . "👎")
      ("ok"                            . "👌")
      ("pinch"                         . "🤏")
      ("left"                          . "👈")
      ("right"                         . "👉")
      ("down"                          . "👇")
      ("wave"                          . "👋")
      ("pray"                          . "🙏")
      ("eyes"                          . "👀")
      ("brain"                         . "🧠")
      ("facepalm"                      . "🤦")
      ("tada"                          . "🎉")
      ("fire"                          . "🔥")
      ("flying_money"                  . "💸")
      ("lighbulb"                      . "💡")
      ("heart"                         . "❤️")
      ("sparkling_heart"               . "💖")
      ("heartbreak"                    . "💔")
      ("100"                           . "💯")))
  
  (defvar lui-emoticons-alist
    '((":)"   . "slight_smile")
      (";)"   . "wink")
      (":D"   . "smile")
      ("=D"   . "grin")
      ("xD"   . "laughing")
      (";("   . "joy")
      (":P"   . "stuck_out_tongue")
      (";D"   . "stuck_out_tongue_wink")
      ("xP"   . "stuck_out_tongue_closed_eyes")
      (":("   . "slight_frown")
      (";("   . "cry")
      (";'("  . "sob")
      (">:("  . "angry")
      (">>:(" . "rage")
      (":o"   . "wow")
      (":O"   . "astonished")
      (":/"   . "confused")
      (":-/"  . "thinking")
      (":|"   . "neutral")
      (":-|"  . "expressionless")))

  (defun named-circe-prompt ()
    (lui-set-prompt
     (concat (propertize (format "%13s > " (circe-nick))
                         'face 'circe-prompt-face)
             "")))
  (add-hook 'circe-chat-mode-hook #'named-circe-prompt)


  (appendq! nerd-icons-mode-icon-alist
            '((circe-channel-mode nerd-icons-mdicon "nf-md-message" :face nerd-icons-lblue)
              (circe-server-mode nerd-icons-mdicon "nf-md-chat_outline" :face nerd-icons-purple))))

(defun auth-server-pass (server)
  (if-let ((secret (plist-get (car (auth-source-search :host server)) :secret)))
      (if (functionp secret)
          (funcall secret) secret)
    (error "Could not fetch password for host %s" server)))

(defun register-irc-auths ()
  (require 'circe)
  (require 'dash)
  (let ((accounts (-filter (lambda (a) (string= "irc" (plist-get a :for)))
                           (auth-source-search :require '(:for) :max 10))))
    (appendq! circe-network-options
              (mapcar (lambda (entry)
                        (let* ((host (plist-get entry :host))
                               (label (or (plist-get entry :label) host))
                               (_ports (mapcar #'string-to-number
                                               (s-split "," (plist-get entry :port))))
                               (port (if (= 1 (length _ports)) (car _ports) _ports))
                               (user (plist-get entry :user))
                               (nick (or (plist-get entry :nick) user))
                               (channels (mapcar (lambda (c) (concat "#" c))
                                                 (s-split "," (plist-get entry :channels)))))
                          `(,label
                            :host ,host :port ,port :nick ,nick
                            :sasl-username ,user :sasl-password auth-server-pass
                            :channels ,channels)))
                      accounts))))

(add-transient-hook! #'=irc (register-irc-auths))

(map! :map elfeed-search-mode-map
      :after elfeed-search
      [remap kill-this-buffer] "q"
      [remap kill-buffer] "q"
      :n doom-leader-key nil
      :n "q" #'+rss/quit
      :n "e" #'elfeed-update
      :n "r" #'elfeed-search-untag-all-unread
      :n "u" #'elfeed-search-tag-all-unread
      :n "s" #'elfeed-search-live-filter
      :n "RET" #'elfeed-search-show-entry
      :n "p" #'elfeed-show-pdf
      :n "+" #'elfeed-search-tag-all
      :n "-" #'elfeed-search-untag-all
      :n "S" #'elfeed-search-set-filter
      :n "b" #'elfeed-search-browse-url
      :n "y" #'elfeed-search-yank)
(map! :map elfeed-show-mode-map
      :after elfeed-show
      [remap kill-this-buffer] "q"
      [remap kill-buffer] "q"
      :n doom-leader-key nil
      :nm "q" #'+rss/delete-pane
      :nm "o" #'ace-link-elfeed
      :nm "RET" #'org-ref-elfeed-add
      :nm "n" #'elfeed-show-next
      :nm "N" #'elfeed-show-prev
      :nm "p" #'elfeed-show-pdf
      :nm "+" #'elfeed-show-tag
      :nm "-" #'elfeed-show-untag
      :nm "s" #'elfeed-show-new-live-search
      :nm "y" #'elfeed-show-yank)

(after! elfeed-search
  (set-evil-initial-state! 'elfeed-search-mode 'normal))
(after! elfeed-show-mode
  (set-evil-initial-state! 'elfeed-show-mode   'normal))

(after! evil-snipe
  (push 'elfeed-show-mode   evil-snipe-disabled-modes)
  (push 'elfeed-search-mode evil-snipe-disabled-modes))

(after! elfeed

  (elfeed-org)
  (use-package! elfeed-link)

  (setq elfeed-search-filter "@1-week-ago +unread"
        elfeed-search-print-entry-function '+rss/elfeed-search-print-entry
        elfeed-search-title-min-width 80
        elfeed-show-entry-switch #'pop-to-buffer
        elfeed-show-entry-delete #'+rss/delete-pane
        elfeed-show-refresh-function #'+rss/elfeed-show-refresh--better-style
        shr-max-image-proportion 0.6)

  (add-hook! 'elfeed-show-mode-hook (hide-mode-line-mode 1))
  (add-hook! 'elfeed-search-update-hook #'hide-mode-line-mode)

  (defface elfeed-show-title-face '((t (:weight ultrabold :slant italic :height 1.5)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-author-face `((t (:weight light)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  ;; (set-face-attribute 'elfeed-search-title-face nil
  ;;                     :foreground 'nil
  ;;                     :weight 'light)

  (defadvice! +rss-elfeed-wrap-h-nicer ()
    "Enhances an elfeed entry's readability by wrapping it to a width of
`fill-column' and centering it with `visual-fill-column-mode'."
    :override #'+rss-elfeed-wrap-h
    (setq-local truncate-lines nil
                shr-width 120
                visual-fill-column-center-text t
                default-text-properties '(line-height 1.1))
    (let ((inhibit-read-only t)
          (inhibit-modification-hooks t))
      (visual-fill-column-mode)
      ;; (setq-local shr-current-font '(:family "Merriweather" :height 1.2))
      (set-buffer-modified-p nil)))

  (defun +rss/elfeed-search-print-entry (entry)
    "Print ENTRY to the buffer."
    (let* ((elfeed-goodies/tag-column-width 40)
           (elfeed-goodies/feed-source-column-width 30)
           (title (or (elfeed-meta entry :title) (elfeed-entry-title entry) ""))
           (title-faces (elfeed-search--faces (elfeed-entry-tags entry)))
           (feed (elfeed-entry-feed entry))
           (feed-title
            (when feed
              (or (elfeed-meta feed :title) (elfeed-feed-title feed))))
           (tags (mapcar #'symbol-name (elfeed-entry-tags entry)))
           (tags-str (concat (mapconcat 'identity tags ",")))
           (title-width (- (window-width) elfeed-goodies/feed-source-column-width
                           elfeed-goodies/tag-column-width 4))

           (tag-column (elfeed-format-column
                        tags-str (elfeed-clamp (length tags-str)
                                               elfeed-goodies/tag-column-width
                                               elfeed-goodies/tag-column-width)
                        :left))
           (feed-column (elfeed-format-column
                         feed-title (elfeed-clamp elfeed-goodies/feed-source-column-width
                                                  elfeed-goodies/feed-source-column-width
                                                  elfeed-goodies/feed-source-column-width)
                         :left)))

      (insert (propertize feed-column 'face 'elfeed-search-feed-face) " ")
      (insert (propertize tag-column 'face 'elfeed-search-tag-face) " ")
      (insert (propertize title 'face title-faces 'kbd-help title))
      (setq-local line-spacing 0.2)))

  (defun +rss/elfeed-show-refresh--better-style ()
    "Update the buffer to match the selected entry, using a mail-style."
    (interactive)
    (let* ((inhibit-read-only t)
           (title (elfeed-entry-title elfeed-show-entry))
           (date (seconds-to-time (elfeed-entry-date elfeed-show-entry)))
           (author (elfeed-meta elfeed-show-entry :author))
           (link (elfeed-entry-link elfeed-show-entry))
           (tags (elfeed-entry-tags elfeed-show-entry))
           (tagsstr (mapconcat #'symbol-name tags ", "))
           (nicedate (format-time-string "%a, %e %b %Y %T %Z" date))
           (content (elfeed-deref (elfeed-entry-content elfeed-show-entry)))
           (type (elfeed-entry-content-type elfeed-show-entry))
           (feed (elfeed-entry-feed elfeed-show-entry))
           (feed-title (elfeed-feed-title feed))
           (base (and feed (elfeed-compute-base (elfeed-feed-url feed)))))
      (erase-buffer)
      (insert "\n")
      (insert (format "%s\n\n" (propertize title 'face 'elfeed-show-title-face)))
      (insert (format "%s\t" (propertize feed-title 'face 'elfeed-search-feed-face)))
      (when (and author elfeed-show-entry-author)
        (insert (format "%s\n" (propertize author 'face 'elfeed-show-author-face))))
      (insert (format "%s\n\n" (propertize nicedate 'face 'elfeed-log-date-face)))
      (when tags
        (insert (format "%s\n"
                        (propertize tagsstr 'face 'elfeed-search-tag-face))))
      ;; (insert (propertize "Link: " 'face 'message-header-name))
      ;; (elfeed-insert-link link link)
      ;; (insert "\n")
      (cl-loop for enclosure in (elfeed-entry-enclosures elfeed-show-entry)
               do (insert (propertize "Enclosure: " 'face 'message-header-name))
               do (elfeed-insert-link (car enclosure))
               do (insert "\n"))
      (insert "\n")
      (if content
          (if (eq type 'html)
              (elfeed-insert-html content base)
            (insert content))
        (insert (propertize "(empty)\n" 'face 'italic)))
      (goto-char (point-min))))

  )

(after! elfeed-show
  (require 'url)

  (defvar elfeed-pdf-dir
    (expand-file-name "pdfs/"
                      (file-name-directory (directory-file-name elfeed-enclosure-default-dir))))

  (defvar elfeed-link-pdfs
    '(("https://www.jstatsoft.org/index.php/jss/article/view/v0\\([^/]+\\)" . "https://www.jstatsoft.org/index.php/jss/article/view/v0\\1/v\\1.pdf")
      ("http://arxiv.org/abs/\\([^/]+\\)" . "https://arxiv.org/pdf/\\1.pdf"))
    "List of alists of the form (REGEX-FOR-LINK . FORM-FOR-PDF)")

  (defun elfeed-show-pdf (entry)
    (interactive
     (list (or elfeed-show-entry (elfeed-search-selected :ignore-region))))
    (let ((link (elfeed-entry-link entry))
          (feed-name (plist-get (elfeed-feed-meta (elfeed-entry-feed entry)) :title))
          (title (elfeed-entry-title entry))
          (file-view-function
           (lambda (f)
             (when elfeed-show-entry
               (elfeed-kill-buffer))
             (pop-to-buffer (find-file-noselect f))))
          pdf)

      (let ((file (expand-file-name
                   (concat (subst-char-in-string ?/ ?, title) ".pdf")
                   (expand-file-name (subst-char-in-string ?/ ?, feed-name)
                                     elfeed-pdf-dir))))
        (if (file-exists-p file)
            (funcall file-view-function file)
          (dolist (link-pdf elfeed-link-pdfs)
            (when (and (string-match-p (car link-pdf) link)
                       (not pdf))
              (setq pdf (replace-regexp-in-string (car link-pdf) (cdr link-pdf) link))))
          (if (not pdf)
              (message "No associated PDF for entry")
            (message "Fetching %s" pdf)
            (unless (file-exists-p (file-name-directory file))
              (make-directory (file-name-directory file) t))
            (url-copy-file pdf file)
            (funcall file-view-function file))))))

  )

(use-package! lexic
  :commands lexic-search lexic-list-dictionary
  :config
  (map! :map lexic-mode-map
        :n "q" #'lexic-return-from-lexic
        :nv "RET" #'lexic-search-word-at-point
        :n "a" #'outline-show-all
        :n "h" (cmd! (outline-hide-sublevels 3))
        :n "o" #'lexic-toggle-entry
        :n "n" #'lexic-next-entry
        :n "N" (cmd! (lexic-next-entry t))
        :n "p" #'lexic-previous-entry
        :n "P" (cmd! (lexic-previous-entry t))
        :n "E" (cmd! (lexic-return-from-lexic) ; expand
                     (switch-to-buffer (lexic-get-buffer)))
        :n "M" (cmd! (lexic-return-from-lexic) ; minimise
                     (lexic-goto-lexic))
        :n "C-p" #'lexic-search-history-backwards
        :n "C-n" #'lexic-search-history-forwards
        :n "/" (cmd! (call-interactively #'lexic-search))))

(defadvice! +lookup/dictionary-definition-lexic (identifier &optional arg)
  "Look up the definition of the word at point (or selection) using `lexic-search'."
  :override #'+lookup/dictionary-definition
  (interactive
   (list (or (doom-thing-at-point-or-region 'word)
             (read-string "Look up in dictionary: "))
         current-prefix-arg))
  (lexic-search identifier nil nil t))

(defvar mu4e-reindex-request-file "/tmp/mu_reindex_now"
  "Location of the reindex request, signaled by existance")
(defvar mu4e-reindex-request-min-seperation 5.0
  "Don't refresh again until this many second have elapsed.
Prevents a series of redisplays from being called (when set to an appropriate value)")

(defvar mu4e-reindex-request--file-watcher nil)
(defvar mu4e-reindex-request--file-just-deleted nil)
(defvar mu4e-reindex-request--last-time 0)

(defun mu4e-reindex-request--add-watcher ()
  (setq mu4e-reindex-request--file-just-deleted nil)
  (setq mu4e-reindex-request--file-watcher
        (file-notify-add-watch mu4e-reindex-request-file
                               '(change)
                               #'mu4e-file-reindex-request)))

(defadvice! mu4e-stop-watching-for-reindex-request ()
  :after #'mu4e--server-kill
  (if mu4e-reindex-request--file-watcher
      (file-notify-rm-watch mu4e-reindex-request--file-watcher)))

(defadvice! mu4e-watch-for-reindex-request ()
  :after #'mu4e--server-start
  (mu4e-stop-watching-for-reindex-request)
  (when (file-exists-p mu4e-reindex-request-file)
    (delete-file mu4e-reindex-request-file))
  (mu4e-reindex-request--add-watcher))

(defun mu4e-file-reindex-request (event)
  "Act based on the existance of `mu4e-reindex-request-file'"
  (if mu4e-reindex-request--file-just-deleted
      (mu4e-reindex-request--add-watcher)
    (when (equal (nth 1 event) 'created)
      (delete-file mu4e-reindex-request-file)
      (setq mu4e-reindex-request--file-just-deleted t)
      (mu4e-reindex-maybe t))))

(defun mu4e-reindex-maybe (&optional new-request)
  "Run `mu4e--server-index' if it's been more than
`mu4e-reindex-request-min-seperation'seconds since the last request,"
  (let ((time-since-last-request (- (float-time)
                                    mu4e-reindex-request--last-time)))
    (when new-request
      (setq mu4e-reindex-request--last-time (float-time)))
    (if (> time-since-last-request mu4e-reindex-request-min-seperation)
        (mu4e--server-index nil t)
      (when new-request
        (run-at-time (* 1.1 mu4e-reindex-request-min-seperation) nil
                     #'mu4e-reindex-maybe)))))
(setq mu4e-headers-fields
      '((:flags . 6)
        (:account-stripe . 2)
        (:from-or-to . 25)
        (:folder . 10)
        (:recipnum . 2)
        (:subject . 80)
        (:human-date . 8))
      +mu4e-min-header-frame-width 142
      mu4e-headers-date-format "%d/%m/%y"
      mu4e-headers-time-format "⧖ %H:%M"
      mu4e-headers-results-limit 1000
      mu4e-index-cleanup t)

(defvar +mu4e-header--folder-colors nil)
;; (setq mu4e-alert-icon "/usr/share/icons/Papirus/64x64/apps/evolution.svg")
(setq sendmail-program "/usr/bin/msmtp"
      send-mail-function #'smtpmail-send-it
      message-sendmail-f-is-evil t
      message-sendmail-extra-arguments '("--read-envelope-from"); , "--read-recipients")
      message-send-mail-function #'message-send-mail-with-sendmail)
(defun mu4e-compose-from-mailto (mailto-string &optional quit-frame-after)
  (require 'mu4e)
  (unless mu4e--server-props (mu4e t) (sleep-for 0.1))
  (let* ((mailto (message-parse-mailto-url mailto-string))
         (to (cadr (assoc "to" mailto)))
         (subject (or (cadr (assoc "subject" mailto)) ""))
         (body (cadr (assoc "body" mailto)))
         (headers (-filter (lambda (spec) (not (-contains-p '("to" "subject" "body") (car spec)))) mailto)))
    (when-let ((mu4e-main (get-buffer mu4e-main-buffer-name)))
      (switch-to-buffer mu4e-main))
    (mu4e~compose-mail to subject headers)
    (when body
      (goto-char (point-min))
      (if (eq major-mode 'org-msg-edit-mode)
          (org-msg-goto-body)
        (mu4e-compose-goto-bottom))
      (insert body))
    (goto-char (point-min))
    (cond ((null to) (search-forward "To: "))
          ((string= "" subject) (search-forward "Subject: "))
          (t (if (eq major-mode 'org-msg-edit-mode)
                 (org-msg-goto-body)
               (mu4e-compose-goto-bottom))))
    (font-lock-ensure)
    (when evil-normal-state-minor-mode
      (evil-append 1))
    (when quit-frame-after
      (add-hook 'kill-buffer-hook
                `(lambda ()
                   (when (eq (selected-frame) ,(selected-frame))
                     (delete-frame)))))))
(defvar mu4e-from-name "Preston"
  "Name used in \"From:\" template.")
(defadvice! mu4e~draft-from-construct-renamed (orig-fn)
  "Wrap `mu4e~draft-from-construct-renamed' to change the name."
  :around #'mu4e~draft-from-construct
  (let ((user-full-name mu4e-from-name))
    (funcall orig-fn)))
(setq message-signature mu4e-from-name)
(defun +mu4e-update-personal-addresses ()
  (let ((primary-address
         (car (cl-remove-if-not
               (lambda (a) (eq (mod (apply #'* (cl-coerce a 'list)) 600) 0))
               (mu4e-personal-addresses)))))
    (setq +mu4e-personal-addresses
          (and primary-address
               (append (mu4e-personal-addresses)
                       (mapcar
                        (lambda (subalias)
                          (concat subalias "@"
                                  (subst-char-in-string ?@ ?. primary-address)))
                        '("orgmode"))
                       (mapcar
                        (lambda (alias)
                          (replace-regexp-in-string
                           "\\`\\(.*\\)@" alias primary-address t t 1))
                        '("contact" "preston")))))))

(add-transient-hook! 'mu4e-compose-pre-hook
  (+mu4e-update-personal-addresses))
(defun +mu4e-account-sent-folder (&optional msg)
  (let ((from (if msg
                  (plist-get (car (plist-get msg :from)) :email)
                (save-restriction
                  (mail-narrow-to-head)
                  (mail-fetch-field "from")))))
    (if (and from (string-match-p "@tecosaur\\.net>?\\'" from))
        "/tecosaur-net/Sent"
      "/sent")))
(setq mu4e-sent-folder #'+mu4e-account-sent-folder)
(defun +mu4e-evil-enter-insert-mode ()
  (when (eq (bound-and-true-p evil-state) 'normal)
    (call-interactively #'evil-append)))

(add-hook 'mu4e-compose-mode-hook #'+mu4e-evil-enter-insert-mode 90)

(setq org-msg-greeting-fmt "\nHi%s,\n\n"
      org-msg-signature "\n\n#+begin_signature\nAll the best,\\\\\n@@html:<b>@@Timothy@@html:</b>@@\n#+end_signature")

(defun +org-msg-goto-body (&optional end)
  "Go to either the beginning or the end of the body.
END can be the symbol top, bottom, or nil to toggle."
  (interactive)
  (let ((initial-pos (point)))
    (org-msg-goto-body)
    (when (or (eq end 'top)
              (and (or (eq initial-pos (point)) ; Already at bottom
                       (<= initial-pos ; Above message body
                           (save-excursion
                             (message-goto-body)
                             (point))))
                   (not (eq end 'bottom))))
      (message-goto-body)
      (search-forward (format org-msg-greeting-fmt
                              (concat " " (org-msg-get-to-name)))))))

(map! :map org-msg-edit-mode-map
      :after org-msg
      :n "G" #'+org-msg-goto-body)

(defun +org-msg-goto-body-when-replying (compose-type &rest _)
  "Call `+org-msg-goto-body' when the current message is a reply."
  (when (and org-msg-edit-mode (eq compose-type 'reply))
    (+org-msg-goto-body)))

(advice-add 'mu4e~compose-handler :after #'+org-msg-goto-body-when-replying)

(set-file-template! "\\.tex$" :trigger "__" :mode 'latex-mode)
(set-file-template! "\\.org$" :trigger "__" :mode 'org-mode)
(set-file-template! "/LICEN[CS]E$" :trigger '+file-templates/insert-license)

(after! text-mode
  (add-hook! 'text-mode-hook
    (unless (derived-mode-p 'org-mode)
      ;; Apply ANSI color codes
      (with-silent-modifications
        (ansi-color-apply-on-region (point-min) (point-max) t)))))

(defvar +text-mode-left-margin-width 1
  "The `left-margin-width' to be used in `text-mode' buffers.")

(defun +setup-text-mode-left-margin ()
  (when (and (derived-mode-p 'text-mode)
             (not (and (bound-and-true-p visual-fill-column-mode)
                       visual-fill-column-center-text))
             (eq (current-buffer) ; Check current buffer is active.
                 (window-buffer (frame-selected-window))))
    (setq left-margin-width (if display-line-numbers
                                0 +text-mode-left-margin-width))
    (set-window-buffer (get-buffer-window (current-buffer))
                       (current-buffer))))

(add-hook 'window-configuration-change-hook #'+setup-text-mode-left-margin)
(add-hook 'display-line-numbers-mode-hook #'+setup-text-mode-left-margin)
(add-hook 'text-mode-hook #'+setup-text-mode-left-margin)

(defadvice! +doom/toggle-line-numbers--call-hook-a ()
  :after #'doom/toggle-line-numbers
  (run-hooks 'display-line-numbers-mode-hook))

(remove-hook 'text-mode-hook #'display-line-numbers-mode)

(use-package! org-modern
  :hook (org-mode . org-modern-mode)
  :config
  (setq org-modern-star '("◉" "○" "✸" "✿" "✤" "✜" "◆" "▶")
        org-modern-table-vertical 1
        org-modern-table-horizontal 0.2
        org-modern-list '((43 . "➤")
                          (45 . "–")
                          (42 . "•"))
        org-modern-todo-faces
        '(("TODO" :inverse-video t :inherit org-todo)
          ("PROJ" :inverse-video t :inherit +org-todo-project)
          ("STRT" :inverse-video t :inherit +org-todo-active)
          ("[-]"  :inverse-video t :inherit +org-todo-active)
          ("HOLD" :inverse-video t :inherit +org-todo-onhold)
          ("WAIT" :inverse-video t :inherit +org-todo-onhold)
          ("[?]"  :inverse-video t :inherit +org-todo-onhold)
          ("KILL" :inverse-video t :inherit +org-todo-cancel)
          ("NO"   :inverse-video t :inherit +org-todo-cancel))
        org-modern-footnote
        (cons nil (cadr org-script-display))
        org-modern-block-fringe nil
        org-modern-block-name
        '((t . t)
          ("src" "»" "«")
          ("example" "»–" "–«")
          ("quote" "❝" "❞")
          ("export" "⏩" "⏪"))
        org-modern-progress nil
        org-modern-priority nil
        org-modern-horizontal-rule (make-string 36 ?─)
        org-modern-keyword
        '((t . t)
          ("title" . "𝙏")
          ("subtitle" . "𝙩")
          ("author" . "𝘼")
          ("email" . #("" 0 1 (display (raise -0.14))))
          ("date" . "𝘿")
          ("property" . "☸")
          ("options" . "⌥")
          ("startup" . "⏻")
          ("macro" . "𝓜")
          ("bind" . #("" 0 1 (display (raise -0.1))))
          ("bibliography" . "")
          ("print_bibliography" . #("" 0 1 (display (raise -0.1))))
          ("cite_export" . "⮭")
          ("print_glossary" . #("ᴬᶻ" 0 1 (display (raise -0.1))))
          ("glossary_sources" . #("" 0 1 (display (raise -0.14))))
          ("include" . "⇤")
          ("setupfile" . "⇚")
          ("html_head" . "🅷")
          ("html" . "🅗")
          ("latex_class" . "🄻")
          ("latex_class_options" . #("🄻" 1 2 (display (raise -0.14))))
          ("latex_header" . "🅻")
          ("latex_header_extra" . "🅻⁺")
          ("latex" . "🅛")
          ("beamer_theme" . "🄱")
          ("beamer_color_theme" . #("🄱" 1 2 (display (raise -0.12))))
          ("beamer_font_theme" . "🄱𝐀")
          ("beamer_header" . "🅱")
          ("beamer" . "🅑")
          ("attr_latex" . "🄛")
          ("attr_html" . "🄗")
          ("attr_org" . "⒪")
          ("call" . #("" 0 1 (display (raise -0.15))))
          ("name" . "⁍")
          ("header" . "›")
          ("caption" . "☰")
          ("results" . "🠶")))
  (custom-set-faces! '(org-modern-statistics :inherit org-checkbox-statistics-todo)))

(after! spell-fu
  (cl-pushnew 'org-modern-tag (alist-get 'org-mode +spell-excluded-faces-alist)))

(use-package! org-appear
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autolinks nil)
  ;; for proper first-time setup, `org-appear--set-elements'
  ;; needs to be run after other hooks have acted.
  (run-at-time nil nil #'org-appear--set-elements))

(use-package! org-ol-tree
  :commands org-ol-tree
  :config
  (setq org-ol-tree-ui-icon-set
        (if (and (display-graphic-p)
                 (fboundp 'all-the-icons-material))
            'all-the-icons
          'unicode))
  (org-ol-tree-ui--update-icon-set))

(map! :map org-mode-map
      :after org
      :localleader
      :desc "Outline" "O" #'org-ol-tree)

(use-package! ob-http
  :commands org-babel-execute:http)

(use-package! org-transclusion
  :commands org-transclusion-mode
  :init
  (map! :after org :map org-mode-map
        "<f12>" #'org-transclusion-mode))

(use-package! org-chef
  :commands (org-chef-insert-recipe org-chef-get-recipe-from-url))

(use-package! org-pandoc-import
  :after org)

(use-package! org-glossary
  :hook (org-mode . org-glossary-mode)
  :config
  (setq org-glossary-collection-root "~/.config/doom/misc/glossaries/")
  (defun +org-glossary--latex-cdef (backend info term-entry form &optional ref-index plural-p capitalized-p extra-parameters)
    (org-glossary--export-template
     (if (plist-get term-entry :uses)
         "*%d*\\emsp{}%v\\ensp{}@@latex:\\labelcpageref{@@%b@@latex:}@@\n"
       "*%d*\\emsp{}%v\n")
     backend info term-entry ref-index
     plural-p capitalized-p extra-parameters))
  (org-glossary-set-export-spec
   'latex t
   :backref "gls-%K-use-%r"
   :backref-seperator ","
   :definition-structure #'+org-glossary--latex-cdef))

(use-package! org-music
  :after org
  :config
  (setq org-music-mpris-player "Lollypop"
        org-music-track-search-method 'beets
        org-music-beets-db "~/Music/library.db"))

;; (use-package! org-tanglesync
;;   :after org
;;   :hook ((org-mode . org-tanglesync-mode)
;;          ;; enable watch-mode globally:
;;          ((prog-mode text-mode) . org-tanglesync-watch-mode))
;;   :init
;;   (map! :after org :map org-mode-map
;;         "C-c M-i" #'org-tanglesync-process-buffer-interactive
;;         "C-c M-a" #'org-tanglesync-process-buffer-automatic)
;;   :config
;;   (setq org-tanglesync-watch-files '("config.org")))

(after! org
  (setq org-directory (substitute-in-file-name "$XDG_DATA_HOME/org") ; Let's put files here.
        org-agenda-files (list org-directory)                  ; Seems like the obvious place.
        org-use-property-inheritance t                         ; It's convenient to have properties inherited.
        org-log-done 'time                                     ; Having the time a item is done sounds convenient.
        org-list-allow-alphabetical t                          ; Have a. A. a) A) list bullets.
        org-catch-invisible-edits 'smart                       ; Try not to accidently do weird stuff in invisible regions.
        org-export-with-sub-superscripts '{}                   ; Don't treat lone _ / ^ as sub/superscripts, require _{} / ^{}.
        org-export-allow-bind-keywords t                       ; Bind keywords can be handy
        org-image-actual-width '(0.9))                         ; Make the in-buffer display closer to the exported result..
  (setq org-babel-default-header-args
        '((:session . "none")
          (:results . "replace")
          (:exports . "code")
          (:cache . "no")
          (:noweb . "no")
          (:hlines . "no")
          (:tangle . "no")
          (:comments . "link")))
  (remove-hook 'text-mode-hook #'visual-line-mode)
  (add-hook 'text-mode-hook #'auto-fill-mode)
  (map! :map evil-org-mode-map
        :after evil-org
        :n "g <up>" #'org-backward-heading-same-level
        :n "g <down>" #'org-forward-heading-same-level
        :n "g <left>" #'org-up-element
        :n "g <right>" #'org-down-element)
  (map! :map org-mode-map
        :nie "M-SPC M-SPC" (cmd! (insert "\u200B")))
  (defun +org-export-remove-zero-width-space (text _backend _info)
    "Remove zero width spaces from TEXT."
    (unless (org-export-derived-backend-p 'org)
      (replace-regexp-in-string "\u200B" "" text)))
  
  (after! ox
    (add-to-list 'org-export-filter-final-output-functions #'+org-export-remove-zero-width-space t))
  (setq org-list-demote-modify-bullet '(("+" . "-") ("-" . "+") ("*" . "+") ("1." . "a.")))
  (defun +org-insert-file-link ()
    "Insert a file link.  At the prompt, enter the filename."
    (interactive)
    (insert (format "[[%s]]" (org-link-complete-file))))
  (map! :after org
        :map org-mode-map
        :localleader
        "l f" #'+org-insert-file-link)
  (add-hook 'org-mode-hook 'turn-on-org-cdlatex)
  (defadvice! org-edit-latex-emv-after-insert ()
    :after #'org-cdlatex-environment-indent
    (org-edit-latex-environment))
  (cl-defmacro lsp-org-babel-enable (lang)
    "Support LANG in org source code block."
    (setq centaur-lsp 'lsp-mode)
    (cl-check-type lang stringp)
    (let* ((edit-pre (intern (format "org-babel-edit-prep:%s" lang)))
           (intern-pre (intern (format "lsp--%s" (symbol-name edit-pre)))))
      `(progn
         (defun ,intern-pre (info)
           (let ((file-name (->> info caddr (alist-get :file))))
             (unless file-name
               (setq file-name (make-temp-file "babel-lsp-")))
             (setq buffer-file-name file-name)
             (lsp-deferred)))
         (put ',intern-pre 'function-documentation
              (format "Enable lsp-mode in the buffer of org source block (%s)."
                      (upcase ,lang)))
         (if (fboundp ',edit-pre)
             (advice-add ',edit-pre :after ',intern-pre)
           (progn
             (defun ,edit-pre (info)
               (,intern-pre info))
             (put ',edit-pre 'function-documentation
                  (format "Prepare local buffer environment for org source block (%s)."
                          (upcase ,lang))))))))
  (defvar org-babel-lang-list
    '("go" "python" "ipython" "bash" "sh" "cpp"))
  (dolist (lang org-babel-lang-list)
    (eval `(lsp-org-babel-enable ,lang)))
  (map! :map org-mode-map
        :localleader
        :desc "View exported file" "v" #'org-view-output-file)
  
  (defun org-view-output-file (&optional org-file-path)
    "Visit buffer open on the first output file (if any) found, using `org-view-output-file-extensions'"
    (interactive)
    (let* ((org-file-path (or org-file-path (buffer-file-name) ""))
           (dir (file-name-directory org-file-path))
           (basename (file-name-base org-file-path))
           (output-file nil))
      (dolist (ext org-view-output-file-extensions)
        (unless output-file
          (when (file-exists-p
                 (concat dir basename "." ext))
            (setq output-file (concat dir basename "." ext)))))
      (if output-file
          (if (member (file-name-extension output-file) org-view-external-file-extensions)
              (browse-url-xdg-open output-file)
            (pop-to-buffer (or (find-buffer-visiting output-file)
                               (find-file-noselect output-file))))
        (message "No exported file found"))))
  
  (defvar org-view-output-file-extensions '("pdf" "md" "rst" "txt" "tex" "html")
    "Search for output files with these extensions, in order, viewing the first that matches")
  (defvar org-view-external-file-extensions '("html")
    "File formats that should be opened externally.")
  (use-package! doct
    :commands doct)
  (after! org-capture
    (defun org-capture-select-template-prettier (&optional keys)
      "Select a capture template, in a prettier way than default
    Lisp programs can force the template by setting KEYS to a string."
      (let ((org-capture-templates
             (or (org-contextualize-keys
                  (org-capture-upgrade-templates org-capture-templates)
                  org-capture-templates-contexts)
                 '(("t" "Task" entry (file+headline "" "Tasks")
                    "* TODO %?\n  %u\n  %a")))))
        (if keys
            (or (assoc keys org-capture-templates)
                (error "No capture template referred to by \"%s\" keys" keys))
          (org-mks org-capture-templates
                   "Select a capture template\n━━━━━━━━━━━━━━━━━━━━━━━━━"
                   "Template key: "
                   `(("q" ,(concat (nerd-icons-octicon "nf-oct-stop" :face 'nerd-icons-red :v-adjust 0.01) "\tAbort")))))))
    (advice-add 'org-capture-select-template :override #'org-capture-select-template-prettier)
    
    (defun org-mks-pretty (table title &optional prompt specials)
      "Select a member of an alist with multiple keys. Prettified.
    
    TABLE is the alist which should contain entries where the car is a string.
    There should be two types of entries.
    
    1. prefix descriptions like (\"a\" \"Description\")
       This indicates that `a' is a prefix key for multi-letter selection, and
       that there are entries following with keys like \"ab\", \"ax\"…
    
    2. Select-able members must have more than two elements, with the first
       being the string of keys that lead to selecting it, and the second a
       short description string of the item.
    
    The command will then make a temporary buffer listing all entries
    that can be selected with a single key, and all the single key
    prefixes.  When you press the key for a single-letter entry, it is selected.
    When you press a prefix key, the commands (and maybe further prefixes)
    under this key will be shown and offered for selection.
    
    TITLE will be placed over the selection in the temporary buffer,
    PROMPT will be used when prompting for a key.  SPECIALS is an
    alist with (\"key\" \"description\") entries.  When one of these
    is selected, only the bare key is returned."
      (save-window-excursion
        (let ((inhibit-quit t)
              (buffer (org-switch-to-buffer-other-window "*Org Select*"))
              (prompt (or prompt "Select: "))
              case-fold-search
              current)
          (unwind-protect
              (catch 'exit
                (while t
                  (setq-local evil-normal-state-cursor (list nil))
                  (erase-buffer)
                  (insert title "\n\n")
                  (let ((des-keys nil)
                        (allowed-keys '("\C-g"))
                        (tab-alternatives '("\s" "\t" "\r"))
                        (cursor-type nil))
                    ;; Populate allowed keys and descriptions keys
                    ;; available with CURRENT selector.
                    (let ((re (format "\\`%s\\(.\\)\\'"
                                      (if current (regexp-quote current) "")))
                          (prefix (if current (concat current " ") "")))
                      (dolist (entry table)
                        (pcase entry
                          ;; Description.
                          (`(,(and key (pred (string-match re))) ,desc)
                           (let ((k (match-string 1 key)))
                             (push k des-keys)
                             ;; Keys ending in tab, space or RET are equivalent.
                             (if (member k tab-alternatives)
                                 (push "\t" allowed-keys)
                               (push k allowed-keys))
                             (insert (propertize prefix 'face 'font-lock-comment-face) (propertize k 'face 'bold) (propertize "›" 'face 'font-lock-comment-face) "  " desc "…" "\n")))
                          ;; Usable entry.
                          (`(,(and key (pred (string-match re))) ,desc . ,_)
                           (let ((k (match-string 1 key)))
                             (insert (propertize prefix 'face 'font-lock-comment-face) (propertize k 'face 'bold) "   " desc "\n")
                             (push k allowed-keys)))
                          (_ nil))))
                    ;; Insert special entries, if any.
                    (when specials
                      (insert "─────────────────────────\n")
                      (pcase-dolist (`(,key ,description) specials)
                        (insert (format "%s   %s\n" (propertize key 'face '(bold nerd-icons-red)) description))
                        (push key allowed-keys)))
                    ;; Display UI and let user select an entry or
                    ;; a sub-level prefix.
                    (goto-char (point-min))
                    (unless (pos-visible-in-window-p (point-max))
                      (org-fit-window-to-buffer))
                    (let ((pressed (org--mks-read-key allowed-keys
                                                      prompt
                                                      (not (pos-visible-in-window-p (1- (point-max)))))))
                      (setq current (concat current pressed))
                      (cond
                       ((equal pressed "\C-g") (user-error "Abort"))
                       ;; Selection is a prefix: open a new menu.
                       ((member pressed des-keys))
                       ;; Selection matches an association: return it.
                       ((let ((entry (assoc current table)))
                          (and entry (throw 'exit entry))))
                       ;; Selection matches a special entry: return the
                       ;; selection prefix.
                       ((assoc current specials) (throw 'exit current))
                       (t (error "No entry available")))))))
            (when buffer (kill-buffer buffer))))))
    (advice-add 'org-mks :override #'org-mks-pretty)
  
    (defun +doct-icon-declaration-to-icon (declaration)
      "Convert :icon declaration to icon"
      (let ((name (pop declaration))
            (set  (intern (concat "nerd-icons-" (plist-get declaration :set))))
            (face (intern (concat "nerd-icons-" (plist-get declaration :color))))
            (v-adjust (or (plist-get declaration :v-adjust) 0.01)))
        (apply set `(,name :face ,face :v-adjust ,v-adjust))))
  
    (defun +doct-iconify-capture-templates (groups)
      "Add declaration's :icon to each template group in GROUPS."
      (let ((templates (doct-flatten-lists-in groups)))
        (setq doct-templates (mapcar (lambda (template)
                                       (when-let* ((props (nthcdr (if (= (length template) 4) 2 5) template))
                                                   (spec (plist-get (plist-get props :doct) :icon)))
                                         (setf (nth 1 template) (concat (+doct-icon-declaration-to-icon spec)
                                                                        "\t"
                                                                        (nth 1 template))))
                                       template)
                                     templates))))
  
    (setq doct-after-conversion-functions '(+doct-iconify-capture-templates))
  
    (defvar +org-capture-recipies  "~/Desktop/TEC/Organisation/recipies.org")
  
    (defun set-org-capture-templates ()
      (setq org-capture-templates
            (doct `(("Personal todo" :keys "t"
                     :icon ("nf-oct-checklist" :set "octicon" :color "green")
                     :file +org-capture-todo-file
                     :prepend t
                     :headline "Inbox"
                     :type entry
                     :template ("* TODO %?"
                                "%i %a"))
                    ("Personal note" :keys "n"
                     :icon ("nf-fa-sticky_note_o" :set "faicon" :color "green")
                     :file +org-capture-todo-file
                     :prepend t
                     :headline "Inbox"
                     :type entry
                     :template ("* %?"
                                "%i %a"))
                    ("Email" :keys "e"
                     :icon ("nf-fa-envelope" :set "faicon" :color "blue")
                     :file +org-capture-todo-file
                     :prepend t
                     :headline "Inbox"
                     :type entry
                     :template ("* TODO %^{type|reply to|contact} %\\3 %? :email:"
                                "Send an email %^{urgancy|soon|ASAP|anon|at some point|eventually} to %^{recipiant}"
                                "about %^{topic}"
                                "%U %i %a"))
                    ("Interesting" :keys "i"
                     :icon ("nf-fa-eye" :set "faicon" :color "lcyan")
                     :file +org-capture-todo-file
                     :prepend t
                     :headline "Interesting"
                     :type entry
                     :template ("* [ ] %{desc}%? :%{i-type}:"
                                "%i %a")
                     :children (("Webpage" :keys "w"
                                 :icon ("nf-fa-globe" :set "faicon" :color "green")
                                 :desc "%(org-cliplink-capture) "
                                 :i-type "read:web")
                                ("Article" :keys "a"
                                 :icon ("nf-fa-file_text_o" :set "faicon" :color "yellow")
                                 :desc ""
                                 :i-type "read:reaserch")
                                ("\tRecipie" :keys "r"
                                 :icon ("nf-fa-spoon" :set "faicon" :color "dorange")
                                 :file +org-capture-recipies
                                 :headline "Unsorted"
                                 :template "%(org-chef-get-recipe-from-url)")
                                ("Information" :keys "i"
                                 :icon ("nf-fa-info_circle" :set "faicon" :color "blue")
                                 :desc ""
                                 :i-type "read:info")
                                ("Idea" :keys "I"
                                 :icon ("nf-md-chart_bubble" :set "mdicon" :color "silver")
                                 :desc ""
                                 :i-type "idea")))
                    ("Tasks" :keys "k"
                     :icon ("nf-oct-inbox" :set "octicon" :color "yellow")
                     :file +org-capture-todo-file
                     :prepend t
                     :headline "Tasks"
                     :type entry
                     :template ("* TODO %? %^G%{extra}"
                                "%i %a")
                     :children (("General Task" :keys "k"
                                 :icon ("nf-oct-inbox" :set "octicon" :color "yellow")
                                 :extra "")
                                ("Task with deadline" :keys "d"
                                 :icon ("nf-md-timer" :set "mdicon" :color "orange" :v-adjust -0.1)
                                 :extra "\nDEADLINE: %^{Deadline:}t")
                                ("Scheduled Task" :keys "s"
                                 :icon ("nf-oct-calendar" :set "octicon" :color "orange")
                                 :extra "\nSCHEDULED: %^{Start time:}t")))
                    ("Project" :keys "p"
                     :icon ("nf-oct-repo" :set "octicon" :color "silver")
                     :prepend t
                     :type entry
                     :headline "Inbox"
                     :template ("* %{time-or-todo} %?"
                                "%i"
                                "%a")
                     :file ""
                     :custom (:time-or-todo "")
                     :children (("Project-local todo" :keys "t"
                                 :icon ("nf-oct-checklist" :set "octicon" :color "green")
                                 :time-or-todo "TODO"
                                 :file +org-capture-project-todo-file)
                                ("Project-local note" :keys "n"
                                 :icon ("nf-fa-sticky_note" :set "faicon" :color "yellow")
                                 :time-or-todo "%U"
                                 :file +org-capture-project-notes-file)
                                ("Project-local changelog" :keys "c"
                                 :icon ("nf-fa-list" :set "faicon" :color "blue")
                                 :time-or-todo "%U"
                                 :heading "Unreleased"
                                 :file +org-capture-project-changelog-file)))
                    ("\tCentralised project templates"
                     :keys "o"
                     :type entry
                     :prepend t
                     :template ("* %{time-or-todo} %?"
                                "%i"
                                "%a")
                     :children (("Project todo"
                                 :keys "t"
                                 :prepend nil
                                 :time-or-todo "TODO"
                                 :heading "Tasks"
                                 :file +org-capture-central-project-todo-file)
                                ("Project note"
                                 :keys "n"
                                 :time-or-todo "%U"
                                 :heading "Notes"
                                 :file +org-capture-central-project-notes-file)
                                ("Project changelog"
                                 :keys "c"
                                 :time-or-todo "%U"
                                 :heading "Unreleased"
                                 :file +org-capture-central-project-changelog-file)))))))
  
    (set-org-capture-templates)
    (unless (display-graphic-p)
      (add-hook 'server-after-make-frame-hook
                (defun org-capture-reinitialise-hook ()
                  (when (display-graphic-p)
                    (set-org-capture-templates)
                    (remove-hook 'server-after-make-frame-hook
                                 #'org-capture-reinitialise-hook))))))
  (setq +org-capture-fn
        (lambda ()
          (interactive)
          (set-window-parameter nil 'mode-line-format 'none)
          (org-capture)))
  (defvar org-reference-contraction-max-words 3
    "Maximum number of words in a reference reference.")
  (defvar org-reference-contraction-max-length 35
    "Maximum length of resulting reference reference, including joining characters.")
  (defvar org-reference-contraction-stripped-words
    '("the" "on" "in" "off" "a" "for" "by" "of" "and" "is" "to")
    "Superfluous words to be removed from a reference.")
  (defvar org-reference-contraction-joining-char "-"
    "Character used to join words in the reference reference.")
  
  (defun org-reference-contraction-truncate-words (words)
    "Using `org-reference-contraction-max-length' as the total character 'budget' for the WORDS
  and truncate individual words to conform to this budget.
  
  To arrive at a budget that accounts for words undershooting their requisite average length,
  the number of characters in the budget freed by short words is distributed among the words
  exceeding the average length.  This adjusts the per-word budget to be the maximum feasable for
  this particular situation, rather than the universal maximum average.
  
  This budget-adjusted per-word maximum length is given by the mathematical expression below:
  
  max length = \\floor{ \\frac{total length - chars for seperators - \\sum_{word \\leq average length} length(word) }{num(words) > average length} }"
    ;; trucate each word to a max word length determined by
    ;;
    (let* ((total-length-budget (- org-reference-contraction-max-length  ; how many non-separator chars we can use
                                   (1- (length words))))
           (word-length-budget (/ total-length-budget                      ; max length of each word to keep within budget
                                  org-reference-contraction-max-words))
           (num-overlong (-count (lambda (word)                            ; how many words exceed that budget
                                   (> (length word) word-length-budget))
                                 words))
           (total-short-length (-sum (mapcar (lambda (word)                ; total length of words under that budget
                                               (if (<= (length word) word-length-budget)
                                                   (length word) 0))
                                             words)))
           (max-length (/ (- total-length-budget total-short-length)       ; max(max-length) that we can have to fit within the budget
                          num-overlong)))
      (mapcar (lambda (word)
                (if (<= (length word) max-length)
                    word
                  (substring word 0 max-length)))
              words)))
  
  (defun org-reference-contraction (reference-string)
    "Give a contracted form of REFERENCE-STRING that is only contains alphanumeric characters.
  Strips 'joining' words present in `org-reference-contraction-stripped-words',
  and then limits the result to the first `org-reference-contraction-max-words' words.
  If the total length is > `org-reference-contraction-max-length' then individual words are
  truncated to fit within the limit using `org-reference-contraction-truncate-words'."
    (let ((reference-words
           (-filter (lambda (word)
                      (not (member word org-reference-contraction-stripped-words)))
                    (split-string
                     (->> reference-string
                          downcase
                          (replace-regexp-in-string "\\[\\[[^]]+\\]\\[\\([^]]+\\)\\]\\]" "\\1") ; get description from org-link
                          (replace-regexp-in-string "[-/ ]+" " ") ; replace seperator-type chars with space
                          puny-encode-string
                          (replace-regexp-in-string "^xn--\\(.*?\\) ?-?\\([a-z0-9]+\\)$" "\\2 \\1") ; rearrange punycode
                          (replace-regexp-in-string "[^A-Za-z0-9 ]" "") ; strip chars which need %-encoding in a uri
                          ) " +"))))
      (when (> (length reference-words)
               org-reference-contraction-max-words)
        (setq reference-words
              (cl-subseq reference-words 0 org-reference-contraction-max-words)))
  
      (when (> (apply #'+ (1- (length reference-words))
                      (mapcar #'length reference-words))
               org-reference-contraction-max-length)
        (setq reference-words (org-reference-contraction-truncate-words reference-words)))
  
      (string-join reference-words org-reference-contraction-joining-char)))
  (define-minor-mode unpackaged/org-export-html-with-useful-ids-mode
    "Attempt to export Org as HTML with useful link IDs.
  Instead of random IDs like \"#orga1b2c3\", use heading titles,
  made unique when necessary."
    :global t
    (if unpackaged/org-export-html-with-useful-ids-mode
        (advice-add #'org-export-get-reference :override #'unpackaged/org-export-get-reference)
      (advice-remove #'org-export-get-reference #'unpackaged/org-export-get-reference)))
  (unpackaged/org-export-html-with-useful-ids-mode 1) ; ensure enabled, and advice run
  
  (defun unpackaged/org-export-get-reference (datum info)
    "Like `org-export-get-reference', except uses heading titles instead of random numbers."
    (let ((cache (plist-get info :internal-references)))
      (or (car (rassq datum cache))
          (let* ((crossrefs (plist-get info :crossrefs))
                 (cells (org-export-search-cells datum))
                 ;; Preserve any pre-existing association between
                 ;; a search cell and a reference, i.e., when some
                 ;; previously published document referenced a location
                 ;; within current file (see
                 ;; `org-publish-resolve-external-link').
                 ;;
                 ;; However, there is no guarantee that search cells are
                 ;; unique, e.g., there might be duplicate custom ID or
                 ;; two headings with the same title in the file.
                 ;;
                 ;; As a consequence, before re-using any reference to
                 ;; an element or object, we check that it doesn't refer
                 ;; to a previous element or object.
                 (new (or (cl-some
                           (lambda (cell)
                             (let ((stored (cdr (assoc cell crossrefs))))
                               (when stored
                                 (let ((old (org-export-format-reference stored)))
                                   (and (not (assoc old cache)) stored)))))
                           cells)
                          (when (org-element-property :raw-value datum)
                            ;; Heading with a title
                            (unpackaged/org-export-new-named-reference datum cache))
                          (when (member (car datum) '(src-block table example fixed-width property-drawer))
                            ;; Nameable elements
                            (unpackaged/org-export-new-named-reference datum cache))
                          ;; NOTE: This probably breaks some Org Export
                          ;; feature, but if it does what I need, fine.
                          (org-export-format-reference
                           (org-export-new-reference cache))))
                 (reference-string new))
            ;; Cache contains both data already associated to
            ;; a reference and in-use internal references, so as to make
            ;; unique references.
            (dolist (cell cells) (push (cons cell new) cache))
            ;; Retain a direct association between reference string and
            ;; DATUM since (1) not every object or element can be given
            ;; a search cell (2) it permits quick lookup.
            (push (cons reference-string datum) cache)
            (plist-put info :internal-references cache)
            reference-string))))
  
  (defun unpackaged/org-export-new-named-reference (datum cache)
    "Return new reference for DATUM that is unique in CACHE."
    (cl-macrolet ((inc-suffixf (place)
                               `(progn
                                  (string-match (rx bos
                                                    (minimal-match (group (1+ anything)))
                                                    (optional "--" (group (1+ digit)))
                                                    eos)
                                                ,place)
                                  ;; HACK: `s1' instead of a gensym.
                                  (-let* (((s1 suffix) (list (match-string 1 ,place)
                                                             (match-string 2 ,place)))
                                          (suffix (if suffix
                                                      (string-to-number suffix)
                                                    0)))
                                    (setf ,place (format "%s--%s" s1 (cl-incf suffix)))))))
      (let* ((headline-p (eq (car datum) 'headline))
             (title (if headline-p
                        (org-element-property :raw-value datum)
                      (or (org-element-property :name datum)
                          (concat (org-element-property :raw-value
                                                        (org-element-property :parent
                                                                              (org-element-property :parent datum)))))))
             ;; get ascii-only form of title without needing percent-encoding
             (ref (concat (org-reference-contraction (substring-no-properties title))
                          (unless (or headline-p (org-element-property :name datum))
                            (concat ","
                                    (pcase (car datum)
                                      ('src-block "code")
                                      ('example "example")
                                      ('fixed-width "mono")
                                      ('property-drawer "properties")
                                      (_ (symbol-name (car datum))))
                                    "--1"))))
             (parent (when headline-p (org-element-property :parent datum))))
        (while (--any (equal ref (car it))
                      cache)
          ;; Title not unique: make it so.
          (if parent
              ;; Append ancestor title.
              (setf title (concat (org-element-property :raw-value parent)
                                  "--" title)
                    ;; get ascii-only form of title without needing percent-encoding
                    ref (org-reference-contraction (substring-no-properties title))
                    parent (when headline-p (org-element-property :parent parent)))
            ;; No more ancestors: add and increment a number.
            (inc-suffixf ref)))
        ref)))
  
  (add-hook 'org-load-hook #'unpackaged/org-export-html-with-useful-ids-mode)
  (defadvice! org-export-format-reference-a (reference)
    "Format REFERENCE into a string.
  
  REFERENCE is a either a number or a string representing a reference,
  as returned by `org-export-new-reference'."
    :override #'org-export-format-reference
    (if (stringp reference) reference (format "org%07x" reference)))
  (defun unpackaged/org-element-descendant-of (type element)
    "Return non-nil if ELEMENT is a descendant of TYPE.
  TYPE should be an element type, like `item' or `paragraph'.
  ELEMENT should be a list like that returned by `org-element-context'."
    ;; MAYBE: Use `org-element-lineage'.
    (when-let* ((parent (org-element-property :parent element)))
      (or (eq type (car parent))
          (unpackaged/org-element-descendant-of type parent))))
  
  ;;;###autoload
  (defun unpackaged/org-return-dwim (&optional default)
    "A helpful replacement for `org-return-indent'.  With prefix, call `org-return-indent'.
  
  On headings, move point to position after entry content.  In
  lists, insert a new item or end the list, with checkbox if
  appropriate.  In tables, insert a new row or end the table."
    ;; Inspired by John Kitchin: http://kitchingroup.cheme.cmu.edu/blog/2017/04/09/A-better-return-in-org-mode/
    (interactive "P")
    (if default
        (org-return t)
      (cond
       ;; Act depending on context around point.
  
       ;; NOTE: I prefer RET to not follow links, but by uncommenting this block, links will be
       ;; followed.
  
       ;; ((eq 'link (car (org-element-context)))
       ;;  ;; Link: Open it.
       ;;  (org-open-at-point-global))
  
       ((org-at-heading-p)
        ;; Heading: Move to position after entry content.
        ;; NOTE: This is probably the most interesting feature of this function.
        (let ((heading-start (org-entry-beginning-position)))
          (goto-char (org-entry-end-position))
          (cond ((and (org-at-heading-p)
                      (= heading-start (org-entry-beginning-position)))
                 ;; Entry ends on its heading; add newline after
                 (end-of-line)
                 (insert "\n\n"))
                (t
                 ;; Entry ends after its heading; back up
                 (forward-line -1)
                 (end-of-line)
                 (when (org-at-heading-p)
                   ;; At the same heading
                   (forward-line)
                   (insert "\n")
                   (forward-line -1))
                 (while (not (looking-back "\\(?:[[:blank:]]?\n\\)\\{3\\}" nil))
                   (insert "\n"))
                 (forward-line -1)))))
  
       ((org-at-item-checkbox-p)
        ;; Checkbox: Insert new item with checkbox.
        (org-insert-todo-heading nil))
  
       ((org-in-item-p)
        ;; Plain list.  Yes, this gets a little complicated...
        (let ((context (org-element-context)))
          (if (or (eq 'plain-list (car context))  ; First item in list
                  (and (eq 'item (car context))
                       (not (eq (org-element-property :contents-begin context)
                                (org-element-property :contents-end context))))
                  (unpackaged/org-element-descendant-of 'item context))  ; Element in list item, e.g. a link
              ;; Non-empty item: Add new item.
              (org-insert-item)
            ;; Empty item: Close the list.
            ;; TODO: Do this with org functions rather than operating on the text. Can't seem to find the right function.
            (delete-region (line-beginning-position) (line-end-position))
            (insert "\n"))))
  
       ((when (fboundp 'org-inlinetask-in-task-p)
          (org-inlinetask-in-task-p))
        ;; Inline task: Don't insert a new heading.
        (org-return t))
  
       ((org-at-table-p)
        (cond ((save-excursion
                 (beginning-of-line)
                 ;; See `org-table-next-field'.
                 (cl-loop with end = (line-end-position)
                          for cell = (org-element-table-cell-parser)
                          always (equal (org-element-property :contents-begin cell)
                                        (org-element-property :contents-end cell))
                          while (re-search-forward "|" end t)))
               ;; Empty row: end the table.
               (delete-region (line-beginning-position) (line-end-position))
               (org-return t))
              (t
               ;; Non-empty row: call `org-return-indent'.
               (org-return t))))
       (t
        ;; All other cases: call `org-return-indent'.
        (org-return t)))))
  
  (map!
   :after evil-org
   :map evil-org-mode-map
   :i [return] #'unpackaged/org-return-dwim)
  (defun +yas/org-src-header-p ()
    "Determine whether `point' is within a src-block header or header-args."
    (pcase (org-element-type (org-element-context))
      ('src-block (< (point) ; before code part of the src-block
                     (save-excursion (goto-char (org-element-property :begin (org-element-context)))
                                     (forward-line 1)
                                     (point))))
      ('inline-src-block (< (point) ; before code part of the inline-src-block
                            (save-excursion (goto-char (org-element-property :begin (org-element-context)))
                                            (search-forward "]{")
                                            (point))))
      ('keyword (string-match-p "^header-args" (org-element-property :value (org-element-context))))))
  (defun +yas/org-prompt-header-arg (arg question values)
    "Prompt the user to set ARG header property to one of VALUES with QUESTION.
  The default value is identified and indicated. If either default is selected,
  or no selection is made: nil is returned."
    (let* ((src-block-p (not (looking-back "^#\\+property:[ \t]+header-args:.*" (line-beginning-position))))
           (default
             (or
              (cdr (assoc arg
                          (if src-block-p
                              (nth 2 (org-babel-get-src-block-info t))
                            (org-babel-merge-params
                             org-babel-default-header-args
                             (let ((lang-headers
                                    (intern (concat "org-babel-default-header-args:"
                                                    (+yas/org-src-lang)))))
                               (when (boundp lang-headers) (eval lang-headers t)))))))
              ""))
           default-value)
      (setq values (mapcar
                    (lambda (value)
                      (if (string-match-p (regexp-quote value) default)
                          (setq default-value
                                (concat value " "
                                        (propertize "(default)" 'face 'font-lock-doc-face)))
                        value))
                    values))
      (let ((selection (consult--read values :prompt question :default default-value)))
        (unless (or (string-match-p "(default)$" selection)
                    (string= "" selection))
          selection))))
  (defun +yas/org-src-lang ()
    "Try to find the current language of the src/header at `point'.
  Return nil otherwise."
    (let ((context (org-element-context)))
      (pcase (org-element-type context)
        ('src-block (org-element-property :language context))
        ('inline-src-block (org-element-property :language context))
        ('keyword (when (string-match "^header-args:\\([^ ]+\\)" (org-element-property :value context))
                    (match-string 1 (org-element-property :value context)))))))
  
  (defun +yas/org-last-src-lang ()
    "Return the language of the last src-block, if it exists."
    (save-excursion
      (beginning-of-line)
      (when (re-search-backward "^[ \t]*#\\+begin_src" nil t)
        (org-element-property :language (org-element-context)))))
  
  (defun +yas/org-most-common-no-property-lang ()
    "Find the lang with the most source blocks that has no global header-args, else nil."
    (let (src-langs header-langs)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[ \t]*#\\+begin_src" nil t)
          (push (+yas/org-src-lang) src-langs))
        (goto-char (point-min))
        (while (re-search-forward "^[ \t]*#\\+property: +header-args" nil t)
          (push (+yas/org-src-lang) header-langs)))
  
      (setq src-langs
            (mapcar #'car
                    ;; sort alist by frequency (desc.)
                    (sort
                     ;; generate alist with form (value . frequency)
                     (cl-loop for (n . m) in (seq-group-by #'identity src-langs)
                              collect (cons n (length m)))
                     (lambda (a b) (> (cdr a) (cdr b))))))
  
      (car (cl-set-difference src-langs header-langs :test #'string=))))
  (defun org-syntax-convert-keyword-case-to-lower ()
    "Convert all #+KEYWORDS to #+keywords."
    (interactive)
    (save-excursion
      (goto-char (point-min))
      (let ((count 0)
            (case-fold-search nil))
        (while (re-search-forward "^[ \t]*#\\+[A-Z_]+" nil t)
          (unless (s-matches-p "RESULTS" (match-string 0))
            (replace-match (downcase (match-string 0)) t)
            (setq count (1+ count))))
        (message "Replaced %d occurances" count))))
  (org-link-set-parameters "xkcd"
                           :image-data-fun #'+org-xkcd-image-fn
                           :follow #'+org-xkcd-open-fn
                           :export #'+org-xkcd-export
                           :complete #'+org-xkcd-complete)
  
  (defun +org-xkcd-open-fn (link)
    (+org-xkcd-image-fn nil link nil))
  
  (defun +org-xkcd-image-fn (protocol link description)
    "Get image data for xkcd num LINK"
    (let* ((xkcd-info (+xkcd-fetch-info (string-to-number link)))
           (img (plist-get xkcd-info :img))
           (alt (plist-get xkcd-info :alt)))
      ;; (message alt)
      (+org-image-file-data-fn protocol (xkcd-download img (string-to-number link)) description)))
      ;; (org-link-open (xkcd-download img (string-to-number link)) nil)))
  
  (defun +org-xkcd-export (num desc backend _com)
    "Convert xkcd to html/LaTeX form"
    (let* ((xkcd-info (+xkcd-fetch-info (string-to-number num)))
           (img (plist-get xkcd-info :img))
           (alt (plist-get xkcd-info :alt))
           (title (plist-get xkcd-info :title))
           (file (xkcd-download img (string-to-number num))))
      (cond ((org-export-derived-backend-p backend 'html)
             (format "<img class='invertible' src='%s' title=\"%s\" alt='%s'>" img (subst-char-in-string ?\" ?“ alt) title))
            ((org-export-derived-backend-p backend 'latex)
             (format "\\begin{figure}[!htb]
    \\centering
    \\includegraphics[scale=0.4]{%s}%s
  \\end{figure}" file (if (equal desc (format "xkcd:%s" num)) ""
                        (format "\n  \\caption*{\\label{xkcd:%s} %s}"
                                num
                                (or desc
                                    (format "\\textbf{%s} %s" title alt))))))
            (t (format "https://xkcd.com/%s" num)))))
  
  (defun +org-xkcd-complete (&optional arg)
    "Complete xkcd using `+xkcd-stored-info'"
    (format "xkcd:%d" (+xkcd-select)))
  (org-link-set-parameters "yt" :export #'+org-export-yt)
  (defun +org-export-yt (path desc backend _com)
    (cond ((org-export-derived-backend-p backend 'html)
           (format "<iframe width='440' \
  height='335' \
  src='https://www.youtube.com/embed/%s' \
  frameborder='0' \
  allowfullscreen>%s</iframe>" path (or "" desc)))
          ((org-export-derived-backend-p backend 'latex)
           (format "\\href{https://youtu.be/%s}{%s}" path (or desc "youtube")))
          (t (format "https://youtu.be/%s" path))))
  (defadvice! shut-up-org-problematic-hooks (orig-fn &rest args)
    :around #'org-fancy-priorities-mode
    (ignore-errors (apply orig-fn args))))

(use-package! oc-csl-activate
  :after oc
  :config
  (setq org-cite-csl-activate-use-document-style t)
  (defun +org-cite-csl-activate/enable ()
    (interactive)
    (setq org-cite-activate-processor 'csl-activate)
    (add-hook! 'org-mode-hook '((lambda () (cursor-sensor-mode 1)) org-cite-csl-activate-render-all))
    (defadvice! +org-cite-csl-activate-render-all-silent (orig-fn)
      :around #'org-cite-csl-activate-render-all
      (with-silent-modifications (funcall orig-fn)))
    (when (eq major-mode 'org-mode)
      (with-silent-modifications
        (save-excursion
          (goto-char (point-min))
          (org-cite-activate (point-max)))
        (org-cite-csl-activate-render-all)))
    (fmakunbound #'+org-cite-csl-activate/enable)))
(setq! citar-bibliography '("~/Documents/BibTex/library.bib"))
(after! citar
  (setq org-cite-global-bibliography
        (let ((libfile-search-names '("library.json" "Library.json" "library.bib" "Library.bib"))
              (libfile-dir "~/Zotero")
              paths)
          (dolist (libfile libfile-search-names)
            (when (and (not paths)
                       (file-exists-p (expand-file-name libfile libfile-dir)))
              (setq paths (list (expand-file-name libfile libfile-dir)))))
          paths)
        citar-bibliography org-cite-global-bibliography
        citar-symbols
        `((file ,(nerd-icons-faicon "nf-fa-file_o" :face 'nerd-icons-green :v-adjust -0.1) . " ")
          (note ,(nerd-icons-octicon "nf-oct-note" :face 'nerd-icons-blue :v-adjust -0.3) . " ")
          (link ,(nerd-icons-octicon "nf-oct-link" :face 'nerd-icons-orange :v-adjust 0.01) . " "))))
(after! oc-csl
  (setq org-cite-csl-styles-dir "~/Zotero/styles"))
(after! oc
  (setq org-cite-export-processors '((t csl))))
(map! :after org
      :map org-mode-map
      :localleader
      :desc "Insert citation" "@" #'org-cite-insert)
(after! oc
  (defun org-ref-to-org-cite ()
    "Attempt to convert org-ref citations to org-cite syntax."
    (interactive)
    (let* ((cite-conversions '(("cite" . "//b") ("Cite" . "//bc")
                               ("nocite" . "/n")
                               ("citep" . "") ("citep*" . "//f")
                               ("parencite" . "") ("Parencite" . "//c")
                               ("citeauthor" . "/a/f") ("citeauthor*" . "/a")
                               ("citeyear" . "/na/b")
                               ("Citep" . "//c") ("Citealp" . "//bc")
                               ("Citeauthor" . "/a/cf") ("Citeauthor*" . "/a/c")
                               ("autocite" . "") ("Autocite" . "//c")
                               ("notecite" . "/l/b") ("Notecite" . "/l/bc")
                               ("pnotecite" . "/l") ("Pnotecite" . "/l/bc")))
           (cite-regexp (rx (regexp (regexp-opt (mapcar #'car cite-conversions) t))
                            ":" (group (+ (not (any "\n 	,.)]}")))))))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward cite-regexp nil t)
          (message (format "[cite%s:@%s]"
                                 (cdr (assoc (match-string 1) cite-conversions))
                                 (match-string 2)))
          (replace-match (format "[cite%s:@%s]"
                                 (cdr (assoc (match-string 1) cite-conversions))
                                 (match-string 2))))))))

(use-package! org-super-agenda
  :commands org-super-agenda-mode)
(after! org-agenda
  (let ((inhibit-message t))
    (org-super-agenda-mode)))

(setq org-agenda-skip-scheduled-if-done t
      org-agenda-skip-deadline-if-done t
      org-agenda-include-deadlines t
      org-agenda-block-separator nil
      org-agenda-tags-column 100 ;; from testing this seems to be a good value
      org-agenda-compact-blocks t)

(setq org-agenda-custom-commands
      '(("o" "Overview"
         ((agenda "" ((org-agenda-span 'day)
                      (org-super-agenda-groups
                       '((:name "Today"
                          :time-grid t
                          :date today
                          :todo "TODAY"
                          :scheduled today
                          :order 1)))))
          (alltodo "" ((org-agenda-overriding-header "")
                       (org-super-agenda-groups
                        '((:name "Next to do"
                           :todo "NEXT"
                           :order 1)
                          (:name "Important"
                           :tag "Important"
                           :priority "A"
                           :order 6)
                          (:name "Due Today"
                           :deadline today
                           :order 2)
                          (:name "Due Soon"
                           :deadline future
                           :order 8)
                          (:name "Overdue"
                           :deadline past
                           :face error
                           :order 7)
                          (:name "Assignments"
                           :tag "Assignment"
                           :order 10)
                          (:name "Issues"
                           :tag "Issue"
                           :order 12)
                          (:name "Emacs"
                           :tag "Emacs"
                           :order 13)
                          (:name "Projects"
                           :tag "Project"
                           :order 14)
                          (:name "Research"
                           :tag "Research"
                           :order 15)
                          (:name "To read"
                           :tag "Read"
                           :order 30)
                          (:name "Waiting"
                           :todo "WAITING"
                           :order 20)
                          (:name "University"
                           :tag "uni"
                           :order 32)
                          (:name "Trivial"
                           :priority<= "E"
                           :tag ("Trivial" "Unimportant")
                           :todo ("SOMEDAY" )
                           :order 90)
                          (:discard (:tag ("Chore" "Routine" "Daily")))))))))))

(after! org-roam
  (setq org-roam-directory "~/Documents/org/roam/")
  (defadvice! doom-modeline--buffer-file-name-roam-aware-a (orig-fun)
    :around #'doom-modeline-buffer-file-name ; takes no args
    (if (s-contains-p org-roam-directory (or buffer-file-name ""))
        (replace-regexp-in-string
         "\\(?:^\\|.*/\\)\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)[0-9]*-"
         "🢔(\\1-\\2-\\3) "
         (subst-char-in-string ?_ ?  buffer-file-name))
      (funcall orig-fun))))

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam
  :commands org-roam-ui-open
  :hook (org-roam . org-roam-ui-mode)
  :config
  (require 'org-roam) ; in case autoloaded
  (defun org-roam-ui-open ()
    "Ensure the server is active, then open the roam graph."
    (interactive)
    (unless org-roam-ui-mode (org-roam-ui-mode 1))
    (browse-url-xdg-open (format "http://localhost:%d" org-roam-ui-port))))

(defadvice! org-export-format-reference-a (reference)
  "Format REFERENCE into a string.

REFERENCE is a either a number or a string representing a reference,
as returned by `org-export-new-reference'."
  :override #'org-export-format-reference
  (if (stringp reference) reference (format "org%07x" reference)))

;; (after! org
;;   (defconst flycheck-org-lint-form
;;     (flycheck-prepare-emacs-lisp-form
;;       (require 'org)
;;       (require 'org-attach)
;;       (let ((source (car command-line-args-left))
;;             (process-default-directory default-directory))
;;         (with-temp-buffer
;;           (insert-file-contents source 'visit)
;;           (setq buffer-file-name source)
;;           (setq default-directory process-default-directory)
;;           (delay-mode-hooks (org-mode))
;;           (setq delayed-mode-hooks nil)
;;           (dolist (err (org-lint))
;;             (let ((inf (cl-second err)))
;;               (princ (elt inf 0))
;;               (princ ": ")
;;               (princ (elt inf 2))
;;               (terpri)))))))
;;   
;;   (defconst flycheck-org-lint-variables
;;     '(org-directory
;;       org-id-locations
;;       org-id-locations-file
;;       org-attach-id-dir
;;       org-attach-use-inheritance
;;       org-attach-id-to-path-function-list
;;       org-link-parameters)
;;     "Variables inherited by the org-lint subprocess.")
;;   
;;   (defun flycheck-org-lint-variables-form ()
;;     (require 'org-attach)  ; Needed to make variables available
;;     `(progn
;;        ,@(seq-map (lambda (opt) `(setq-default ,opt ',(symbol-value opt)))
;;                   (seq-filter #'boundp flycheck-org-lint-variables))))
;;   
;;   (eval ; To preveant eager macro expansion form loading flycheck early.
;;    '(flycheck-define-checker org-lint
;;      "Org buffer checker using `org-lint'."
;;      :command ("emacs" (eval flycheck-emacs-args)
;;                "--eval" (eval (concat "(add-to-list 'load-path \""
;;                                       (file-name-directory (locate-library "org"))
;;                                       "\")"))
;;                "--eval" (eval (flycheck-sexp-to-string
;;                                (flycheck-org-lint-variables-form)))
;;                "--eval" (eval (flycheck-sexp-to-string
;;                                (flycheck-org-lint-customisations-form)))
;;                "--eval" (eval flycheck-org-lint-form)
;;                "--" source)
;;      :error-patterns
;;      ((error line-start line ": " (message) line-end))
;;      :modes org-mode))
;;   (add-to-list 'flycheck-checkers 'org-lint)
;;   (defun flycheck-org-lint-customisations-form ()
;;     `(progn
;;        (require 'ox)
;;        (cl-pushnew '(:latex-cover-page nil "coverpage" nil)
;;                    (org-export-backend-options (org-export-get-backend 'latex)))
;;        (cl-pushnew '(:latex-font-set nil "fontset" nil)
;;                    (org-export-backend-options (org-export-get-backend 'latex))))))

(after! org
  (add-hook 'org-mode-hook #'+org-pretty-mode)
  (custom-set-faces!
    '(outline-1 :weight extra-bold :height 1.25)
    '(outline-2 :weight bold :height 1.15)
    '(outline-3 :weight bold :height 1.12)
    '(outline-4 :weight semi-bold :height 1.09)
    '(outline-5 :weight semi-bold :height 1.06)
    '(outline-6 :weight semi-bold :height 1.03)
    '(outline-8 :weight semi-bold)
    '(outline-9 :weight semi-bold))
  (custom-set-faces!
    '(org-document-title :height 1.2))
  (setq org-agenda-deadline-faces
        '((1.001 . error)
          (1.0 . org-warning)
          (0.5 . org-upcoming-deadline)
          (0.0 . org-upcoming-distant-deadline)))
  (setq org-fontify-quote-and-verse-blocks t)
  (defun locally-defer-font-lock ()
    "Set jit-lock defer and stealth, when buffer is over a certain size."
    (when (> (buffer-size) 50000)
      (setq-local jit-lock-defer-time 0.05
                  jit-lock-stealth-time 1)))
  
  (add-hook 'org-mode-hook #'locally-defer-font-lock)
  (defadvice! +org-indent--reduced-text-prefixes ()
    :after #'org-indent--compute-prefixes
    (setq org-indent--text-line-prefixes
          (make-vector org-indent--deepest-level nil))
    (when (> org-indent-indentation-per-level 0)
      (dotimes (n org-indent--deepest-level)
        (aset org-indent--text-line-prefixes
              n
              (org-add-props
                  (concat (make-string (* n (1- org-indent-indentation-per-level))
                                       ?\s)
                          (if (> n 0)
                               (char-to-string org-indent-boundary-char)
                            "\u200b"))
                  nil 'face 'org-indent)))))
  (setq org-inline-src-prettify-results '("⟨" . "⟩"))
  (setq doom-themes-org-fontify-special-tags nil)
  (setq org-ellipsis " ▾ "
        org-hide-leading-stars t
        org-priority-highest ?A
        org-priority-lowest ?E
        org-priority-faces
        '((?A . 'nerd-icons-red)
          (?B . 'nerd-icons-orange)
          (?C . 'nerd-icons-yellow)
          (?D . 'nerd-icons-green)
          (?E . 'nerd-icons-blue)))
  (setq org-highlight-latex-and-related '(native script entities))
  (require 'org-src)
  (add-to-list 'org-src-block-faces '("latex" (:inherit default :extend t)))
  ;; (add-hook 'org-mode-hook #'org-latex-preview-auto-mode)
  ;; (setq org-latex-preview-header
  ;;       (concat
  ;;        <<grab("latex-default-snippet-preamble")>>
  ;;        "\n% Custom font\n\\usepackage{arev}\n\n"
  ;;        <<grab("latex-maths-conveniences")>>))
  (plist-put org-format-latex-options :background "Transparent")
  (plist-put org-format-latex-options :zoom 0.93) ; Calibrated based on the TeX font and org-buffer font.
  (defun +org-refresh-latex-images-previews-h ()
    (dolist (buffer (doom-buffers-in-mode 'org-mode (buffer-list)))
      (with-current-buffer buffer
        (+org--toggle-inline-images-in-subtree (point-min) (point-max) 'refresh)
        (unless (eq org-preview-latex-default-process 'dvisvgm)
          (org-clear-latex-preview (point-min) (point-max))
          (org--latex-preview-region (point-min) (point-max))))))
  
  (add-hook 'doom-load-theme-hook #'+org-refresh-latex-images-previews-h)
  (defvar +org-plot-term-size '(1050 . 650)
    "The size of the GNUPlot terminal, in the form (WIDTH . HEIGHT).")
  
  (after! org-plot
    (defun +org-plot-generate-theme (_type)
      "Use the current Doom theme colours to generate a GnuPlot preamble."
      (format "
  fgt = \"textcolor rgb '%s'\" # foreground text
  fgat = \"textcolor rgb '%s'\" # foreground alt text
  fgl = \"linecolor rgb '%s'\" # foreground line
  fgal = \"linecolor rgb '%s'\" # foreground alt line
  
  # foreground colors
  set border lc rgb '%s'
  # change text colors of  tics
  set xtics @fgt
  set ytics @fgt
  # change text colors of labels
  set title @fgt
  set xlabel @fgt
  set ylabel @fgt
  # change a text color of key
  set key @fgt
  
  # line styles
  set linetype 1 lw 2 lc rgb '%s' # red
  set linetype 2 lw 2 lc rgb '%s' # blue
  set linetype 3 lw 2 lc rgb '%s' # green
  set linetype 4 lw 2 lc rgb '%s' # magenta
  set linetype 5 lw 2 lc rgb '%s' # orange
  set linetype 6 lw 2 lc rgb '%s' # yellow
  set linetype 7 lw 2 lc rgb '%s' # teal
  set linetype 8 lw 2 lc rgb '%s' # violet
  
  # border styles
  set tics out nomirror
  set border 3
  
  # palette
  set palette maxcolors 8
  set palette defined ( 0 '%s',\
  1 '%s',\
  2 '%s',\
  3 '%s',\
  4 '%s',\
  5 '%s',\
  6 '%s',\
  7 '%s' )
  "
              (doom-color 'fg)
              (doom-color 'fg-alt)
              (doom-color 'fg)
              (doom-color 'fg-alt)
              (doom-color 'fg)
              ;; colours
              (doom-color 'red)
              (doom-color 'blue)
              (doom-color 'green)
              (doom-color 'magenta)
              (doom-color 'orange)
              (doom-color 'yellow)
              (doom-color 'teal)
              (doom-color 'violet)
              ;; duplicated
              (doom-color 'red)
              (doom-color 'blue)
              (doom-color 'green)
              (doom-color 'magenta)
              (doom-color 'orange)
              (doom-color 'yellow)
              (doom-color 'teal)
              (doom-color 'violet)))
  
    (defun +org-plot-gnuplot-term-properties (_type)
      (format "background rgb '%s' size %s,%s"
              (doom-color 'bg) (car +org-plot-term-size) (cdr +org-plot-term-size)))
  
    (setq org-plot/gnuplot-script-preamble #'+org-plot-generate-theme)
    (setq org-plot/gnuplot-term-extra #'+org-plot-gnuplot-term-properties)))

(setq org-highlight-latex-and-related '(native script entities))

(require 'org-src)
(add-to-list 'org-src-block-faces '("latex" (:inherit default :extend t)))

;; (add-hook 'org-mode-hook #'org-latex-preview-auto-mode)

(plist-put org-format-latex-options :background "Transparent")
(plist-put org-format-latex-options :zoom 0.93) ; Calibrated based on the TeX font and org-buffer font.

(defun +org-refresh-latex-images-previews-h ()
  (dolist (buffer (doom-buffers-in-mode 'org-mode (buffer-list)))
    (with-current-buffer buffer
      (+org--toggle-inline-images-in-subtree (point-min) (point-max) 'refresh)
      (unless (eq org-preview-latex-default-process 'dvisvgm)
        (org-clear-latex-preview (point-min) (point-max))
        (org--latex-preview-region (point-min) (point-max))))))

(add-hook 'doom-load-theme-hook #'+org-refresh-latex-images-previews-h)

(after! ox
  (setq org-export-headline-levels 5) ; I like nesting
  (require 'ox-extra)
  (ox-extras-activate '(ignore-headlines))
  (setq org-export-creator-string
        (format "Emacs %s (Org mode %s–%s)" emacs-version (org-release) (org-git-version)))
  (defun org-export-filter-text-acronym (text backend _info)
    "Wrap suspected acronyms in acronyms-specific formatting.
  Treat sequences of 2+ capital letters (optionally succeeded by \"s\") as an acronym.
  Ignore if preceeded by \";\" (for manual prevention) or \"\\\" (for LaTeX commands).
  
  TODO abstract backend implementations."
    (let ((base-backend
           (cond
            ((org-export-derived-backend-p backend 'latex) 'latex)
            ;; Markdown is derived from HTML, but we don't want to format it
            ((org-export-derived-backend-p backend 'md) nil)
            ((org-export-derived-backend-p backend 'html) 'html)))
          (case-fold-search nil))
      (when base-backend
        (replace-regexp-in-string
         "[;\\\\]?\\b[A-Z][A-Z]+s?\\(?:[^A-Za-z]\\|\\b\\)"
         (lambda (all-caps-str)
           (cond ((equal (aref all-caps-str 0) ?\\) all-caps-str)                ; don't format LaTeX commands
                 ((equal (aref all-caps-str 0) ?\;) (substring all-caps-str 1))  ; just remove not-acronym indicator char ";"
                 (t (let* ((final-char (if (string-match-p "[^A-Za-z]" (substring all-caps-str -1 (length all-caps-str)))
                                           (substring all-caps-str -1 (length all-caps-str))
                                         nil)) ; needed to re-insert the [^A-Za-z] at the end
                           (trailing-s (equal (aref all-caps-str (- (length all-caps-str) (if final-char 2 1))) ?s))
                           (acr (if final-char
                                    (substring all-caps-str 0 (if trailing-s -2 -1))
                                  (substring all-caps-str 0 (+ (if trailing-s -1 (length all-caps-str)))))))
                      (pcase base-backend
                        ('latex (concat "\\acr{" (s-downcase acr) "}" (when trailing-s "\\acrs{}") final-char))
                        ('html (concat "<span class='acr'>" acr "</span>" (when trailing-s "<small>s</small>") final-char)))))))
         text t t))))
  
  (add-to-list 'org-export-filter-plain-text-functions
               #'org-export-filter-text-acronym)
  
  ;; We won't use `org-export-filter-headline-functions' because it
  ;; passes (and formats) the entire section contents. That's no good.
  
  (defun org-html-format-headline-acronymised (todo todo-type priority text tags info)
    "Like `org-html-format-headline-default-function', but with acronym formatting."
    (org-html-format-headline-default-function
     todo todo-type priority (org-export-filter-text-acronym text 'html info) tags info))
  (setq org-html-format-headline-function #'org-html-format-headline-acronymised)
  
  (defun org-latex-format-headline-acronymised (todo todo-type priority text tags info)
    "Like `org-latex-format-headline-default-function', but with acronym formatting."
    (org-latex-format-headline-default-function
     todo todo-type priority (org-export-filter-text-acronym text 'latex info) tags info))
  (setq org-latex-format-headline-function #'org-latex-format-headline-acronymised)
  (defun +org-mode--fontlock-only-mode ()
    "Just apply org-mode's font-lock once."
    (let (org-mode-hook
          org-hide-leading-stars
          org-hide-emphasis-markers)
      (org-set-font-lock-defaults)
      (font-lock-ensure))
    (setq-local major-mode #'fundamental-mode))
  
  (defun +org-export-babel-mask-org-config (_backend)
    "Use `+org-mode--fontlock-only-mode' instead of `org-mode'."
    (setq-local org-src-lang-modes
                (append org-src-lang-modes
                        (list (cons "org" #'+org-mode--fontlock-only)))))
  
  (add-hook 'org-export-before-processing-hook #'+org-export-babel-mask-org-config))

(after! ox-html
  (define-minor-mode org-fancy-html-export-mode
    "Toggle my fabulous org export tweaks. While this mode itself does a little bit,
  the vast majority of the change in behaviour comes from switch statements in:
   - `org-html-template-fancier'
   - `org-html--build-meta-info-extended'
   - `org-html-src-block-collapsable'
   - `org-html-block-collapsable'
   - `org-html-table-wrapped'
   - `org-html--format-toc-headline-colapseable'
   - `org-html--toc-text-stripped-leaves'
   - `org-export-html-headline-anchor'"
    :global t
    :init-value t
    (if org-fancy-html-export-mode
        (setq org-html-style-default org-html-style-fancy
              org-html-meta-tags #'org-html-meta-tags-fancy
              org-html-checkbox-type 'html-span)
      (setq org-html-style-default org-html-style-plain
            org-html-meta-tags #'org-html-meta-tags-default
            org-html-checkbox-type 'html)))
  (defadvice! org-html-template-fancier (orig-fn contents info)
    "Return complete document string after HTML conversion.
  CONTENTS is the transcoded contents string.  INFO is a plist
  holding export options. Adds a few extra things to the body
  compared to the default implementation."
    :around #'org-html-template
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn contents info)
      (concat
       (when (and (not (org-html-html5-p info)) (org-html-xhtml-p info))
         (let* ((xml-declaration (plist-get info :html-xml-declaration))
                (decl (or (and (stringp xml-declaration) xml-declaration)
                          (cdr (assoc (plist-get info :html-extension)
                                      xml-declaration))
                          (cdr (assoc "html" xml-declaration))
                          "")))
           (when (not (or (not decl) (string= "" decl)))
             (format "%s\n"
                     (format decl
                             (or (and org-html-coding-system
                                      (fboundp 'coding-system-get)
                                      (coding-system-get org-html-coding-system 'mime-charset))
                                 "iso-8859-1"))))))
       (org-html-doctype info)
       "\n"
       (concat "<html"
               (cond ((org-html-xhtml-p info)
                      (format
                       " xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"%s\" xml:lang=\"%s\""
                       (plist-get info :language) (plist-get info :language)))
                     ((org-html-html5-p info)
                      (format " lang=\"%s\"" (plist-get info :language))))
               ">\n")
       "<head>\n"
       (org-html--build-meta-info info)
       (org-html--build-head info)
       (org-html--build-mathjax-config info)
       "</head>\n"
       "<body>\n<input type='checkbox' id='theme-switch'><div id='page'><label id='switch-label' for='theme-switch'></label>"
       (let ((link-up (org-trim (plist-get info :html-link-up)))
             (link-home (org-trim (plist-get info :html-link-home))))
         (unless (and (string= link-up "") (string= link-home ""))
           (format (plist-get info :html-home/up-format)
                   (or link-up link-home)
                   (or link-home link-up))))
       ;; Preamble.
       (org-html--build-pre/postamble 'preamble info)
       ;; Document contents.
       (let ((div (assq 'content (plist-get info :html-divs))))
         (format "<%s id=\"%s\">\n" (nth 1 div) (nth 2 div)))
       ;; Document title.
       (when (plist-get info :with-title)
         (let ((title (and (plist-get info :with-title)
                           (plist-get info :title)))
               (subtitle (plist-get info :subtitle))
               (html5-fancy (org-html--html5-fancy-p info)))
           (when title
             (format
              (if html5-fancy
                  "<header class=\"page-header\">%s\n<h1 class=\"title\">%s</h1>\n%s</header>"
                "<h1 class=\"title\">%s%s</h1>\n")
              (if (or (plist-get info :with-date)
                      (plist-get info :with-author))
                  (concat "<div class=\"page-meta\">"
                          (when (plist-get info :with-date)
                            (org-export-data (plist-get info :date) info))
                          (when (and (plist-get info :with-date) (plist-get info :with-author)) ", ")
                          (when (plist-get info :with-author)
                            (org-export-data (plist-get info :author) info))
                          "</div>\n")
                "")
              (org-export-data title info)
              (if subtitle
                  (format
                   (if html5-fancy
                       "<p class=\"subtitle\" role=\"doc-subtitle\">%s</p>\n"
                     (concat "\n" (org-html-close-tag "br" nil info) "\n"
                             "<span class=\"subtitle\">%s</span>\n"))
                   (org-export-data subtitle info))
                "")))))
       contents
       (format "</%s>\n" (nth 1 (assq 'content (plist-get info :html-divs))))
       ;; Postamble.
       (org-html--build-pre/postamble 'postamble info)
       ;; Possibly use the Klipse library live code blocks.
       (when (plist-get info :html-klipsify-src)
         (concat "<script>" (plist-get info :html-klipse-selection-script)
                 "</script><script src=\""
                 org-html-klipse-js
                 "\"></script><link rel=\"stylesheet\" type=\"text/css\" href=\""
                 org-html-klipse-css "\"/>"))
       ;; Closing document.
       "</div>\n</body>\n</html>")))
  (defadvice! org-html-toc-linked (depth info &optional scope)
    "Build a table of contents.
  
  Just like `org-html-toc', except the header is a link to \"#\".
  
  DEPTH is an integer specifying the depth of the table.  INFO is
  a plist used as a communication channel.  Optional argument SCOPE
  is an element defining the scope of the table.  Return the table
  of contents as a string, or nil if it is empty."
    :override #'org-html-toc
    (let ((toc-entries
           (mapcar (lambda (headline)
                     (cons (org-html--format-toc-headline headline info)
                           (org-export-get-relative-level headline info)))
                   (org-export-collect-headlines info depth scope))))
      (when toc-entries
        (let ((toc (concat "<div id=\"text-table-of-contents\">"
                           (org-html--toc-text toc-entries)
                           "</div>\n")))
          (if scope toc
            (let ((outer-tag (if (org-html--html5-fancy-p info)
                                 "nav"
                               "div")))
              (concat (format "<%s id=\"table-of-contents\">\n" outer-tag)
                      (let ((top-level (plist-get info :html-toplevel-hlevel)))
                        (format "<h%d><a href=\"#\" style=\"color:inherit; text-decoration: none;\">%s</a></h%d>\n"
                                top-level
                                (org-html--translate "Table of Contents" info)
                                top-level))
                      toc
                      (format "</%s>\n" outer-tag))))))))
  (defvar org-html-meta-tags-opengraph-image
    '(:image "https://tecosaur.com/resources/org/nib.png"
      :type "image/png"
      :width "200"
      :height "200"
      :alt "Green fountain pen nib")
    "Plist of og:image:PROP properties and their value, for use in `org-html-meta-tags-fancy'.")
  
  (defun org-html-meta-tags-fancy (info)
    "Use the INFO plist to construct the meta tags, as described in `org-html-meta-tags'."
    (let ((title (org-html-plain-text
                  (org-element-interpret-data (plist-get info :title)) info))
          (author (and (plist-get info :with-author)
                       (let ((auth (plist-get info :author)))
                         ;; Return raw Org syntax.
                         (and auth (org-html-plain-text
                                    (org-element-interpret-data auth) info))))))
      (append
       (list
        (when (org-string-nw-p author)
          (list "name" "author" author))
        (when (org-string-nw-p (plist-get info :description))
          (list "name" "description"
                (plist-get info :description)))
        '("name" "generator" "org mode")
        '("name" "theme-color" "#77aa99")
        '("property" "og:type" "article")
        (list "property" "og:title" title)
        (let ((subtitle (org-export-data (plist-get info :subtitle) info)))
          (when (org-string-nw-p subtitle)
            (list "property" "og:description" subtitle))))
       (when org-html-meta-tags-opengraph-image
         (list (list "property" "og:image" (plist-get org-html-meta-tags-opengraph-image :image))
               (list "property" "og:image:type" (plist-get org-html-meta-tags-opengraph-image :type))
               (list "property" "og:image:width" (plist-get org-html-meta-tags-opengraph-image :width))
               (list "property" "og:image:height" (plist-get org-html-meta-tags-opengraph-image :height))
               (list "property" "og:image:alt" (plist-get org-html-meta-tags-opengraph-image :alt))))
       (list
        (when (org-string-nw-p author)
          (list "property" "og:article:author:first_name" (car (s-split-up-to " " author 2))))
        (when (and (org-string-nw-p author) (s-contains-p " " author))
          (list "property" "og:article:author:last_name" (cadr (s-split-up-to " " author 2))))
        (list "property" "og:article:published_time"
              (format-time-string
               "%FT%T%z"
               (or
                (when-let ((date-str (cadar (org-collect-keywords '("DATE")))))
                  (unless (string= date-str (format-time-string "%F"))
                    (ignore-errors (encode-time (org-parse-time-string date-str)))))
                (if buffer-file-name
                    (file-attribute-modification-time (file-attributes buffer-file-name))
                  (current-time)))))
        (when buffer-file-name
          (list "property" "og:article:modified_time"
                (format-time-string "%FT%T%z" (file-attribute-modification-time (file-attributes buffer-file-name)))))))))
  
  (unless (functionp #'org-html-meta-tags-default)
    (defalias 'org-html-meta-tags-default #'ignore))
  (setq org-html-meta-tags #'org-html-meta-tags-fancy)
  (defvar org-html-export-collapsed nil)
  (eval '(cl-pushnew '(:collapsed "COLLAPSED" "collapsed" org-html-export-collapsed t)
                     (org-export-backend-options (org-export-get-backend 'html))))
  (add-to-list 'org-default-properties "EXPORT_COLLAPSED")
  (defadvice! org-html-src-block-collapsable (orig-fn src-block contents info)
    "Wrap the usual <pre> block in a <details>"
    :around #'org-html-src-block
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn src-block contents info)
      (let* ((properties (cadr src-block))
             (lang (mode-name-to-lang-name
                    (plist-get properties :language)))
             (name (plist-get properties :name))
             (ref (org-export-get-reference src-block info))
             (collapsed-p (member (or (org-export-read-attribute :attr_html src-block :collapsed)
                                      (plist-get info :collapsed))
                                  '("y" "yes" "t" t "true" "all"))))
        (format
         "<details id='%s' class='code'%s><summary%s>%s</summary>
  <div class='gutter'>
  <a href='#%s'>#</a>
  <button title='Copy to clipboard' onclick='copyPreToClipbord(this)'>⎘</button>\
  </div>
  %s
  </details>"
         ref
         (if collapsed-p "" " open")
         (if name " class='named'" "")
         (concat
          (when name (concat "<span class=\"name\">" name "</span>"))
          "<span class=\"lang\">" lang "</span>")
         ref
         (if name
             (replace-regexp-in-string (format "<pre\\( class=\"[^\"]+\"\\)? id=\"%s\">" ref) "<pre\\1>"
                                       (funcall orig-fn src-block contents info))
           (funcall orig-fn src-block contents info))))))
  
  (defun mode-name-to-lang-name (mode)
    (or (cadr (assoc mode
                     '(("asymptote" "Asymptote")
                       ("awk" "Awk")
                       ("C" "C")
                       ("clojure" "Clojure")
                       ("css" "CSS")
                       ("D" "D")
                       ("ditaa" "ditaa")
                       ("dot" "Graphviz")
                       ("calc" "Emacs Calc")
                       ("emacs-lisp" "Emacs Lisp")
                       ("fortran" "Fortran")
                       ("gnuplot" "gnuplot")
                       ("haskell" "Haskell")
                       ("hledger" "hledger")
                       ("java" "Java")
                       ("js" "Javascript")
                       ("latex" "LaTeX")
                       ("ledger" "Ledger")
                       ("lisp" "Lisp")
                       ("lilypond" "Lilypond")
                       ("lua" "Lua")
                       ("matlab" "MATLAB")
                       ("mscgen" "Mscgen")
                       ("ocaml" "Objective Caml")
                       ("octave" "Octave")
                       ("org" "Org mode")
                       ("oz" "OZ")
                       ("plantuml" "Plantuml")
                       ("processing" "Processing.js")
                       ("python" "Python")
                       ("R" "R")
                       ("ruby" "Ruby")
                       ("sass" "Sass")
                       ("scheme" "Scheme")
                       ("screen" "Gnu Screen")
                       ("sed" "Sed")
                       ("sh" "shell")
                       ("sql" "SQL")
                       ("sqlite" "SQLite")
                       ("forth" "Forth")
                       ("io" "IO")
                       ("J" "J")
                       ("makefile" "Makefile")
                       ("maxima" "Maxima")
                       ("perl" "Perl")
                       ("picolisp" "Pico Lisp")
                       ("scala" "Scala")
                       ("shell" "Shell Script")
                       ("ebnf2ps" "ebfn2ps")
                       ("cpp" "C++")
                       ("abc" "ABC")
                       ("coq" "Coq")
                       ("groovy" "Groovy")
                       ("bash" "bash")
                       ("csh" "csh")
                       ("ash" "ash")
                       ("dash" "dash")
                       ("ksh" "ksh")
                       ("mksh" "mksh")
                       ("posh" "posh")
                       ("ada" "Ada")
                       ("asm" "Assembler")
                       ("caml" "Caml")
                       ("delphi" "Delphi")
                       ("html" "HTML")
                       ("idl" "IDL")
                       ("mercury" "Mercury")
                       ("metapost" "MetaPost")
                       ("modula-2" "Modula-2")
                       ("pascal" "Pascal")
                       ("ps" "PostScript")
                       ("prolog" "Prolog")
                       ("simula" "Simula")
                       ("tcl" "tcl")
                       ("tex" "LaTeX")
                       ("plain-tex" "TeX")
                       ("verilog" "Verilog")
                       ("vhdl" "VHDL")
                       ("xml" "XML")
                       ("nxml" "XML")
                       ("conf" "Configuration File"))))
        mode))
  (defun org-html-block-collapsable (orig-fn block contents info)
    "Wrap the usual block in a <details>"
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn block contents info)
      (let ((ref (org-export-get-reference block info))
            (type (pcase (car block)
                    ('property-drawer "Properties")))
            (collapsed-default (pcase (car block)
                                 ('property-drawer t)
                                 (_ nil)))
            (collapsed-value (org-export-read-attribute :attr_html block :collapsed))
            (collapsed-p (or (member (org-export-read-attribute :attr_html block :collapsed)
                                     '("y" "yes" "t" t "true"))
                             (member (plist-get info :collapsed) '("all")))))
        (format
         "<details id='%s' class='code'%s>
  <summary%s>%s</summary>
  <div class='gutter'>\
  <a href='#%s'>#</a>
  <button title='Copy to clipboard' onclick='copyPreToClipbord(this)'>⎘</button>\
  </div>
  %s\n
  </details>"
         ref
         (if (or collapsed-p collapsed-default) "" " open")
         (if type " class='named'" "")
         (if type (format "<span class='type'>%s</span>" type) "")
         ref
         (funcall orig-fn block contents info)))))
  
  (advice-add 'org-html-example-block   :around #'org-html-block-collapsable)
  (advice-add 'org-html-fixed-width     :around #'org-html-block-collapsable)
  (advice-add 'org-html-property-drawer :around #'org-html-block-collapsable)
  (autoload #'highlight-numbers--turn-on "highlight-numbers")
  (add-hook 'htmlize-before-hook #'highlight-numbers--turn-on)
  (defadvice! org-html-table-wrapped (orig-fn table contents info)
    "Wrap the usual <table> in a <div>"
    :around #'org-html-table
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn table contents info)
      (let* ((name (plist-get (cadr table) :name))
             (ref (org-export-get-reference table info)))
        (format "<div id='%s' class='table'>
  <div class='gutter'><a href='#%s'>#</a></div>
  <div class='tabular'>
  %s
  </div>\
  </div>"
                ref ref
                (if name
                    (replace-regexp-in-string (format "<table id=\"%s\"" ref) "<table"
                                              (funcall orig-fn table contents info))
                  (funcall orig-fn table contents info))))))
  (defadvice! org-html--format-toc-headline-colapseable (orig-fn headline info)
    "Add a label and checkbox to `org-html--format-toc-headline's usual output,
  to allow the TOC to be a collapseable tree."
    :around #'org-html--format-toc-headline
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn headline info)
      (let ((id (or (org-element-property :CUSTOM_ID headline)
                    (org-export-get-reference headline info))))
        (format "<input type='checkbox' id='toc--%s'/><label for='toc--%s'>%s</label>"
                id id (funcall orig-fn headline info)))))
  (defadvice! org-html--toc-text-stripped-leaves (orig-fn toc-entries)
    "Remove label"
    :around #'org-html--toc-text
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn toc-entries)
      (replace-regexp-in-string "<input [^>]+><label [^>]+>\\(.+?\\)</label></li>" "\\1</li>"
                                (funcall orig-fn toc-entries))))
  (setq org-html-text-markup-alist
        '((bold . "<b>%s</b>")
          (code . "<code>%s</code>")
          (italic . "<i>%s</i>")
          (strike-through . "<del>%s</del>")
          (underline . "<span class=\"underline\">%s</span>")
          (verbatim . "<kbd>%s</kbd>")))
  (appendq! org-html-checkbox-types
            '((html-span
               (on . "<span class='checkbox'></span>")
               (off . "<span class='checkbox'></span>")
               (trans . "<span class='checkbox'></span>"))))
  (setq org-html-checkbox-type 'html-span)
  (pushnew! org-html-special-string-regexps
            '("-&gt;" . "&#8594;")
            '("&lt;-" . "&#8592;"))
  (defun org-export-html-headline-anchor (text backend info)
    (when (and (org-export-derived-backend-p backend 'html)
               (not (org-export-derived-backend-p backend 're-reveal))
               org-fancy-html-export-mode)
      (unless (bound-and-true-p org-msg-export-in-progress)
        (replace-regexp-in-string
         "<h\\([0-9]\\) id=\"\\([a-z0-9-]+\\)\">\\(.*[^ ]\\)<\\/h[0-9]>" ; this is quite restrictive, but due to `org-reference-contraction' I can do this
         "<h\\1 id=\"\\2\">\\3<a aria-hidden=\"true\" href=\"#\\2\">#</a> </h\\1>"
         text))))
  
  (add-to-list 'org-export-filter-headline-functions
               'org-export-html-headline-anchor)
  (org-link-set-parameters "Https"
                           :follow (lambda (url arg) (browse-url (concat "https:" url) arg))
                           :export #'org-url-fancy-export)
  (defun org-url-fancy-export (url _desc backend)
    (let ((metadata (org-url-unfurl-metadata (concat "https:" url))))
      (cond
       ((org-export-derived-backend-p backend 'html)
        (concat
         "<div class=\"link-preview\">"
         (format "<a href=\"%s\">" (concat "https:" url))
         (when (plist-get metadata :image)
           (format "<img src=\"%s\"/>" (plist-get metadata :image)))
         "<small>"
         (replace-regexp-in-string "//\\(?:www\\.\\)?\\([^/]+\\)/?.*" "\\1" url)
         "</small><p>"
         (when (plist-get metadata :title)
           (concat "<b>" (org-html-encode-plain-text (plist-get metadata :title)) "</b></br>"))
         (when (plist-get metadata :description)
           (org-html-encode-plain-text (plist-get metadata :description)))
         "</p></a></div>"))
       (t url))))
  (setq org-url-unfurl-metadata--cache nil)
  (defun org-url-unfurl-metadata (url)
    (cdr (or (assoc url org-url-unfurl-metadata--cache)
             (car (push
                   (cons
                    url
                    (let* ((head-data
                            (-filter #'listp
                                     (cdaddr
                                      (with-current-buffer (progn (message "Fetching metadata from %s" url)
                                                                  (url-retrieve-synchronously url t t 5))
                                        (goto-char (point-min))
                                        (delete-region (point-min) (- (search-forward "<head") 6))
                                        (delete-region (search-forward "</head>") (point-max))
                                        (goto-char (point-min))
                                        (while (re-search-forward "<script[^\u2800]+?</script>" nil t)
                                          (replace-match ""))
                                        (goto-char (point-min))
                                        (while (re-search-forward "<style[^\u2800]+?</style>" nil t)
                                          (replace-match ""))
                                        (libxml-parse-html-region (point-min) (point-max))))))
                           (meta (delq nil
                                       (mapcar
                                        (lambda (tag)
                                          (when (eq 'meta (car tag))
                                            (cons (or (cdr (assoc 'name (cadr tag)))
                                                      (cdr (assoc 'property (cadr tag))))
                                                  (cdr (assoc 'content (cadr tag))))))
                                        head-data))))
                      (let ((title (or (cdr (assoc "og:title" meta))
                                       (cdr (assoc "twitter:title" meta))
                                       (nth 2 (assq 'title head-data))))
                            (description (or (cdr (assoc "og:description" meta))
                                             (cdr (assoc "twitter:description" meta))
                                             (cdr (assoc "description" meta))))
                            (image (or (cdr (assoc "og:image" meta))
                                       (cdr (assoc "twitter:image" meta)))))
                        (when image
                          (setq image (replace-regexp-in-string
                                       "^/" (concat "https://" (replace-regexp-in-string "//\\([^/]+\\)/?.*" "\\1" url) "/")
                                       (replace-regexp-in-string
                                        "^//" "https://"
                                        image))))
                        (list :title title :description description :image image))))
                   org-url-unfurl-metadata--cache)))))
  ;; (setq-default org-html-with-latex `dvisvgm)
  (setq org-html-mathjax-options
        '((path "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" )
          (scale "1")
          (autonumber "ams")
          (multlinewidth "85%")
          (tagindent ".8em")
          (tagside "right")))
  
  (setq org-html-mathjax-template
        "<script>
  MathJax = {
    chtml: {
      scale: %SCALE
    },
    svg: {
      scale: %SCALE,
      fontCache: \"global\"
    },
    tex: {
      tags: \"%AUTONUMBER\",
      multlineWidth: \"%MULTLINEWIDTH\",
      tagSide: \"%TAGSIDE\",
      tagIndent: \"%TAGINDENT\"
    }
  };
  </script>
  <script id=\"MathJax-script\" async
          src=\"%PATH\"></script>"))

(after! ox-latex
  ;; org-latex-compilers = ("pdflatex" "xelatex" "lualatex"), which are the possible values for %latex
  (setq org-latex-pdf-process '("LC_ALL=en_US.UTF-8 latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))
  (defun +org-export-latex-fancy-item-checkboxes (text backend info)
    (when (org-export-derived-backend-p backend 'latex)
      (replace-regexp-in-string
       "\\\\item\\[{$\\\\\\(\\w+\\)$}\\]"
       (lambda (fullmatch)
         (concat "\\\\item[" (pcase (substring fullmatch 9 -3) ; content of capture group
                               ("square"   "\\\\checkboxUnchecked")
                               ("boxminus" "\\\\checkboxTransitive")
                               ("boxtimes" "\\\\checkboxChecked")
                               (_ (substring fullmatch 9 -3))) "]"))
       text)))
  
  (add-to-list 'org-export-filter-item-functions
               '+org-export-latex-fancy-item-checkboxes)
  (after! ox-latex
    (let* ((article-sections '(("\\section{%s}" . "\\section*{%s}")
                               ("\\subsection{%s}" . "\\subsection*{%s}")
                               ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                               ("\\paragraph{%s}" . "\\paragraph*{%s}")
                               ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))
           (book-sections (append '(("\\chapter{%s}" . "\\chapter*{%s}"))
                                  article-sections))
           (hanging-secnum-preamble "\\renewcommand\\sectionformat{\\llap{\\thesection\\autodot\\enskip}}
  \\renewcommand\\subsectionformat{\\llap{\\thesubsection\\autodot\\enskip}}
  \\renewcommand\\subsubsectionformat{\\llap{\\thesubsubsection\\autodot\\enskip}}")
           (big-chap-preamble ))
      (setcdr (assoc "article" org-latex-classes)
              `(,(concat "\\documentclass{scrartcl}" hanging-secnum-preamble)
                ,@article-sections))
      (add-to-list 'org-latex-classes
                   `("report" ,(concat "\\documentclass{scrartcl}" hanging-secnum-preamble)
                     ,@article-sections))
      (add-to-list 'org-latex-classes
                   `("book" ,(concat "\\documentclass[twoside=false]{scrbook}"
                                     big-chap-preamble hanging-secnum-preamble)
                     ,@book-sections))
      (add-to-list 'org-latex-classes
                   `("blank" "[NO-DEFAULT-PACKAGES]\n[NO-PACKAGES]\n[EXTRA]"
                     ,@article-sections))
      (add-to-list 'org-latex-classes
                   `("bmc-article" "\\documentclass[article,code,maths]{bmc}\n[NO-DEFAULT-PACKAGES]\n[NO-PACKAGES]\n[EXTRA]"
                     ,@article-sections))
      (add-to-list 'org-latex-classes
                   `("bmc" "\\documentclass[code,maths]{bmc}\n[NO-DEFAULT-PACKAGES]\n[NO-PACKAGES]\n[EXTRA]"
                     ,@book-sections))))
  
  (setq org-latex-tables-booktabs t
        org-latex-hyperref-template
        "\\providecolor{url}{HTML}{0077bb}
  \\providecolor{link}{HTML}{882255}
  \\providecolor{cite}{HTML}{999933}
  \\hypersetup{
    pdfauthor={%a},
    pdftitle={%t},
    pdfkeywords={%k},
    pdfsubject={%d},
    pdfcreator={%c},
    pdflang={%L},
    breaklinks=true,
    colorlinks=true,
    linkcolor=link,
    urlcolor=url,
    citecolor=cite
  }
  \\urlstyle{same}
  %% hide links styles in toc
  \\NewCommandCopy{\\oldtoc}{\\tableofcontents}
  \\renewcommand{\\tableofcontents}{\\begingroup\\hypersetup{hidelinks}\\oldtoc\\endgroup}"
        org-latex-reference-command "\\cref{%s}")
    (defvar org-latex-maths-preamble
  "%% Maths-related packages
  % More maths environments, commands, and symbols.
  \\usepackage{amsmath, amssymb}
  % Slanted fractions with \\sfrac{a}{b}, in text and maths.
  \\usepackage{xfrac}
  % Visually cancel expressions with \\cancel{value} and \\cancelto{expression}{value}
  \\usepackage[makeroom]{cancel}
  % Improvements on amsmath and utilities for mathematical typesetting
  \\usepackage{mathtools}
  
  % Deliminators
  \\DeclarePairedDelimiter{\\abs}{\\lvert}{\\rvert}
  \\DeclarePairedDelimiter{\\norm}{\\lVert}{\\rVert}
  
  \\DeclarePairedDelimiter{\\ceil}{\\lceil}{\\rceil}
  \\DeclarePairedDelimiter{\\floor}{\\lfloor}{\\rfloor}
  \\DeclarePairedDelimiter{\\round}{\\lfloor}{\\rceil}
  
  \\newcommand{\\RR}[1][]{\\ensuremath{\\ifstrempty{#1}{\\mathbb{R}}{\\mathbb{R}^{#1}}}} % Real numbers
  \\newcommand{\\NN}[1][]{\\ensuremath{\\ifstrempty{#1}{\\mathbb{N}}{\\mathbb{N}^{#1}}}} % Natural numbers
  \\newcommand{\\ZZ}[1][]{\\ensuremath{\\ifstrempty{#1}{\\mathbb{Z}}{\\mathbb{Z}^{#1}}}} % Integer numbers
  \\newcommand{\\QQ}[1][]{\\ensuremath{\\ifstrempty{#1}{\\mathbb{Q}}{\\mathbb{Q}^{#1}}}} % Rational numbers
  \\newcommand{\\CC}[1][]{\\ensuremath{\\ifstrempty{#1}{\\mathbb{C}}{\\mathbb{C}^{#1}}}} % Complex numbers
  
  % Easy derivatives
  \\ProvideDocumentCommand\\dv{o m g}{%
    \\IfNoValueTF{#3}{%
      \\dv[#1]{}{#2}}{%
      \\IfNoValueTF{#1}{%
        \\frac{\\dd #2}{\\dd #3}%
      }{\\frac{\\dd[#1] #2}{\\dd {#3}^{#1}}}}}
  % Easy partial derivatives
  \\ExplSyntaxOn
  \\ProvideDocumentCommand\\pdv{o m g}{%
    \\IfNoValueTF{#3}{\\pdv[#1]{}{#2}}%
    {\\ifnum\\clist_count:n{#3}<2
      \\IfValueTF{#1}{\\frac{\\partial^{#1} #2}{\\partial {#3}^{#1}}}%
      {\\frac{\\partial #2}{\\partial #3}}
      \\else
      \\frac{\\IfValueTF{#1}{\\partial^{#1}}{\\partial^{\\clist_count:n{#3}}}#2}%
      {\\clist_map_inline:nn{#3}{\\partial ##1 \\,}\\!}
      \\fi}}
  \\ExplSyntaxOff
  
  % Laplacian
  \\DeclareMathOperator{\\Lap}{\\mathcal{L}}
  
  % Statistics
  \\DeclareMathOperator{\\Var}{Var} % varience
  \\DeclareMathOperator{\\Cov}{Cov} % covarience
  \\newcommand{\\EE}{\\ensuremath{\\mathbb{E}}} % expected value
  \\DeclareMathOperator{\\E}{E} % expected value
  
  % I prefer the slanted \\leq/\\geq
  \\let\\barleq\\leq % Save them in case they're every wanted
  \\let\\bargeq\\geq
  \\renewcommand{\\leq}{\\leqslant}
  \\renewcommand{\\geq}{\\geqslant}
  
  % Redefine the matrix environment to allow for alignment
  % via an optional argument, and use r as the default.
  \\makeatletter
  \\renewcommand*\\env@matrix[1][r]{\\hskip -\\arraycolsep%
      \\let\\@ifnextchar\\new@ifnextchar
      \\array{*\\c@MaxMatrixCols #1}}
  \\makeatother
  
  % Slanted roman \"d\" for derivatives
  \\ifcsname pdfoutput\\endcsname
    \\ifnum\\pdfoutput>0 % PDF
      \\newsavebox\\diffdbox{}
      \\newcommand{\\slantedromand}{{\\mathpalette\\makesl{d}}}
      \\newcommand{\\makesl}[2]{%
        \\begingroup
        \\sbox{\\diffdbox}{$\\mathsurround=0pt#1\\mathrm{#2}$}%
        \\pdfsave%
        \\pdfsetmatrix{1 0 0.2 1}%
        \\rlap{\\usebox{\\diffdbox}}%
        \\pdfrestore%
        \\hskip\\wd\\diffdbox%
        \\endgroup}
    \\else % DVI
      \\newcommand{\\slantedromand}{d} % fallback
    \\fi
  \\else % Also DVI
    \\newcommand{\\slantedromand}{d} % fallback
  \\fi
  
  % Derivative d^n, nicely spaced
  \\makeatletter
  \\newcommand{\\dd}[1][]{\\mathop{}\\!%
    \\expandafter\\ifx\\expandafter&\\detokenize{#1}&% \\ifstrempty from etoolbox
      \\slantedromand\\@ifnextchar^{\\hspace{0.2ex}}{\\hspace{0.1ex}}
    \\else
      \\slantedromand\\hspace{0.2ex}^{#1}
    \\fi}
  \\makeatother
  
  \\NewCommandCopy{\\daccent}{\\d}
  \\renewcommand{\\d}{\\ifmmode\\dd\\else\\daccent\\fi}"
  "Preamble that sets up a bunch of mathematical conveniences.")
  (defvar org-latex-embed-files-preamble
    "\\usepackage[main,include]{embedall}
  \\IfFileExists{./\\jobname.org}{\\embedfile[desc=The original file]{\\jobname.org}}{}"
    "Preamble that embeds files within the pdf.")
  
  (defvar org-latex-caption-preamble
    "\\usepackage{subcaption}
  \\usepackage[hypcap=true]{caption}
  \\setkomafont{caption}{\\sffamily\\small}
  \\setkomafont{captionlabel}{\\upshape\\bfseries}
  \\captionsetup{justification=raggedright,singlelinecheck=true}
  \\usepackage{capt-of} % required by Org"
    "Preamble that improves captions.")
  
  (defvar org-latex-checkbox-preamble
    "\\newcommand{\\checkboxUnchecked}{$\\square$}
  \\newcommand{\\checkboxTransitive}{\\rlap{\\raisebox{-0.1ex}{\\hspace{0.35ex}\\Large\\textbf -}}$\\square$}
  \\newcommand{\\checkboxChecked}{\\rlap{\\raisebox{0.2ex}{\\hspace{0.35ex}\\scriptsize \\ding{52}}}$\\square$}"
    "Preamble that improves checkboxes.")
  
  (defvar org-latex-box-preamble
    "\\ExplSyntaxOn
  \\NewCoffin\\Content
  \\NewCoffin\\SideRule
  \\NewDocumentCommand{\\defsimplebox}{O{\\ding{117}} O{0.36em} m m m}{%
    % #1 ding, #2 ding offset, #3 name, #4 colour, #5 default label
    \\definecolor{#3}{HTML}{#4}
    \\NewDocumentEnvironment{#3}{ O{#5} }
    {
      \\vcoffin_set:Nnw \\Content { \\linewidth }
      \\noindent \\ignorespaces
      \\par\\vspace{-0.7\\baselineskip}%
      \\textcolor{#3}{#1}~\\textcolor{#3}{\\textbf{##1}}%
      \\vspace{-0.8\\baselineskip}
      \\begin{addmargin}[1em]{1em}
      }
      {
      \\end{addmargin}
      \\vspace{-0.5\\baselineskip}
      \\vcoffin_set_end:
      \\SetHorizontalCoffin\\SideRule{\\color{#3}\\rule{1pt}{\\CoffinTotalHeight\\Content}}
      \\JoinCoffins*\\Content[l,t]\\SideRule[l,t](#2,-0.7em)
      \\noindent\\TypesetCoffin\\Content
      \\vspace*{\\CoffinTotalHeight\\Content}\\bigskip
      \\vspace{-2\\baselineskip}
    }
  }
  \\ExplSyntaxOff"
    "Preamble that provides a macro for custom boxes.")
  (defun org-latex-embed-extra-files ()
    "Return a string that uses embedfile to embed all tangled files."
    (mapconcat
     (lambda (file-desc)
       (format "\\IfFileExists{%1$s}{\\embedfile[desc=%2$s]{%1$s}}{}"
               (thread-last (car file-desc)
                            (replace-regexp-in-string "\\\\" "\\\\\\\\")
                            (replace-regexp-in-string "~" "\\\\string~"))
               (cdr file-desc)))
     (append
      (let (tangle-fspecs) ; All files being tangled to.
        (org-element-cache-map
         (lambda (src)
           (when (and (not (org-in-commented-heading-p nil src))
                      (not (org-in-archived-heading-p nil src)))
             (when-let ((lang (org-element-property :language src))
                        (params
                         (apply
                          #'org-babel-merge-params
                          (append
                           (org-with-point-at (org-element-property :begin src)
                             (org-babel-params-from-properties lang t))
                           (mapcar
                            (lambda (h)
                              (org-babel-parse-header-arguments h t))
                            (cons (org-element-property :parameters src)
                                  (org-element-property :header src))))))
                        (tangle-value
                         (pcase (alist-get :tangle params)
                           ((and (pred stringp) (pred (string-match-p "^(.*)$")) expr)
                            (eval (read expr)))
                           (val val)))
                        (tangle-file
                         (pcase tangle-value
                           ((or "no" (guard (member (alist-get :export-embed params) '("no" "nil"))))
                            nil)
                           ("yes"
                            (file-name-with-extension
                             (file-name-nondirectory (buffer-file-name))
                             (or (alist-get lang org-babel-tangle-lang-exts nil nil #'equal)
                                 lang)))
                           (val val))))
               (unless (assoc tangle-file tangle-fspecs)
                 (push
                  (cons tangle-file (format "Tangled %s file" lang))
                  tangle-fspecs)))))
         :granularity 'element
         :restrict-elements '(src-block))
        (nreverse tangle-fspecs))
      (let (extra-files)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward "^[ \t]*#\\+embed:" nil t)
            (let* ((file-desc (split-string (org-element-property :value (org-element-at-point)) " :desc\\(?:ription\\)? ")))
              (push (cons (car file-desc) (or (cdr file-desc) "Extra file")) extra-files))))
        (nreverse extra-files)))
     "\n"))
  (defvar org-latex-embed-files t
    "Embed the source .org, .tex, and any tangled files.")
  (defvar org-latex-use-microtype t
    "Use the microtype pakage.")
  (defvar org-latex-italic-quotes t
    "Make \"quote\" environments italic.")
  (defvar org-latex-par-sep t
    "Vertically seperate paragraphs, and remove indentation.")
  
  ;; (org-export-update-features 'latex
  ;;   ((image caption)
  ;;    :condition "\\[\\[xkcd:"))
  ;; (org-export-update-features 'latex
  ;;   (maths
  ;;    :snippet org-latex-maths-preamble
  ;;    :order 0.2)
  ;;   (cleveref
  ;;    :condition "cref:\\|\\cref{\\|\\[\\[[^\\]+\n?[^\\]\\]\\]"
  ;;    :snippet "\\usepackage[capitalize]{cleveref}"
  ;;    :order 1)
  ;;   (caption
  ;;    :snippet org-latex-caption-preamble
  ;;    :order 2.1)
  ;;   (microtype
  ;;    :condition org-latex-use-microtype
  ;;    :snippet "\\usepackage[activate={true,nocompatibility},final,tracking=true,kerning=true,spacing=true,factor=2000]{microtype}\n"
  ;;    :order 0.1)
  ;;   (embed-files
  ;;    :condition org-latex-embed-files
  ;;    :snippet org-latex-embed-files-preamble
  ;;    :order -2)
  ;;   (embed-tangled
  ;;    :condition (and org-latex-embed-files
  ;;                    "^[ \t]*#\\+embed\\|^[ \t]*#\\+begin_src\\|^[ \t]*#\\+BEGIN_SRC")
  ;;    :requires embed-files
  ;;    :snippet org-latex-embed-extra-files
  ;;    :order -1)
  ;;   (acronym
  ;;    :condition "[;\\\\]?\\b[A-Z][A-Z]+s?[^A-Za-z]"
  ;;    :snippet "\\newcommand{\\acr}[1]{\\protect\\textls*[110]{\\scshape #1}}\n\\newcommand{\\acrs}{\\protect\\scalebox{.91}[.84]{\\hspace{0.15ex}s}}"
  ;;    :order 0.4)
  ;;   (box-drawing
  ;;    :condition "[\u2500-\u259F]"
  ;;    :snippet "\\usepackage{pmboxdraw}"
  ;;    :order 0.05)
  ;;   (italic-quotes
  ;;    :condition (and org-latex-italic-quotes "^[ \t]*#\\+begin_quote\\|\\\\begin{quote}")
  ;;    :snippet "\\renewcommand{\\quote}{\\list{}{\\rightmargin\\leftmargin}\\item\\relax\\em}\n"
  ;;    :order 0.5)
  ;;   (par-sep
  ;;    :condition org-latex-par-sep
  ;;    :snippet "\\setlength{\\parskip}{\\baselineskip}\n\\setlength{\\parindent}{0pt}\n"
  ;;    :order 0.5)
  ;;   (.pifont
  ;;    :snippet "\\usepackage{pifont}")
  ;;   (.xcoffins
  ;;    :snippet "\\usepackage{xcoffins}")
  ;;   (checkbox
  ;;    :condition "^[ \t]*\\(?:[-+*]\\|[0-9]+[.)]\\|[A-Za-z]+[.)]\\) \\[[ -X]\\]"
  ;;    :requires .pifont
  ;;    :snippet (concat (unless (memq 'maths features)
  ;;                       "\\usepackage{amssymb} % provides \\square")
  ;;                     org-latex-checkbox-preamble)
  ;;    :order 3)
  ;;   (.fancy-box
  ;;    :requires (.pifont .xcoffins)
  ;;    :snippet org-latex-box-preamble
  ;;    :order 3.9)
  ;;   (box-warning
  ;;    :condition "^[ \t]*#\\+begin_warning\\|\\\\begin{warning}"
  ;;    :requires .fancy-box
  ;;    :snippet "\\defsimplebox{warning}{e66100}{Warning}"
  ;;    :order 4)
  ;;   (box-info
  ;;    :condition "^[ \t]*#\\+begin_info\\|\\\\begin{info}"
  ;;    :requires .fancy-box
  ;;    :snippet "\\defsimplebox{info}{3584e4}{Information}"
  ;;    :order 4)
  ;;   (box-notes
  ;;    :condition "^[ \t]*#\\+begin_notes\\|\\\\begin{notes}"
  ;;    :requires .fancy-box
  ;;    :snippet "\\defsimplebox{notes}{26a269}{Notes}"
  ;;    :order 4)
  ;;   (box-success
  ;;    :condition "^[ \t]*#\\+begin_success\\|\\\\begin{success}"
  ;;    :requires .fancy-box
  ;;    :snippet "\\defsimplebox{success}{26a269}{\\vspace{-\\baselineskip}}"
  ;;    :order 4)
  ;;   (box-error
  ;;    :condition "^[ \t]*#\\+begin_error\\|\\\\begin{error}"
  ;;    :requires .fancy-box
  ;;    :snippet "\\defsimplebox{error}{c01c28}{Important}"
  ;;    :order 4))
  (setq org-latex-packages-alist
        '(("" "xcolor" t)))
  (defvar org-latex-default-fontset 'alegreya
    "Fontset from `org-latex-fontsets' to use by default.
  As cm (computer modern) is TeX's default, that causes nothing
  to be added to the document.
  
  If \"nil\" no custom fonts will ever be used.")
  
  (eval '(cl-pushnew '(:latex-font-set nil "fontset" org-latex-default-fontset)
                     (org-export-backend-options (org-export-get-backend 'latex))))
  (defun org-latex-fontset-entry ()
    "Get the fontset spec of the current file.
  Has format \"name\" or \"name-style\" where 'name' is one of
  the cars in `org-latex-fontsets'."
    (let ((fontset-spec
           (symbol-name
            (or (car (delq nil
                           (mapcar
                            (lambda (opt-line)
                              (plist-get (org-export--parse-option-keyword opt-line 'latex)
                                         :latex-font-set))
                            (cdar (org-collect-keywords '("OPTIONS"))))))
                org-latex-default-fontset))))
      (cons (intern (car (split-string fontset-spec "-")))
            (when (cadr (split-string fontset-spec "-"))
              (intern (concat ":" (cadr (split-string fontset-spec "-"))))))))
  
  (defun org-latex-fontset (&rest desired-styles)
    "Generate a LaTeX preamble snippet which applies the current fontset for DESIRED-STYLES."
    (let* ((fontset-spec (org-latex-fontset-entry))
           (fontset (alist-get (car fontset-spec) org-latex-fontsets)))
      (if fontset
          (concat
           (mapconcat
            (lambda (style)
              (when (plist-get fontset style)
                (concat (plist-get fontset style) "\n")))
            desired-styles
            "")
           (when (memq (cdr fontset-spec) desired-styles)
             (pcase (cdr fontset-spec)
               (:serif "\\renewcommand{\\familydefault}{\\rmdefault}\n")
               (:sans "\\renewcommand{\\familydefault}{\\sfdefault}\n")
               (:mono "\\renewcommand{\\familydefault}{\\ttdefault}\n"))))
        (error "Font-set %s is not provided in org-latex-fontsets" (car fontset-spec)))))
  ;; (org-export-update-features 'latex
  ;;   (custom-font
  ;;    :condition org-latex-default-fontset
  ;;    :snippet (org-latex-fontset :serif :sans :mono)
  ;;    :order 0)
  ;;   (custom-maths-font
  ;;    :condition t
  ;;    :when (custom-font maths)
  ;;    :snippet (org-latex-fontset :maths)
  ;;    :order 0.3))
  (defvar org-latex-fontsets
    '((cm nil) ; computer modern
      (## nil) ; no font set
      (alegreya
       :serif "\\usepackage[osf]{Alegreya}"
       :sans "\\usepackage{AlegreyaSans}"
       :mono "\\usepackage[scale=0.88]{sourcecodepro}"
       :maths "\\usepackage[varbb]{newpxmath}")
      (biolinum
       :serif "\\usepackage[osf]{libertineRoman}"
       :sans "\\usepackage[sfdefault,osf]{biolinum}"
       :mono "\\usepackage[scale=0.88]{sourcecodepro}"
       :maths "\\usepackage[libertine,varvw]{newtxmath}")
      (fira
       :sans "\\usepackage[sfdefault,scale=0.85]{FiraSans}"
       :mono "\\usepackage[scale=0.80]{FiraMono}"
       :maths "\\usepackage{newtxsf} % change to firamath in future?")
      (kp
       :serif "\\usepackage{kpfonts}")
      (newpx
       :serif "\\usepackage{newpxtext}"
       :sans "\\usepackage{gillius}"
       :mono "\\usepackage[scale=0.9]{sourcecodepro}"
       :maths "\\usepackage[varbb]{newpxmath}")
      (noto
       :serif "\\usepackage[osf]{noto-serif}"
       :sans "\\usepackage[osf]{noto-sans}"
       :mono "\\usepackage[scale=0.96]{noto-mono}"
       :maths "\\usepackage{notomath}")
      (plex
       :serif "\\usepackage{plex-serif}"
       :sans "\\usepackage{plex-sans}"
       :mono "\\usepackage[scale=0.95]{plex-mono}"
       :maths "\\usepackage{newtxmath}") ; may be plex-based in future
      (source
       :serif "\\usepackage[osf,semibold]{sourceserifpro}"
       :sans "\\usepackage[osf,semibold]{sourcesanspro}"
       :mono "\\usepackage[scale=0.92]{sourcecodepro}"
       :maths "\\usepackage{newtxmath}") ; may be sourceserifpro-based in future
      (times
       :serif "\\usepackage{newtxtext}"
       :maths "\\usepackage{newtxmath}"))
    "Alist of fontset specifications.
  Each car is the name of the fontset (which cannot include \"-\").
  
  Each cdr is a plist with (optional) keys :serif, :sans, :mono, and :maths.
  A key's value is a LaTeX snippet which loads such a font.")
  ;; (org-export-update-features 'latex
  ;;   (alegreya-typeface
  ;;    :condition (string= (car (org-latex-fontset-entry)) "alegreya")
  ;;    :snippet nil)
  ;;   (alegreya-tabular-figures
  ;;    :condition t
  ;;    :when (alegreya-typeface table)
  ;;    :snippet "\
  ;; \\makeatletter
  ;; % tabular lining figures in tables
  ;; \\renewcommand{\\tabular}{\\AlegreyaTLF\\let\\@halignto\\@empty\\@tabular}
  ;; \\makeatother"
  ;;    :order 0.5))
  ;; (org-export-update-features 'latex
  ;;   (alegreya-latex-symbol
  ;;     :condition "LaTeX"
  ;;     :when alegreya-typeface
  ;;     :snippet "\
  ;; \\makeatletter
  ;; % Kerning around the A needs adjusting
  ;; \\DeclareRobustCommand{\\LaTeX}{L\\kern-.24em%
  ;;         {\\sbox\\z@ T%
  ;;          \\vbox to\\ht\\z@{\\hbox{\\check@mathfonts
  ;;                               \\fontsize\\sf@size\\z@
  ;;                               \\math@fontsfalse\\selectfont
  ;;                               A}%
  ;;                         \\vss}%
  ;;         }%
  ;;         \\kern-.10em%
  ;;         \\TeX}
  ;; \\makeatother"
  ;;     :order 0.5))
  (defvar org-latex-cover-page 'auto
    "When t, use a cover page by default.
  When auto, use a cover page when the document's wordcount exceeds
  `org-latex-cover-page-wordcount-threshold'.
  
  Set with #+option: coverpage:{yes,auto,no} in org buffers.")
  (defvar org-latex-cover-page-wordcount-threshold 5000
    "Document word count at which a cover page will be used automatically.
  This condition is applied when cover page option is set to auto.")
  (defvar org-latex-subtitle-coverpage-format "\\\\\\bigskip\n\\LARGE\\mdseries\\itshape\\color{black!80} %s\\par"
    "Variant of `org-latex-subtitle-format' to use with the cover page.")
  (defvar org-latex-cover-page-maketitle
    "\\usepackage{tikz}
    \\usetikzlibrary{shapes.geometric}
    \\usetikzlibrary{calc}
    
    \\newsavebox\\orgicon
    \\begin{lrbox}{\\orgicon}
      \\begin{tikzpicture}[y=0.80pt, x=0.80pt, inner sep=0pt, outer sep=0pt]
        \\path[fill=black!6] (16.15,24.00) .. controls (15.58,24.00) and (13.99,20.69) .. (12.77,18.06)arc(215.55:180.20:2.19) .. controls (12.33,19.91) and (11.27,19.09) .. (11.43,18.05) .. controls (11.36,18.09) and (10.17,17.83) .. (10.17,17.82) .. controls (9.94,18.75) and (9.37,19.44) .. (9.02,18.39) .. controls (8.32,16.72) and (8.14,15.40) .. (9.13,13.80) .. controls (8.22,9.74) and (2.18,7.75) .. (2.81,4.47) .. controls (2.99,4.47) and (4.45,0.99) .. (9.15,2.41) .. controls (14.71,3.99) and (17.77,0.30) .. (18.13,0.04) .. controls (18.65,-0.49) and (16.78,4.61) .. (12.83,6.90) .. controls (10.49,8.18) and (11.96,10.38) .. (12.12,11.15) .. controls (12.12,11.15) and (14.00,9.84) .. (15.36,11.85) .. controls (16.58,11.53) and (17.40,12.07) .. (18.46,11.69) .. controls (19.10,11.41) and (21.79,11.58) .. (20.79,13.08) .. controls (20.79,13.08) and (21.71,13.90) .. (21.80,13.99) .. controls (21.97,14.75) and (21.59,14.91) .. (21.47,15.12) .. controls (21.44,15.60) and (21.04,15.79) .. (20.55,15.44) .. controls (19.45,15.64) and (18.36,15.55) .. (17.83,15.59) .. controls (16.65,15.76) and (15.67,16.38) .. (15.67,16.38) .. controls (15.40,17.19) and (14.82,17.01) .. (14.09,17.32) .. controls (14.70,18.69) and (14.76,19.32) .. (15.50,21.32) .. controls (15.76,22.37) and (16.54,24.00) .. (16.15,24.00) -- cycle(7.83,16.74) .. controls (6.83,15.71) and (5.72,15.70) .. (4.05,15.42) .. controls (2.75,15.19) and (0.39,12.97) .. (0.02,10.68) .. controls (-0.02,10.07) and (-0.06,8.50) .. (0.45,7.18) .. controls (0.94,6.05) and (1.27,5.45) .. (2.29,4.85) .. controls (1.41,8.02) and (7.59,10.18) .. (8.55,13.80) -- (8.55,13.80) .. controls (7.73,15.00) and (7.80,15.64) .. (7.83,16.74) -- cycle;
      \\end{tikzpicture}
    \\end{lrbox}
    
    \\makeatletter
    \\g@addto@macro\\tableofcontents{\\clearpage}
    \\renewcommand\\maketitle{
      \\thispagestyle{empty}
      \\hyphenpenalty=10000 % hyphens look bad in titles
      \\renewcommand{\\baselinestretch}{1.1}
      \\NewCommandCopy{\\oldtoday}{\\today}
      \\renewcommand{\\today}{\\LARGE\\number\\year\\\\\\large%
        \\ifcase \\month \\or Jan\\or Feb\\or Mar\\or Apr\\or May \\or Jun\\or Jul\\or Aug\\or Sep\\or Oct\\or Nov\\or Dec\\fi
        ~\\number\\day}
      \\begin{tikzpicture}[remember picture,overlay]
        %% Background Polygons %%
        \\foreach \\i in {2.5,...,22} % bottom left
        {\\node[rounded corners,black!3.5,draw,regular polygon,regular polygon sides=6, minimum size=\\i cm,ultra thick] at ($(current page.west)+(2.5,-4.2)$) {} ;}
        \\foreach \\i in {0.5,...,22} % top left
        {\\node[rounded corners,black!5,draw,regular polygon,regular polygon sides=6, minimum size=\\i cm,ultra thick] at ($(current page.north west)+(2.5,2)$) {} ;}
        \\node[rounded corners,fill=black!4,regular polygon,regular polygon sides=6, minimum size=5.5 cm,ultra thick] at ($(current page.north west)+(2.5,2)$) {};
        \\foreach \\i in {0.5,...,24} % top right
        {\\node[rounded corners,black!2,draw,regular polygon,regular polygon sides=6, minimum size=\\i cm,ultra thick] at ($(current page.north east)+(0,-8.5)$) {} ;}
        \\node[fill=black!3,rounded corners,regular polygon,regular polygon sides=6, minimum size=2.5 cm,ultra thick] at ($(current page.north east)+(0,-8.5)$) {};
        \\foreach \\i in {21,...,3} % bottom right
        {\\node[black!3,rounded corners,draw,regular polygon,regular polygon sides=6, minimum size=\\i cm,ultra thick] at ($(current page.south east)+(-1.5,0.75)$) {} ;}
        \\node[fill=black!3,rounded corners,regular polygon,regular polygon sides=6, minimum size=2 cm,ultra thick] at ($(current page.south east)+(-1.5,0.75)$) {};
        \\node[align=center, scale=1.4] at ($(current page.south east)+(-1.5,0.75)$) {\\usebox\\orgicon};
        %% Text %%
        \\node[left, align=right, black, text width=0.8\\paperwidth, minimum height=3cm, rounded corners,font=\\Huge\\bfseries] at ($(current page.north east)+(-2,-8.5)$)
        {\\@title};
        \\node[left, align=right, black, text width=0.8\\paperwidth, minimum height=2cm, rounded corners, font=\\Large] at ($(current page.north east)+(-2,-11.8)$)
        {\\scshape \\@author};
        \\renewcommand{\\baselinestretch}{0.75}
        \\node[align=center,rounded corners,fill=black!3,text=black,regular polygon,regular polygon sides=6, minimum size=2.5 cm,inner sep=0, font=\\Large\\bfseries ] at ($(current page.west)+(2.5,-4.2)$)
        {\\@date};
      \\end{tikzpicture}
      \\let\\today\\oldtoday
      \\clearpage}
    \\makeatother"
    "LaTeX preamble snippet that sets \\maketitle to produce a cover page.")
  
  (eval '(cl-pushnew '(:latex-cover-page nil "coverpage" org-latex-cover-page)
                     (org-export-backend-options (org-export-get-backend 'latex))))
  
  (defun org-latex-cover-page-p ()
    "Whether a cover page should be used when exporting this Org file."
    (pcase (or (car
                (delq nil
                      (mapcar
                       (lambda (opt-line)
                         (plist-get (org-export--parse-option-keyword opt-line 'latex) :latex-cover-page))
                       (cdar (org-collect-keywords '("OPTIONS"))))))
               org-latex-cover-page)
      ((or 't 'yes) t)
      ('auto (when (> (count-words (point-min) (point-max)) org-latex-cover-page-wordcount-threshold) t))
      (_ nil)))
  
  (defadvice! org-latex-set-coverpage-subtitle-format-a (contents info)
    "Set the subtitle format when a cover page is being used."
    :before #'org-latex-template
    (when (org-latex-cover-page-p)
      (setf info (plist-put info :latex-subtitle-format org-latex-subtitle-coverpage-format))))
  
  ;; (org-export-update-features 'latex
  ;;   (cover-page
  ;;    :condition (org-latex-cover-page-p)
  ;;    :snippet org-latex-cover-page-maketitle
  ;;    :order 9))
  (defvar org-latex-condense-lists t
    "Reduce the space between list items.")
  (defvar org-latex-condensed-lists
    "\\newcommand{\\setuplistspacing}{\\setlength{\\itemsep}{-0.5ex}\\setlength{\\parskip}{1.5ex}\\setlength{\\parsep}{0pt}}
    \\let\\olditem\\itemize\\renewcommand{\\itemize}{\\olditem\\setuplistspacing}
    \\let\\oldenum\\enumerate\\renewcommand{\\enumerate}{\\oldenum\\setuplistspacing}
    \\let\\olddesc\\description\\renewcommand{\\description}{\\olddesc\\setuplistspacing}"
    "LaTeX preamble snippet that reduces the space between list items.")
  
  ;; (org-export-update-features 'latex
  ;;   (condensed-lists
  ;;    :condition (and org-latex-condense-lists "^[ \t]*[-+]\\|^[ \t]*[1Aa][.)] ")
  ;;    :snippet org-latex-condensed-lists
  ;;    :order 0.7))
  (use-package! engrave-faces-latex
    :after ox-latex)
  (setq org-latex-listings 'engraved)
  ;; (org-export-update-features 'latex
  ;;   (no-protrusion-in-code
  ;;    :condition t
  ;;    :when microtype
  ;;    :snippet "\\ifcsname Code\\endcsname\n  \\let\\oldcode\\Code\\renewcommand{\\Code}{\\microtypesetup{protrusion=false}\\oldcode}\n\\fi"
  ;;    :order 98.5))
  (defadvice! org-latex-example-block-engraved (orig-fn example-block contents info)
    "Like `org-latex-example-block', but supporting an engraved backend"
    :around #'org-latex-example-block
    (let ((output-block (funcall orig-fn example-block contents info)))
      (if (eq 'engraved (plist-get info :latex-listings))
          (format "\\begin{Code}[alt]\n%s\n\\end{Code}" output-block)
        output-block)))
  (defvar +org-pdflatex-inputenc-encoded-chars
    "[[:ascii:]\u00A0-\u01F0\u0218-\u021BȲȳȷˆˇ˜˘˙˛˝\u0400-\u04FFḂḃẞ\u200B\u200C\u2010-\u201E†‡•…‰‱‹›※‽⁄⁎⁒₡₤₦₩₫€₱℃№℗℞℠™Ω℧℮←↑→↓〈〉␢␣◦◯♪⟨⟩Ḡḡ\uFB00-\uFB06\u2500-\u259F]")
  
  (defun +org-latex-replace-non-ascii-chars (text backend info)
    "Replace non-ascii chars with \\char\"XYZ forms."
    (when (and (org-export-derived-backend-p backend 'latex)
               (string= (plist-get info :latex-compiler) "pdflatex"))
      (let (case-replace)
        (replace-regexp-in-string "[^[:ascii:]]"
                                  (lambda (nonascii)
                                    (if (or (string-match-p +org-pdflatex-inputenc-encoded-chars nonascii)
                                            (string-match-p org-latex-emoji--rx nonascii))
                                        nonascii
                                      (or (cdr (assoc nonascii +org-latex-non-ascii-char-substitutions))
                                          "¿")))
                                  text))))
  
  (add-to-list 'org-export-filter-plain-text-functions #'+org-latex-replace-non-ascii-chars t)
  (defvar +org-latex-non-ascii-char-substitutions
     '(("ɑ" . "\\\\(\\\\alpha\\\\)")
       ("β" . "\\\\(\\\\beta\\\\)")
       ("γ" . "\\\\(\\\\gamma\\\\)")
       ("δ" . "\\\\(\\\\delta\\\\)")
       ("ε" . "\\\\(\\\\epsilon\\\\)")
       ("ϵ" . "\\\\(\\\\varepsilon\\\\)")
       ("ζ" . "\\\\(\\\\zeta\\\\)")
       ("η" . "\\\\(\\\\eta\\\\)")
       ("θ" . "\\\\(\\\\theta\\\\)")
       ("ϑ" . "\\\\(\\\\vartheta\\\\)")
       ("ι" . "\\\\(\\\\iota\\\\)")
       ("κ" . "\\\\(\\\\kappa\\\\)")
       ("λ" . "\\\\(\\\\lambda\\\\)")
       ("μ" . "\\\\(\\\\mu\\\\)")
       ("ν" . "\\\\(\\\\nu\\\\)")
       ("ξ" . "\\\\(\\\\xi\\\\)")
       ("π" . "\\\\(\\\\pi\\\\)")
       ("ϖ" . "\\\\(\\\\varpi\\\\)")
       ("ρ" . "\\\\(\\\\rho\\\\)")
       ("ϱ" . "\\\\(\\\\varrho\\\\)")
       ("σ" . "\\\\(\\\\sigma\\\\)")
       ("ς" . "\\\\(\\\\varsigma\\\\)")
       ("τ" . "\\\\(\\\\tau\\\\)")
       ("υ" . "\\\\(\\\\upsilon\\\\)")
       ("ϕ" . "\\\\(\\\\phi\\\\)")
       ("φ" . "\\\\(\\\\varphi\\\\)")
       ("ψ" . "\\\\(\\\\psi\\\\)")
       ("ω" . "\\\\(\\\\omega\\\\)")
       ("Γ" . "\\\\(\\\\Gamma\\\\)")
       ("Δ" . "\\\\(\\\\Delta\\\\)")
       ("Θ" . "\\\\(\\\\Theta\\\\)")
       ("Λ" . "\\\\(\\\\Lambda\\\\)")
       ("Ξ" . "\\\\(\\\\Xi\\\\)")
       ("Π" . "\\\\(\\\\Pi\\\\)")
       ("Σ" . "\\\\(\\\\Sigma\\\\)")
       ("Υ" . "\\\\(\\\\Upsilon\\\\)")
       ("Φ" . "\\\\(\\\\Phi\\\\)")
       ("Ψ" . "\\\\(\\\\Psi\\\\)")
       ("Ω" . "\\\\(\\\\Omega\\\\)")
       ("א" . "\\\\(\\\\aleph\\\\)")
       ("ב" . "\\\\(\\\\beth\\\\)")
       ("ד" . "\\\\(\\\\daleth\\\\)")
       ("ג" . "\\\\(\\\\gimel\\\\)")))
  (defvar +org-latex-abbreviations
    '(;; Latin
      "cf." "e.g." "etc." "et al." "i.e." "v." "vs." "viz." "n.b."
      ;; Corperate
      "inc." "govt." "ltd." "pty." "dept."
      ;; Temporal
      "est." "c."
      ;; Honorifics
      "Prof." "Dr." "Mr." "Mrs." "Ms." "Miss." "Sr." "Jr."
      ;; Components of a work
      "ed." "vol." "sec." "chap." "pt." "pp." "op." "no."
      ;; Common usage
      "approx." "misc." "min." "max.")
    "A list of abbreviations that should be spaced correctly when exporting to LaTeX.")
  
  (defun +org-latex-correct-latin-abbreviation-spaces (text backend _info)
    "Normalise spaces after Latin abbreviations."
    (when (org-export-derived-backend-p backend 'latex)
      (replace-regexp-in-string (rx (group (or line-start space)
                                           (regexp (regexp-opt-group +org-latex-abbreviations)))
                                    (or line-end space))
                                "\\1\\\\ "
                                text)))
  
  (add-to-list 'org-export-filter-paragraph-functions #'+org-latex-correct-latin-abbreviation-spaces t)
  (defvar org-latex-extra-special-string-regexps
    '(("<->" . "\\\\(\\\\leftrightarrow{}\\\\)")
      ("->" . "\\\\textrightarrow{}")
      ("<-" . "\\\\textleftarrow{}")))
  
  (defun org-latex-convert-extra-special-strings (string)
    "Convert special characters in STRING to LaTeX."
    (dolist (a org-latex-extra-special-string-regexps string)
      (let ((re (car a))
            (rpl (cdr a)))
        (setq string (replace-regexp-in-string re rpl string t)))))
  
  (defadvice! org-latex-plain-text-extra-special-a (orig-fn text info)
    "Make `org-latex-plain-text' handle some extra special strings."
    :around #'org-latex-plain-text
    (let ((output (funcall orig-fn text info)))
      (when (plist-get info :with-special-strings)
        (setq output (org-latex-convert-extra-special-strings output)))
      output))
  (setq org-latex-text-markup-alist
        '((bold . "\\textbf{%s}")
          (code . protectedtexttt)
          (italic . "\\emph{%s}")
          (strike-through . "\\sout{%s}")
          (underline . "\\uline{%s}")
          (verbatim . verb)))
  (setq org-required-latex-packages
        '("adjustbox" "amsmath" "booktabs" "cancel" "capt-of" "caption"
  	"cleveref" "embedall" "float" "fontenc" "fvextra" "graphicx"
  	"hanging" "hyperref" "inputenc" "longtable" "mathalpha"
  	"mathtools" "microtype" "pdfx" "pifont" "preview" "scrbase"
  	"siunitx" "soul" "subcaption" "svg" "tikz" "tcolorbox"
  	"textcomp" "xcolor" "xparse" "xcoffins" "Alegreya" "arev"
  	"biolinum" "FiraMono" "FiraSans" "fourier" "gillius" "kpfonts"
  	"libertine" "newpxmath" "newpxtext" "newtxmath" "newtxtext"
  	"newtxsf" "noto" "plex-mono" "plex-sans" "plex-serif"
  	"sourcecodepro" "sourcesanspro" "sourceserifpro"))
  (defun check-for-latex-packages (packages)
    (delq nil
  	(mapcar
  	 (lambda (package)
  	   (unless
  	       (= 0
  		  (call-process "kpsewhich" nil nil nil
  				(concat package ".sty")))
  	     package))
  	 packages)))
  (defun +org-warn-about-missing-latex-packages (&rest _)
    (message "Checking for missing LaTeX packages...") (sleep-for 0.4)
    (if-let
        (missing-pkgs
         (check-for-latex-packages org-required-latex-packages))
        (message "%s You are missing the following LaTeX packages: %s."
  	       (propertize "Warning!" 'face '(bold warning))
  	       (mapconcat
  		(lambda (pkg)
  		  (propertize pkg 'face 'font-lock-variable-name-face))
  		missing-pkgs ", "))
      (message
       "%s You have all the required LaTeX packages. Run %s to make this message go away."
       (propertize "Success!" 'face '(bold success))
       (propertize "doom sync" 'face 'font-lock-keyword-face))
      (advice-remove 'org-latex-export-to-pdf
  		   #'+org-warn-about-missing-latex-packages))
    (sleep-for 1))
  (advice-add 'org-latex-export-to-pdf :before
  	    #'+org-warn-about-missing-latex-packages)
  
  )

(after! ox-latex
  (defvar org-latex-emoji--rx
    (let (emojis)
      (map-char-table
       (lambda (char set)
         (when (eq set 'emoji)
           (push (copy-tree char) emojis)))
       char-script-table)
      (rx-to-string `(any ,@emojis)))
    "A regexp to find all emoji-script characters.")
  (defconst org-latex-emoji-base-dir
    (expand-file-name "emojis/" doom-cache-dir)
    "Directory where emojis should be saved and look for.")
  
  (defvar org-latex-emoji-sets
    '(("twemoji" :url "https://github.com/twitter/twemoji/archive/refs/tags/v14.0.2.zip"
       :folder "twemoji-14.0.2/assets/svg" :height "1.8ex" :offset "-0.3ex")
      ("twemoji-bw" :url "https://github.com/youdly/twemoji-color-font/archive/refs/heads/v11-release.zip"
       :folder "twemoji-color-font-11-release/assets/builds/svg-bw" :height "1.8ex" :offset "-0.3ex")
      ("openmoji" :url "https://github.com/hfg-gmuend/openmoji/releases/latest/download/openmoji-svg-color.zip"
       :height "2.2ex" :offset "-0.45ex")
      ("openmoji-bw" :url "https://github.com/hfg-gmuend/openmoji/releases/latest/download/openmoji-svg-black.zip"
       :height "2.2ex" :offset "-0.45ex")
      ("emojione" :url "https://github.com/joypixels/emojione/archive/refs/tags/v2.2.7.zip"
       :folder "emojione-2.2.7/assets/svg") ; Warning, poor coverage
      ("noto" :url "https://github.com/googlefonts/noto-emoji/archive/refs/tags/v2.038.zip"
       :folder "noto-emoji-2.038/svg" :file-regexp "^emoji_u\\([0-9a-f_]+\\)"
       :height "2.0ex" :offset "-0.3ex"))
    "An alist of plistst of emoji sets.
  Specified with the minimal form:
    (\"SET-NAME\" :url \"URL\")
  The following optional parameters are supported:
    :folder (defaults to \"\")
    The folder within the archive where the emojis exist.
    :file-regexp (defaults to nil)
    Pattern with the emoji code point as the first capture group.
    :height (defaults to \"1.8ex\")
    Height of the emojis to be used.
    :offset (defaults to \"-0.3ex\")
    Baseline offset of the emojis.")
  
  (defconst org-latex-emoji-keyword
    "LATEX_EMOJI_SET"
    "Keyword used to set the emoji set from `org-latex-emoji-sets'.")
  
  (defvar org-latex-emoji-preamble "\\usepackage{accsupp}
  \\usepackage{transparent}
  \\newsavebox\\emojibox
  
  \\NewDocumentCommand\\DeclareEmoji{m m}{% UTF-8 codepoint, UTF-16 codepoint
    \\DeclareUnicodeCharacter{#1}{%
      \\sbox\\emojibox{\\raisebox{OFFSET}{%
          \\includegraphics[height=HEIGHT]{EMOJI-FOLDER/#1}}}%
      \\usebox\\emojibox
      \\llap{%
        \\resizebox{\\wd\\emojibox}{\\height}{%
          \\BeginAccSupp{method=hex,unicode,ActualText=#2}%
          \\texttransparent{0}{X}%
          \\EndAccSupp{}}}}}"
    "LaTeX preamble snippet that will allow for emojis to be declared.
  Contains the string \"EMOJI-FOLDER\" which should be replaced with
  the path to the emoji folder.")
  
  (defun org-latex-emoji-utf16 (char)
    "Return the pair of UTF-16 surrogates that represent CHAR."
    (list
     (+ #xD7C0 (ash char -10))
     (+ #xDC00 (logand char #x03FF))))
  
  (defun org-latex-emoji-declaration (char)
    "Construct the LaTeX command declaring CHAR as an emoji."
    (format "\\DeclareEmoji{%X}{%s} %% %s"
            char
            (if (< char #xFFFF)
                (format "%X" char)
              (apply #'format "%X%X" (org-latex-emoji-utf16 char)))
            (capitalize (get-char-code-property char 'name))))
  
  (defun org-latex-emoji-fill-preamble (emoji-folder &optional height offset svg-p)
    "Fill in `org-latex-emoji-preamble' with EMOJI-FOLDER, HEIGHT, and OFFSET.
  If SVG-P is set \"includegraphics\" will be replaced with \"includesvg\"."
    (let* (case-fold-search
           (filled-preamble
            (replace-regexp-in-string
             "HEIGHT"
             (or height "1.8ex")
             (replace-regexp-in-string
              "OFFSET"
              (or offset "-0.3ex")
              (replace-regexp-in-string
               "EMOJI-FOLDER"
               (directory-file-name
                (if (getenv "HOME")
                    (replace-regexp-in-string
                     (regexp-quote (getenv "HOME"))
                     "\\string~"
                     emoji-folder t t)
                  emoji-folder))
               org-latex-emoji-preamble t t)
              t t)
             t t)))
      (if svg-p
          (replace-regexp-in-string
           "includegraphics" "includesvg"
           filled-preamble t t)
        filled-preamble)))
  
  (defun org-latex-emoji-setup (&optional info)
    "Construct a preamble snippet to set up emojis based on INFO."
    (let* ((emoji-set
            (or (org-element-map
                    (plist-get info :parse-tree)
                    'keyword
                  (lambda (keyword)
                    (and (string= (org-element-property :key keyword)
                                  org-latex-emoji-keyword)
                         (org-element-property :value keyword)))
                  info t)
                (caar org-latex-emoji-sets)))
           (emoji-spec (cdr (assoc emoji-set org-latex-emoji-sets)))
           (emoji-folder
            (expand-file-name emoji-set org-latex-emoji-base-dir))
           (emoji-svg-only
            (and (file-exists-p emoji-folder)
                 (not (cl-some
                       (lambda (path)
                         (not (string= (file-name-extension path) "svg")))
                       (directory-files emoji-folder nil "\\....$"))))))
      (cond
       ((not emoji-spec)
        (error "Emoji set `%s' is unknown. Try one of: %s" emoji-set
               (string-join (mapcar #'car org-latex-emoji-sets) ", ")))
       ((not (file-exists-p emoji-folder))
        (if (and (not noninteractive)
                 (yes-or-no-p (format "Emoji set `%s' is not installed, would you like to install it?" emoji-set)))
            (org-latex-emoji-install
             emoji-set
             (or (executable-find "cairosvg") (executable-find "inkscape")))
          (error "Emoji set `%s' is not installed" emoji-set))))
      (concat
       (org-latex-emoji-fill-preamble
        emoji-folder (plist-get emoji-spec :height)
        (plist-get emoji-spec :offset) emoji-svg-only)
       "\n\n"
       (mapconcat
        #'org-latex-emoji-declaration
        (let (unicode-cars)
          (save-excursion
            (goto-char (point-min))
            (while (re-search-forward org-latex-emoji--rx nil t)
              (push (aref (match-string 0) 0) unicode-cars)))
          (cl-delete-duplicates unicode-cars))
        "\n")
       "\n")))
  
  ;; (org-export-update-features 'latex
  ;;   (emoji
  ;;    :condition (save-excursion
  ;;                 (goto-char (point-min))
  ;;                 (re-search-forward org-latex-emoji--rx nil t))
  ;;    :requires image
  ;;    :snippet org-latex-emoji-setup
  ;;    :order 3))
  ;; (org-export-update-features 'latex
  ;;   (emoji-lualatex-hack
  ;;    :condition t
  ;;    :when (emoji julia-code) ; LuaLaTeX is used with julia-code.
  ;;    :snippet
  ;;    "\\usepackage{newunicodechar}
  ;; \\newcommand{\\DeclareUnicodeCharacter}[2]{%
  ;;     \\begingroup\\lccode`|=\\string\"#1\\relax
  ;;     \\lowercase{\\endgroup\\newunicodechar{|}}{#2}}"
  ;;    :order 2.9))
  (defun org-latex-emoji-install (set &optional convert)
    "Dowload, convert, and install emojis for use with LaTeX."
    (interactive
     (list (completing-read "Emoji set to install: "
                            (mapcar
                             (lambda (set-spec)
                               (if (file-exists-p (expand-file-name (car set-spec) org-latex-emoji-base-dir))
                                   (propertize (car set-spec) 'face 'font-lock-doc-face)
                                 (car set-spec)))
                             org-latex-emoji-sets)
                            nil t)
           (if (or (executable-find "cairosvg") (executable-find "inkscape"))
               (yes-or-no-p "Would you like to create .pdf forms of the Emojis (strongly recommended)?")
             (message "Install `cairosvg' (recommended) or `inkscape' to convert to PDF forms")
             nil)))
    (let ((emoji-folder (expand-file-name set org-latex-emoji-base-dir)))
      (when (or (not (file-exists-p emoji-folder))
                (and (not noninteractive)
                     (yes-or-no-p "Emoji folder already present, would you like to re-download?")
                     (progn (delete-directory emoji-folder) t)))
        (let* ((spec (cdr (assoc set org-latex-emoji-sets)))
               (dir (org-latex-emoji-install--download set (plist-get spec :url)))
               (svg-dir (expand-file-name (or (plist-get spec :folder) "") dir)))
          (org-latex-emoji-install--install
           set svg-dir (plist-get spec :file-regexp))))
      (when convert
        (org-latex-emoji-install--convert (file-name-as-directory emoji-folder))))
    (message "Emojis set `%s' installed." set))
  
  (defun org-latex-emoji-install--download (name url)
    "Download the emoji archive URL for the set NAME."
    (let* ((dest-folder (make-temp-file (format "%s-" name) t)))
      (message "Downloading %s..." name)
      (let ((default-directory dest-folder))
        (call-process "curl" nil nil nil "-sL" url "--output" "emojis.zip")
        (message "Unzipping")
        (call-process "unzip" nil nil nil "emojis.zip")
        dest-folder)))
  
  (defun org-latex-emoji-install--install (name dir &optional filename-regexp)
    "Install the emoji files in DIR to the NAME set folder.
  If a FILENAME-REGEXP, only files matching this regexp will be moved,
  and they will be renamed to the first capture group of the regexp."
    (message "Installing %s emojis into emoji directory" name)
    (let ((images (append (directory-files dir t ".*.svg")
                          (directory-files dir t ".*.pdf")))
          (emoji-dir (file-name-as-directory
                      (expand-file-name name org-latex-emoji-base-dir))))
      (unless (file-exists-p emoji-dir)
        (make-directory emoji-dir t))
      (mapc
       (lambda (image)
         (if filename-regexp
             (when (string-match filename-regexp (file-name-nondirectory image))
               (rename-file image
                            (expand-file-name
                             (file-name-with-extension
                              (upcase (match-string 1 (file-name-nondirectory image)))
                              (file-name-extension image))
                             emoji-dir)
                            t))
           (rename-file image
                        (expand-file-name
                         (file-name-with-extension
                          (upcase (file-name-nondirectory image))
                          (file-name-extension image))
                         emoji-dir)
                        t)))
       images)
      (message "%d emojis installed" (length images))))
  
  (defun org-latex-emoji-install--convert (dir)
    "Convert all .svg files in DIR to .pdf forms.
  Uses cairosvg if possible, falling back to inkscape."
    (let ((default-directory dir))
      (if (executable-find "cairosvg") ; cairo's PDFs are ~10% smaller
          (let* ((images (directory-files dir nil ".*.svg"))
                 (num-images (length images))
                 (index 0)
                 (max-threads (1- (string-to-number (shell-command-to-string "nproc"))))
                 (threads 0))
            (while (< index num-images)
              (setf threads (1+ threads))
              (let (message-log-max)
                (message "Converting emoji %d/%d (%s)" (1+ index) num-images (nth index images)))
              (make-process :name "cairosvg"
                            :command (list "cairosvg" (nth index images) "-o" (concat (file-name-sans-extension (nth index images)) ".pdf"))
                            :sentinel (lambda (proc msg)
                                        (when (memq (process-status proc) '(exit signal))
                                          (setf threads (1- threads)))))
              (setq index (1+ index))
              (while (> threads max-threads)
                (sleep-for 0.01)))
            (while (> threads 0)
              (sleep-for 0.01)))
        (message "Cairosvg not found. Proceeding with inkscape as a fallback.")
        (shell-command "inkscape --batch-process --export-type='pdf' *.svg"))
      (message "Finished conversion!"))))

(use-package! ox-chameleon
  :after ox)

(after! ox-beamer
  (setq org-beamer-theme "[progressbar=foot]metropolis")
  (defun org-beamer-p (info)
    (eq 'beamer (and (plist-get info :back-end)
                     (org-export-backend-name (plist-get info :back-end)))))
  
  ;; (org-export-update-features 'beamer
  ;;   (beamer-setup
  ;;    :condition t
  ;;    :requires .missing-koma
  ;;    :prevents (italic-quotes condensed-lists cover-page)))
  
  ;; (org-export-update-features 'latex
  ;;   (.missing-koma
  ;;    :snippet "\\usepackage{scrextend}"
  ;;    :order 2))
  
  (defvar org-beamer-metropolis-tweaks
    "\\NewCommandCopy{\\moldusetheme}{\\usetheme}
  \\renewcommand*{\\usetheme}[2][]{\\moldusetheme[#1]{#2}
    \\setbeamertemplate{items}{$\\bullet$}
    \\setbeamerfont{block title}{size=\\normalsize, series=\\bfseries\\parbox{0pt}{\\rule{0pt}{4ex}}}}
  
  \\makeatletter
  \\newcommand{\\setmetropolislinewidth}{
    \\setlength{\\metropolis@progressinheadfoot@linewidth}{1.2px}}
  \\makeatother
  
  \\usepackage{etoolbox}
  \\AtEndPreamble{\\setmetropolislinewidth}"
    "LaTeX preamble snippet that tweaks the Beamer metropolis theme styling.")
  
  ;; (org-export-update-features 'beamer
  ;;   (beamer-metropolis
  ;;    :condition (string-match-p "metropolis$" (plist-get info :beamer-theme))
  ;;    :snippet org-beamer-metropolis-tweaks
  ;;    :order 3))
  (setq org-beamer-frame-level 2))

(after! ox-re-reveal
  (setq org-re-reveal-theme "white"
        org-re-reveal-transition "slide"
        org-re-reveal-plugins '(markdown notes math search zoom)))

(after! ox-ascii
  (setq org-ascii-charset 'utf-8)
  (when (executable-find "latex2text")
    (after! ox-ascii
      (defvar org-ascii-convert-latex t
        "Use latex2text to convert LaTeX elements to unicode.")
  
      (defadvice! org-ascii-latex-environment-unicode-a (latex-environment _contents info)
        "Transcode a LATEX-ENVIRONMENT element from Org to ASCII, converting to unicode.
  CONTENTS is nil.  INFO is a plist holding contextual
  information."
        :override #'org-ascii-latex-environment
        (when (plist-get info :with-latex)
          (org-ascii--justify-element
           (org-remove-indentation
            (let* ((latex (org-element-property :value latex-environment))
                   (unicode (and (eq (plist-get info :ascii-charset) 'utf-8)
                                 org-ascii-convert-latex
                                 (doom-call-process "latex2text" "-q" "--code" latex))))
              (if (= (car unicode) 0) ; utf-8 set, and sucessfully ran latex2text
                  (cdr unicode) latex)))
           latex-environment info)))
  
      (defadvice! org-ascii-latex-fragment-unicode-a (latex-fragment _contents info)
        "Transcode a LATEX-FRAGMENT object from Org to ASCII, converting to unicode.
  CONTENTS is nil.  INFO is a plist holding contextual
  information."
        :override #'org-ascii-latex-fragment
        (when (plist-get info :with-latex)
          (let* ((latex (org-element-property :value latex-fragment))
                 (unicode (and (eq (plist-get info :ascii-charset) 'utf-8)
                               org-ascii-convert-latex
                               (doom-call-process "latex2text" "-q" "--code" latex))))
            (if (and unicode (= (car unicode) 0)) ; utf-8 set, and sucessfully ran latex2text
                (cdr unicode) latex)))))))

(use-package! ox-gfm
  :after ox)

(defadvice! org-md-plain-text-unicode-a (orig-fn text info)
  "Locally rebind `org-html-special-string-regexps'"
  :around #'org-md-plain-text
  (let ((org-html-special-string-regexps
         '(("\\\\-" . "-")
           ("---\\([^-]\\|$\\)" . "—\\1")
           ("--\\([^-]\\|$\\)" . "–\\1")
           ("\\.\\.\\." . "…")
           ("<->" . "⟷")
           ("->" . "→")
           ("<-" . "←"))))
    (funcall orig-fn text (plist-put info :with-smart-quotes nil))))

(after! ox-md
  (defun org-md-latex-fragment (latex-fragment _contents info)
    "Transcode a LATEX-FRAGMENT object from Org to Markdown."
    (let ((frag (org-element-property :value latex-fragment)))
      (cond
       ((string-match-p "^\\\\(" frag)
        (concat "$" (substring frag 2 -2) "$"))
       ((string-match-p "^\\\\\\[" frag)
        (concat "$$" (substring frag 2 -2) "$$"))
       (t (message "unrecognised fragment: %s" frag)
          frag))))

  (defun org-md-latex-environment (latex-environment contents info)
    "Transcode a LATEX-ENVIRONMENT object from Org to Markdown."
    (concat "$$\n"
            (org-html-latex-environment latex-environment contents info)
            "$$\n"))

  (defun org-utf8-entity (entity _contents _info)
    "Transcode an ENTITY object from Org to utf-8.
CONTENTS are the definition itself.  INFO is a plist holding
contextual information."
    (org-element-property :utf-8 entity))

  ;; We can't let this be immediately parsed and evaluated,
  ;; because eager macro-expansion tries to call as-of-yet
  ;; undefined functions.
  ;; NOTE in the near future this shouldn't be required
  (eval
   '(dolist (extra-transcoder
             '((latex-fragment . org-md-latex-fragment)
               (latex-environment . org-md-latex-environment)
               (entity . org-utf8-entity)))
      (unless (member extra-transcoder (org-export-backend-transcoders
                                        (org-export-get-backend 'md)))
        (push extra-transcoder (org-export-backend-transcoders
                                (org-export-get-backend 'md)))))))

(add-transient-hook! #'org-babel-execute-src-block
  (require 'ob-async))

(defvar org-babel-auto-async-languages '()
  "Babel languages which should be executed asyncronously by default.")

(defadvice! org-babel-get-src-block-info-eager-async-a (orig-fn &optional light datum)
  "Eagarly add an :async parameter to the src information, unless it seems problematic.
This only acts o languages in `org-babel-auto-async-languages'.
Not added when either:
+ session is not \"none\"
+ :sync is set"
  :around #'org-babel-get-src-block-info
  (let ((result (funcall orig-fn light datum)))
    (when (and (string= "none" (cdr (assoc :session (caddr result))))
               (member (car result) org-babel-auto-async-languages)
               (not (assoc :async (caddr result))) ; don't duplicate
               (not (assoc :sync (caddr result))))
      (push '(:async) (caddr result)))
    result))

(setq ess-eval-visibly 'nowait)

(setq ess-R-font-lock-keywords
      '((ess-R-fl-keyword:keywords . t)
        (ess-R-fl-keyword:constants . t)
        (ess-R-fl-keyword:modifiers . t)
        (ess-R-fl-keyword:fun-defs . t)
        (ess-R-fl-keyword:assign-ops . t)
        (ess-R-fl-keyword:%op% . t)
        (ess-fl-keyword:fun-calls . t)
        (ess-fl-keyword:numbers . t)
        (ess-fl-keyword:operators . t)
        (ess-fl-keyword:delimiters . t)
        (ess-fl-keyword:= . t)
        (ess-R-fl-keyword:F&T . t)))

(after! org
  (add-to-list '+org-babel-mode-alist '(jags . ess-jags)))

;; (after! lsp-python-ms
;;   (set-lsp-priority! 'mspyls 1))

;; (use-package paper
;;   ;; :mode ("\\.pdf\\'"  . paper-mode)
;;   ;; :mode ("\\.epub\\'"  . paper-mode)
;;   :config
;;   (require 'evil-collection-paper)
;;   (evil-collection-paper-setup))

(after! ess-r-mode
  (appendq! +ligatures-extra-symbols
            '(:assign "⟵"
              :multiply "×"))
  (set-ligatures! 'ess-r-mode
    ;; Functional
    :def "function"
    ;; Types
    :null "NULL"
    :true "TRUE"
    :false "FALSE"
    :int "int"
    :floar "float"
    :bool "bool"
    ;; Flow
    :not "!"
    :and "&&" :or "||"
    :for "for"
    :in "%in%"
    :return "return"
    ;; Other
    :assign "<-"
    :multiply "%*%"))

(add-hook 'julia-mode-hook #'rainbow-delimiters-mode-enable)
(add-hook! 'julia-mode-hook
  (setq-local lsp-enable-folding t
              lsp-folding-range-limit 100))

(use-package! graphviz-dot-mode
  :commands graphviz-dot-mode
  :mode ("\\.dot\\'" . graphviz-dot-mode)
  :init
  (after! org
    (setcdr (assoc "dot" org-src-lang-modes)
            'graphviz-dot)))

(use-package! company-graphviz-dot
  :after graphviz-dot-mode)

(add-hook! (gfm-mode markdown-mode) #'visual-line-mode #'turn-off-auto-fill)

(custom-set-faces!
  '(markdown-header-face-1 :height 1.25 :weight extra-bold :inherit markdown-header-face)
  '(markdown-header-face-2 :height 1.15 :weight bold       :inherit markdown-header-face)
  '(markdown-header-face-3 :height 1.08 :weight bold       :inherit markdown-header-face)
  '(markdown-header-face-4 :height 1.00 :weight bold       :inherit markdown-header-face)
  '(markdown-header-face-5 :height 0.90 :weight bold       :inherit markdown-header-face)
  '(markdown-header-face-6 :height 0.75 :weight extra-bold :inherit markdown-header-face))

(use-package! beancount
  :mode ("\\.beancount\\'" . beancount-mode)
  :init
  (after! nerd-icons
    (add-to-list 'nerd-icons-extension-icon-alist
                 '("\\.beancount\\'"  "attach_money" :face nerd-icons-lblue))
    (add-to-list 'nerd-icons-mode-icon-alist
                 '(beancount-mode  "attach_money" :face nerd-icons-lblue)))
  :config
  (setq beancount-electric-currency t)
  (defun beancount-bal ()
    "Run bean-report bal."
    (interactive)
    (let ((compilation-read-command nil))
      (beancount--run "bean-report"
                      (file-relative-name buffer-file-name) "bal")))
  (map! :map beancount-mode-map
        :n "TAB" #'beancount-align-to-previous-number
        :i "RET" (cmd! (newline-and-indent) (beancount-align-to-previous-number))))

(define-derived-mode gimp-palette-mode fundamental-mode "GIMP Palette"
  "A major mode for GIMP Palette (.gpl) files that keeps RGB and Hex colors in sync."
  (when (require 'rainbow-mode)
    (rainbow-mode 1))
  (when (bound-and-true-p hl-line-mode)
    (hl-line-mode -1))
  (add-hook 'after-change-functions #'gimp-palette-update-region nil t))

(defun gimp-palette-update-region (beg end &optional _)
  "Update each line between BEG and END with `gimp-palette-update-line'.
If run interactively without a region set, the whole buffer is affected."
  (interactive
   (if (region-active-p)
       (list (region-beginning) (region-end))
     (list (point-min) (point-max))))
  (let ((marker (prepare-change-group)))
    (unwind-protect
        (save-excursion
          (goto-char beg)
          (while (< (point) end)
            (gimp-palette-update-line)
            (forward-line 1)))
      (undo-amalgamate-change-group marker))))

(defun gimp-palette-update-line ()
  "Update the RGB and Hex colour codes on the current line.
Whichever `point' is currently on is taken as the source of truth."
  (interactive)
  (let ((column (current-column))
        (ipoint (point)))
    (beginning-of-line)
    (when (and (re-search-forward "\\=\\([0-9 ]*\\)\\(#[0-9A-Fa-f]\\{6\\}\\)" nil t)
               (<= column (length (match-string 0))))
      (cond
       ((>= column (length (match-string 1))) ; Point in #HEX
        (cl-destructuring-bind (r g b) (color-name-to-rgb (match-string 2))
          (replace-match
           (format "%3d %3d %3d "
                   (round (* 255 r))
                   (round (* 255 g))
                   (round (* 255 b)))
           nil t nil 1)))
       ((string-match-p "\\`[0-9]+ +[0-9]+ +[0-9]+\\'" (match-string 1)) ; Valid R G B
        (cl-destructuring-bind (r g b)
            (mapcar #'string-to-number
                    (save-match-data
                      (split-string (match-string 1) " +" t)))
          (replace-match
           (format "%3d %3d %3d " r g b)
           nil t nil 1)
          (replace-match
           (color-rgb-to-hex (/ r 255.0) (/ g 255.0) (/ b 255.0) 2)
           nil t nil 2)))))
    (goto-char ipoint)))

(add-to-list 'magic-mode-alist (cons "\\`GIMP Palette\n" #'gimp-palette-mode))
