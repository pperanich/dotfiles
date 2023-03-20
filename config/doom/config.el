;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Preston Peranich"
      user-mail-address "pperanich@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; (setq doom-font (font-spec :family "Fira Mono" :size 12))
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'modus-vivendi)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
;; (setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
(setq doom-modeline-enable-word-count t)


(defun find-nix-path (name &optional relative)
  ;; Poll nix path-info to find dir of command installed
  (setq path (shell-command-to-string (concat "nix path-info nixpkgs#" name)))
  ;; Remove newline character at end of output
  (setq path (replace-regexp-in-string "\n$" "" path))
  (or relative (setq path (concat path relative)))
  )

(custom-set-variables '(conda-anaconda-home (expand-file-name "~/micromamba/envs/conda")))
(setq conda-env-home-directory (expand-file-name "~/micromamba/"))
;; (setq conda-env-subdirectory "envs")

;;; org
; inspired by protesilaos
(setq org-imenu-depth 7)
(setq org-directory (convert-standard-filename "~/Documents/org"))
(setq org-default-notes-file (thread-last org-directory (expand-file-name "notes.org")))
(setq org-agenda-files `(,org-directory "~/Documents"))
(setq org-roam-directory (concat org-directory "/roam"))
(setq org-roam-db-location (concat org-roam-directory "/db/org-roam.db"))

(after! org
        ;; general settings
        (setq org-adapt-indentation nil)
        (setq org-special-ctrl-a/e nil)
        (setq org-special-ctrl-k nil)
        (setq org-M-RET-may-split-line '((default . nil)))
        (setq org-hide-emphasis-markers nil)
        (setq org-hide-macro-markers nil)
        (setq org-hide-leading-stars nil)
        (setq org-cycle-separator-lines 0)
        (setq org-structure-template-alist
        '(("s" . "src")
                ("E" . "src emacs-lisp")
                ("e" . "example")
                ("q" . "quote")
                ("v" . "verse")
                ("V" . "verbatim")
                ("c" . "center")
                ("C" . "comment")))
        (setq org-catch-invisible-edits 'show)
        (setq org-return-follows-link nil)
        (setq org-loop-over-headlines-in-active-region 'start-level)
        (setq org-modules '(ol-info ol-eww))
        (setq org-use-sub-superscripts '{})
        (setq org-insert-heading-respect-content t)

        ;; refile, todo
        (setq org-refile-targets
        '((org-agenda-files . (:maxlevel . 2))
                (nil . (:maxlevel . 2))))
        (setq org-refile-use-outline-path t)
        (setq org-refile-allow-creating-parent-nodes 'confirm)
        (setq org-refile-use-cache t)
        (setq org-reverse-note-order nil)
        ;; (setq org-todo-keywords
        ;; '((sequence "TODO" "DOING" "BLOCKED" "REVIEW" "|" "DONE" "ARCHIVED")))
        ;; (setq org-todo-keyword-faces
        ;; '(("TODO" . "SlateGray")
        ;;         ("DOING" . "DarkOrchid")
        ;;         ("BLOCKED" . "Firebrick")
        ;;         ("REVIEW" . "Teal")
        ;;         ("DONE" . "ForestGreen")
        ;;         ("ARCHIVED" .  "SlateBlue")))
        (setq org-use-fast-todo-selection 'expert)
        (setq org-priority-faces
        '((?A . '(bold org-priority))
                (?B . org-priority)
                (?C . '(shadow org-priority))))
        (setq org-fontify-done-headline nil)
        (setq org-fontify-todo-headline nil)
        (setq org-fontify-quote-and-verse-blocks t)
        (setq org-fontify-whole-heading-line nil)
        (setq org-fontify-whole-block-delimiter-line t)
        (setq org-highlight-latex-and-related nil)
        (setq org-enforce-todo-dependencies t)
        (setq org-enforce-todo-checkbox-dependencies t)
        (setq org-track-ordered-property-with-tag t)
        (setq org-highest-priority ?A)
        (setq org-lowest-priority ?C)
        (setq org-default-priority ?A)

        ;; tags
        (setq org-tag-alist
        '(("meeting")
                ("admin")
                ("emacs")
                ("politics")
                ("economics")
                ("philosophy")
                ("book")
                ("essay")
                ("mail")
                ("purchase")
                ("hardware")
                ("software")
                ("website")))
        (setq org-auto-align-tags nil)
        (setq org-tags-column 0)

        ;; log
        (setq org-log-done 'time)
        (setq org-log-into-drawer t)
        (setq org-log-note-clock-out nil)
        (setq org-log-redeadline 'time)
        (setq org-log-reschedule 'time)
        (setq org-read-date-prefer-future 'time)

        ;; links
        (setq org-link-keep-stored-after-insertion nil)

        (setq-default visual-fill-column-center-text t)
        ;; code blocks
        (setq org-confirm-babel-evaluate nil)
        (setq org-src-window-setup 'current-window)
        (setq org-edit-src-persistent-message nil)
        (setq org-src-fontify-natively t)
        (setq org-src-preserve-indentation t)
        (setq org-src-tab-acts-natively t)
        (setq org-edit-src-content-indentation 0)

        ;; export
        (setq org-export-with-toc t)
        (setq org-export-headline-levels 8)
        (setq org-export-dispatch-use-expert-ui nil)
        (setq org-html-htmlize-output-type nil)
        (setq org-html-head-include-default-style nil)
        (setq org-html-head-include-scripts nil)

        ;; org-roam
        (setq org-enable-roam-support t)
        (setq org-roam-v2-ack t)
        (setq org-roam-dailies-capture-templates
        '(("d" "default" entry "* %?"
        :if-new (file+head "%<%Y-%m-%d>.org" "#+title: %<%Y-%m-%d (%A)>
        * tasks for today [/]
        - [ ]
        * journal
        "))))

        ;; org-modern
        (setq org-modern-label-border 1)
        (setq org-modern-variable-pitch nil)
        (setq org-modern-timestamp t)
        (setq org-modern-table t)
        (setq org-modern-table-vertical 1)
        (setq org-modern-table-horizontal 0)
        (setq org-modern-list
        '((?+ . "•")
                (?- . "–")
                (?* . "◦")))

        ;;; calendar
        ;; (setq calendar-mark-diary-entries-flag t)
        (setq calendar-mark-holidays-flag t)
        (setq calendar-mode-line-format nil)
        (setq calendar-time-display-form
        '(24-hours ":" minutes
                        (when time-zone
                        (format "(%s)" time-zone))))
        (setq calendar-week-start-day 1)      ; Monday
        (setq calendar-date-style 'iso)
        (setq calendar-date-display-form calendar-iso-date-display-form)
        (setq calendar-time-zone-style 'numeric)

        ;; org-babel langs
        (add-to-list
        'org-src-lang-modes '("plantuml" . plantuml))
        (add-to-list
        'org-src-lang-modes '("ipython" . ipython))
        ;; org-latex
        (setq org-latex-pdf-process '("LC_ALL=en_US.UTF-8 latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))
        (setq org-latex-src-block-backend 'engraved))


(add-hook! 'org-mode-hook #'org-modern-mode)
(add-hook! 'org-agenda-finalize-hook #'org-modern-agenda)

;; org-roam-bibtex
;; (use-package! org-roam-bibtex
;;   :after org-roam
;;   :hook (org-roam-mode . org-roam-bibtex-mode)
;;   :custom
;;   (orb-preformat-keywords '("citekey" "title" "url" "author-or-editor" "keywords" "file"))
;;   (orb-file-field-extensions '("pdf" "epub" "html")))

;; Basic agenda setup
(after! org-agenda
        (setq org-agenda-span 'week)
        (setq org-agenda-start-on-weekday 1)  ; Monday
        (setq org-agenda-confirm-kill t)
        (setq org-agenda-show-all-dates t)
        (setq org-agenda-show-outline-path nil)
        (setq org-agenda-window-setup 'current-window)
        (setq org-agenda-skip-comment-trees t)
        (setq org-agenda-menu-show-matcher t)
        (setq org-agenda-menu-two-columns nil)
        (setq org-agenda-sticky nil)
        (setq org-agenda-custom-commands-contexts nil)
        (setq org-agenda-max-entries nil)
        (setq org-agenda-max-todos nil)
        (setq org-agenda-max-tags nil)
        (setq org-agenda-max-effort nil)

        ;; Create reminders for tasks with a due date when this file is read.
        (run-at-time (* 60 5) nil #'org-agenda-to-appt)

        ;; General agenda view options
        (setq org-agenda-prefix-format
        '((agenda . " %i %-12:c%?-12t% s")
                (todo . " %i %-12:c")
                (tags . " %i %-12:c")
                (search . " %i %-12:c")))
        (setq org-agenda-sorting-strategy
        '(((agenda habit-down time-up priority-down category-keep)
                (todo priority-down category-keep)
                (tags priority-down category-keep)
                (search category-keep))))
        (setq org-agenda-breadcrumbs-separator "->")
        (setq org-agenda-todo-keyword-format "%-1s")
        (setq org-agenda-fontify-priorities 'cookies)
        (setq org-agenda-category-icon-alist nil)
        (setq org-agenda-remove-times-when-in-prefix nil)
        (setq org-agenda-remove-timeranges-from-blocks nil)
        (setq org-agenda-compact-blocks nil)
        (setq org-agenda-block-separator ?—)

        ;; Agenda marks
        (setq org-agenda-bulk-mark-char "#")
        (setq org-agenda-persistent-marks nil)

        ;; Agenda diary entries
        ;; (setq org-agenda-insert-diary-strategy 'date-tree)
        ;; (setq org-agenda-insert-diary-extract-time nil)
        ;; (setq org-agenda-include-diary nil)

        ;; Agenda follow mode
        (setq org-agenda-start-with-follow-mode nil)
        (setq org-agenda-follow-indirect t)

        ;; Agenda multi-item tasks
        (setq org-agenda-dim-blocked-tasks t)
        (setq org-agenda-todo-list-sublevels t)

        ;; Agenda filters and restricted views
        (setq org-agenda-persistent-filter nil)
        (setq org-agenda-restriction-lock-highlight-subtree t)

        ;; Agenda items with deadline and scheduled timestamps
        (setq org-agenda-include-deadlines t)
        (setq org-deadline-warning-days 5)
        (setq org-agenda-skip-scheduled-if-done nil)
        (setq org-agenda-skip-scheduled-if-deadline-is-shown t)
        (setq org-agenda-skip-timestamp-if-deadline-is-shown t)
        (setq org-agenda-skip-deadline-if-done nil)
        (setq org-agenda-skip-deadline-prewarning-if-scheduled 1)
        (setq org-agenda-skip-scheduled-delay-if-deadline nil)
        (setq org-agenda-skip-additional-timestamps-same-entry nil)
        (setq org-agenda-skip-timestamp-if-done nil)
        (setq org-agenda-search-headline-for-time nil)
        (setq org-scheduled-past-days 365)
        (setq org-deadline-past-days 365)
        (setq org-agenda-move-date-from-past-immediately-to-today t)
        (setq org-agenda-show-future-repeats t)
        (setq org-agenda-prefer-last-repeat nil)
        (setq org-agenda-timerange-leaders
        '("" "(%d/%d): "))
        (setq org-agenda-scheduled-leaders
        '("Scheduled: " "Sched.%2dx: "))
        (setq org-agenda-inactive-leader "[")
        (setq org-agenda-deadline-leaders
        '("Deadline:  " "In %3d d.: " "%2d d. ago: "))

        ;; Time grid
        (setq org-agenda-time-leading-zero t)
        (setq org-agenda-timegrid-use-ampm nil)
        (setq org-agenda-use-time-grid t)
        (setq org-agenda-show-current-time-in-grid t)
        (setq org-agenda-current-time-string
        (concat "Now " (make-string 70 ?-)))
        (setq org-agenda-time-grid
        '((daily today require-timed)
                (0600 0700 0800 0900 1000 1100
                1200 1300 1400 1500 1600
                1700 1800 1900 2000 2100)
                " ....." "-----------------"))
        (setq org-agenda-default-appointment-duration nil)

        ;; Agenda global to-do list
        (setq org-agenda-todo-ignore-with-date t)
        (setq org-agenda-todo-ignore-timestamp t)
        (setq org-agenda-todo-ignore-scheduled t)
        (setq org-agenda-todo-ignore-deadlines t)
        (setq org-agenda-todo-ignore-time-comparison-use-seconds t)
        (setq org-agenda-tags-todo-honor-ignore-options nil)

        ;; Agenda tagged items
        (setq org-agenda-show-inherited-tags t)
        (setq org-agenda-use-tag-inheritance
        '(todo search agenda))
        (setq org-agenda-hide-tags-regexp nil)
        (setq org-agenda-remove-tags nil)
        (setq org-agenda-tags-column -100)

        ;; Agenda entry
        (setq org-agenda-start-with-entry-text-mode nil)
        (setq org-agenda-entry-text-maxlines 5)
        (setq org-agenda-entry-text-exclude-regexps nil)
        (setq org-agenda-entry-text-leaders "    > ")

        ;; Agenda logging and clocking
        (setq org-agenda-log-mode-items '(closed clock))
        (setq org-agenda-clock-consistency-checks
        '((:max-duration "10:00" :min-duration 0 :max-gap "0:05" :gap-ok-around
                                ("4:00")
                                :default-face ; This should definitely be reviewed
                                ((:background "DarkRed")
                                (:foreground "white"))
                                :overlap-face nil :gap-face nil :no-end-time-face nil
                                :long-face nil :short-face nil)))
        (setq org-agenda-log-mode-add-notes t)
        (setq org-agenda-start-with-log-mode nil)
        (setq org-agenda-start-with-clockreport-mode nil)
        (setq org-agenda-clockreport-parameter-plist '(:link t :maxlevel 2))
        (setq org-agenda-search-view-always-boolean nil)
        (setq org-agenda-search-view-force-full-words nil)
        (setq org-agenda-search-view-max-outline-level 0)
        (setq org-agenda-search-headline-for-time t)
        (setq org-agenda-use-time-grid t)
        (setq org-agenda-cmp-user-defined nil)
        (setq org-agenda-sort-notime-is-late t) ; Org 9.4
        (setq org-agenda-sort-noeffort-is-high t) ; Org 9.4

        ;; Agenda column view
        (setq org-agenda-view-columns-initially nil)
        (setq org-agenda-columns-show-summaries t)
        (setq org-agenda-columns-compute-summary-properties t)
        (setq org-agenda-columns-add-appointments-to-effort-sum nil)
        (setq org-agenda-auto-exclude-function nil)
        (setq org-agenda-bulk-custom-functions nil)

        ;; Agenda habits
        (use-package! org-habit)
        (setq org-habit-graph-column 50)
        (setq org-habit-preceding-days 9))

(use-package! engrave-faces-latex
  :after ox-latex)
(setq org-latex-listings 'engraved)

;; org-file-apps
(setq org-file-apps
      '(("\\.pdf\\'" . emacs)))

;; org visual line mode
(add-hook! 'org-mode-hook #'visual-line-mode)

;; org-present
(use-package! hide-mode-line :after org)
(use-package! org-faces :after org)

(defun my/org-present-prepare-slide (buffer-name heading)
  ;; Show only top-level headlines
  (org-overview)
  ;; Unfold the current entry
  (org-show-entry)
  ;; Show only direct subheadings of the slide but don't expand them
  (org-show-children))
(defun my/org-present-start ()
  ;; Center the presentation and wrap lines
  (visual-fill-column-mode 1)
  (visual-line-mode 1)
  ;; Hide the mode line
  (hide-mode-line-mode 1)
  ;; Hide tidle fringe
  (spacemacs/toggle-vi-tilde-fringe-off)
  ;; (spacemacs/toggle-vim-empty-lines-mode-off)
  (org-present-big)
  (org-display-inline-images)
  (org-present-hide-cursor)
  (org-present-read-only))
(defun my/org-present-end ()
  ;; Stop centering the document
  (visual-fill-column-mode 0)
  (visual-line-mode 0)
  ;; Show the mode line again
  (hide-mode-line-mode 0)
  ;; Show tidle fringe
  (spacemacs/toggle-vi-tilde-fringe-on)
  (org-present-small)
  (org-remove-inline-images)
  (org-present-show-cursor)
  (org-present-read-write))

(add-hook! 'org-present-mode-hook 'my/org-present-start)
(add-hook! 'org-present-mode-quit-hook 'my/org-present-end)
(add-hook! 'org-present-after-navigate-functions 'my/org-present-prepare-slide)

;; org-noter and org-pdftools
;; (use-package! org-noter
;;   :config
;;   (require 'org-noter-pdftools))
;; ;; (use-package! org-pdftools
;; ;;   :hook (org-mode . org-pdftools-setup-link))
;; (use-package! org-noter-pdftools
;;   :after org-noter
;;   :config
;;   ;; Add a function to ensure precise note is inserted
;;   (defun org-noter-pdftools-insert-precise-note (&optional toggle-no-questions)
;;     (interactive "P")
;;     (org-noter--with-valid-session
;;      (let ((org-noter-insert-note-no-questions (if toggle-no-questions
;;                                                    (not org-noter-insert-note-no-questions)
;;                                                  org-noter-insert-note-no-questions))
;;            (org-pdftools-use-isearch-link t)
;;            (org-pdftools-use-freepointer-annot t))
;;        (org-noter-insert-note (org-noter--get-precise-info)))))
;;   ;; fix https://github.com/weirdNox/org-noter/pull/93/commits/f8349ae7575e599f375de1be6be2d0d5de4e6cbf
;;   (defun org-noter-set-start-location (&optional arg)
;;     "When opening a session with this document, go to the current location.
;; With a prefix ARG, remove start location."
;;     (interactive "P")
;;     (org-noter--with-valid-session
;;      (let ((inhibit-read-only t)
;;            (ast (org-noter--parse-root))
;;            (location (org-noter--doc-approx-location (when (called-interactively-p 'any) 'interactive))))
;;        (with-current-buffer (org-noter--session-notes-buffer session)
;;          (org-with-wide-buffer
;;           (goto-char (org-element-property :begin ast))
;;           (if arg
;;               (org-entry-delete nil org-noter-property-note-location)
;;             (org-entry-put nil org-noter-property-note-location
;;                            (org-noter--pretty-print-location location))))))))
;;   (with-eval-after-load 'pdf-annot
;;     (add-hook 'pdf-annot-activate-handler-functions #'org-noter-pdftools-jump-to-note)))

;;; elgantt
(use-package! elgantt
  :after org-mode)
;; (defun elgantt-open-current-org-file ()
;;   (setq elgantt-agenda-files (buffer-file-name))
;;   (elgantt-open))

;;; fonts
(use-package! fontaine)
;; This is defined in Emacs C code: it belongs to font settings.
(setq x-underline-at-descent-line t)

;; And this is for Emacs28.
(setq-default text-scale-remap-header-line t)

;;; Create XDG_CACHE_HOME dir for doom if it does not exist
(unless (file-exists-p (substitute-in-file-name "$XDG_CACHE_HOME/doom"))
  (make-directory (substitute-in-file-name "$XDG_CACHE_HOME/doom") t))
(setq fontaine-latest-state-file (substitute-in-file-name "$XDG_CACHE_HOME/doom/fontaine-latest-state.eld"))
(setq fontaine-presets
      '((tiny
          :default-family "Iosevka Nerd Font Mono"
          :default-height 120)
        (small
          :default-family "Iosevka Nerd Font Mono"
          :default-height 150)
        (regular
          :default-height 180)
        (medium
          :default-height 200)
        (large
          :default-weight semilight
          :default-height 220
          :bold-weight extrabold)
        (presentation
          :default-weight semilight
          :default-height 240
          :bold-weight extrabold)
        (jumbo
          :default-weight semilight
          :default-height 260
          :bold-weight extrabold)
        (t
          :default-family "Iosevka Nerd Font Mono"
          :default-weight regular
          :default-height 100
          :fixed-pitch-family nil ; falls back to :default-family
          :fixed-pitch-weight nil ; falls back to :default-weight
          :fixed-pitch-height 1.0
          :fixed-pitch-serif-family nil ; falls back to :default-family
          :fixed-pitch-serif-weight nil ; falls back to :default-weight
          :fixed-pitch-serif-height 1.0
          :variable-pitch-family "Iosevka Nerd Font"
          :variable-pitch-weight nil
          :variable-pitch-height 1.0
          :bold-family nil ; use whatever the underlying face has
          :bold-weight bold
          :italic-family nil
          :italic-slant italic
          :line-spacing nil)))

;; Add hook to update frame font.
(defun update-frame-font ()
  (set-frame-font (face-attribute 'default :font) nil t))
(add-hook! 'fontaine-set-preset-hook #'update-frame-font)
;; Set last preset or fall back to desired style from `fontaine-presets'.
(fontaine-set-preset (or (fontaine-restore-latest-preset) 'regular))

;; The other side of `fontaine-restore-latest-preset'.
(add-hook! 'kill-emacs-hook #'fontaine-store-latest-preset)

(define-key global-map (kbd "C-c f") #'fontaine-set-preset)
(define-key global-map (kbd "C-c F") #'fontaine-set-face-font)

;;; modus-theme configurations
(setq modus-themes-italic-constructs nil
      modus-themes-bold-constructs nil
      modus-themes-mixed-fonts t
      modus-themes-subtle-line-numbers t
      modus-themes-intense-mouseovers nil
      modus-themes-deuteranopia nil
      modus-themes-tabs-accented nil
      modus-themes-variable-pitch-ui t
      modus-themes-inhibit-reload t ; only applies to `customize-set-variable' and related

      modus-themes-fringes nil ; {nil,'subtle,'intense}

      ;; Options for `modus-themes-lang-checkers' are either nil (the
      ;; default), or a list of properties that may include any of those
      ;; symbols: `straight-underline', `text-also', `background',
      ;; `intense' OR `faint'.
      modus-themes-lang-checkers nil

      ;; Options for `modus-themes-mode-line' are either nil, or a list
      ;; that can combine any of `3d' OR `moody', `borderless',
      ;; `accented', a natural number for extra padding (or a cons cell
      ;; of padding and NATNUM), and a floating point for the height of
      ;; the text relative to the base font size (or a cons cell of
      ;; height and FLOAT)
      modus-themes-mode-line '(borderless (height 0.9) (padding 3))

      ;; Options for `modus-themes-markup' are either nil, or a list
      ;; that can combine any of `bold', `italic', `background',
      ;; `intense'.
      modus-themes-markup nil

      ;; Options for `modus-themes-syntax' are either nil (the default),
      ;; or a list of properties that may include any of those symbols:
      ;; `faint', `yellow-comments', `green-strings', `alt-syntax'
      modus-themes-syntax '(yellow-comments green-strings)

      ;; Options for `modus-themes-hl-line' are either nil (the default),
      ;; or a list of properties that may include any of those symbols:
      ;; `accented', `underline', `intense'
      modus-themes-hl-line nil

      ;; Options for `modus-themes-paren-match' are either nil (the
      ;; default), or a list of properties that may include any of those
      ;; symbols: `bold', `intense', `underline'
      modus-themes-paren-match '(bold)

      ;; Options for `modus-themes-links' are either nil (the default),
      ;; or a list of properties that may include any of those symbols:
      ;; `neutral-underline' OR `no-underline', `faint' OR `no-color',
      ;; `bold', `italic', `background'
      modus-themes-links '(neutral-underline)

      ;; Options for `modus-themes-box-buttons' are either nil (the
      ;; default), or a list that can combine any of `flat',
      ;; `accented', `faint', `variable-pitch', `underline',
      ;; `all-buttons', the symbol of any font weight as listed in
      ;; `modus-themes-weights', and a floating point number
      ;; (e.g. 0.9) for the height of the button's text.
      modus-themes-box-buttons nil

      ;; Options for `modus-themes-prompts' are either nil (the
      ;; default), or a list of properties that may include any of those
      ;; symbols: `background', `bold', `gray', `intense', `italic'
      modus-themes-prompts '(background intense)

      ;; The `modus-themes-completions' is an alist that reads three
      ;; keys: `matches', `selection', `popup'.  Each accepts a nil
      ;; value (or empty list) or a list of properties that can include
      ;; any of the following (for WEIGHT read further below):
      ;;
      ;; `matches' - `background', `intense', `underline', `italic', WEIGHT
      ;; `selection' - `accented', `intense', `underline', `italic', `text-also', WEIGHT
      ;; `popup' - same as `selected'
      ;; `t' - applies to any key not explicitly referenced (check docs)
      ;;
      ;; WEIGHT is a symbol such as `semibold', `light', or anything
      ;; covered in `modus-themes-weights'.  Bold is used in the absence
      ;; of an explicit WEIGHT.
      modus-themes-completions
      '((matches . (semibold))
        (selection . (extrabold accented))
        (popup . (extrabold accented)))

      modus-themes-mail-citations nil ; {nil,'intense,'faint,'monochrome}

      ;; Options for `modus-themes-region' are either nil (the default),
      ;; or a list of properties that may include any of those symbols:
      ;; `no-extend', `bg-only', `accented'
      modus-themes-region '(no-extend)

      ;; Options for `modus-themes-diffs': nil, 'desaturated, 'bg-only
      modus-themes-diffs 'desaturated

      modus-themes-org-blocks 'gray-background ; {nil,'gray-background,'tinted-background}

      modus-themes-org-agenda ; this is an alist: read the manual or its doc string
      '((header-block . (variable-pitch light 1.6))
        (header-date . (underline-today grayscale workaholic 1.2))
        (event . (accented italic varied))
        (scheduled . rainbow)
        (habit . simplified))

      ;; The `modus-themes-headings' is an alist with lots of possible
      ;; combinations, including per-heading-level tweaks: read the
      ;; manual or its doc string.
      modus-themes-headings
      '((0 . (variable-pitch light (height 2.2)))
        (1 . (rainbow variable-pitch light (height 1.6)))
        (2 . (rainbow variable-pitch light (height 1.4)))
        (3 . (rainbow variable-pitch regular (height 1.3)))
        (4 . (rainbow regular (height 1.2)))
        (5 . (rainbow (height 1.1)))
        (t . (variable-pitch extrabold))))
;; Add a hook to set font on theme reload
;; Load the theme files before enabling a theme (else you get an error).
(modus-themes-load-themes)
;; Set theme based on what is set in .spacemacs
(let ((theme (nth 0 doom-themes)))
  (cond ((eq theme 'modus-vivendi) (modus-themes-load-vivendi))
        ((eq theme 'modus-operandi) (modus-themes-load-operandi))))

(defun my-modus-themes-toggle ()
  "Toggle between `modus-operandi' and `modus-vivendi' themes.
This uses `enable-theme' instead of the standard method of
`load-theme'.  The technicalities are covered in the Modus themes
manual."
  (interactive)
  (pcase (modus-themes--current-theme)
    ('modus-operandi (progn (enable-theme 'modus-vivendi)
                            (disable-theme 'modus-operandi)))
    ('modus-vivendi (progn (enable-theme 'modus-operandi)
                           (disable-theme 'modus-vivendi)))
    (_ (error "No Modus theme is loaded; evaluate `modus-themes-load-themes' first"))))
(define-key global-map (kbd "<f5>") #'modus-themes-toggle)

;;; unicode-fonts
(setq unicode-fonts-enable-ligatures t)
(setq unicode-fonts-force-multi-color-on-mac t)


;; (defun my-modus-themes-custom-faces ()
  ;; (message "In custom hook"))
  ;; (set-face-attribute 'default nil :color (modus-themes-color 'blue))
  ;; (set-face-attribute 'font-lock-type-face nil :foreground (modus-themes-color 'magenta-alt)))
;; (add-hook 'modus-themes-after-load-theme-hook #'my-modus-themes-custom-faces)

;;; Latex configuration
(setq exec-path (append exec-path '("/Library/TeX/texbin")))
(setq exec-path (append exec-path '("/opt/local/bin")))
(setq org-latex-create-formula-image-program 'dvipng)
(setq org-format-latex-options (plist-put org-format-latex-options :scale 2.0))

;;; Paradox GitHub token
(setq paradox-github-token "ghp_REDACTED_GITHUB_TOKEN_XXX")

;;; Sync org files to github.
(defun sync-org-directory-to-github ()
  (interactive)
  (let ((default-directory org-directory))
    (async-shell-command
      (format "git add *.org roam/*.org roam/daily/*.org && git commit -m 'org directory auto-commit script @ %s' && git pull --rebase origin main && git push origin main"
              (format-time-string "%FT%T%z")))))

;;; Fix for lsp-ui-sideline wrapping.
;; (eval-after-load 'lsp-ui-sideline
;;   '(progn
;;       (defun lsp-ui-sideline--align (&rest lengths)
;;         "Align sideline string by LENGTHS from the right of the window."
;;         (cons (+ (apply '+ lengths)
;;                 (if (display-graphic-p) 1 2))
;;               'width))))

;;; Convert ipynb to readable format via pandoc.
(setq code-cells-convert-ipynb-style '(("pandoc" "--to" "ipynb" "--from" "org")
                                        ("pandoc" "--to" "org" "--from" "ipynb")
                                        org-mode))

;;; Utility to remove file watchers.
(defun file-notify-rm-all-watches ()
  "Remove all existing file notification watches from Emacs."
  (interactive)
  (maphash
    (lambda (key _value)
      (file-notify-rm-watch key))
    file-notify-descriptors))

;;; Clipetty setup
(use-package! clipetty
  :ensure t
  :hook (after-init . global-clipetty-mode))

;;; Set DAP-python debugger to pydebug
(after! python-mode
  (setq dap-python-debugger 'debugpy)
  )

;;; Set ssh-controlmaster options to improve TRAMP.
(setq tramp-ssh-controlmaster-options
      "-o ControlMaster=auto -o ControlPath='tramp.%%C' -o ControlPersist=yes")

;;; Make sure gt/gT can be used to switch between workspaces.
;; (with-eval-after-load 'evil-maps
;;   (when (featurep 'tab-bar)
;;     (define-key evil-normal-state-map "gt" nil)
;;     (define-key evil-normal-state-map "gT" nil)))

;;; Scrolling setup
(setq pixel-scroll-precision-large-scroll-height 40.0)
(setq pixel-scroll-precision-interpolation-factor 30)
;; scroll one line at a time (less "jumpy" than defaults)
(setq mouse-wheel-scroll-amount '(1 ((shift) . 1))) ;; one line at a time
(setq mouse-wheel-progressive-speed nil) ;; don't accelerate scrolling
(setq mouse-wheel-follow-mouse 't) ;; scroll window under mouse
(setq scroll-step 1) ;; keyboard scroll one line at a time'))

;;; QPDF setup
(use-package! qpdf.el)
(defun qpdf-delete-current-page ()
  "Delete the current page of pdf file."
  (interactive)
  (unless (or (equal major-mode 'doc-view-mode)
	            (equal major-mode 'pdf-view-mode))
    (error "Buffer should visit a pdf file in doc-view-mode or pdf-view-mode."))
  (qpdf-run (list
	           (concat "--pages="
		                 (qpdf--read-pages-with-presets nil nil nil
                                                    'except-current))
	           (concat "--infile="
		                 (buffer-file-name))
	           "--replace-input")))

(defun qpdf-rotate-current-page ()
  "Delete the current page of pdf file."
  (interactive)
  (unless (or (equal major-mode 'doc-view-mode)
              (equal major-mode 'pdf-view-mode))
    (error "Buffer should visit a pdf file in doc-view-mode or pdf-view-mode."))
  (qpdf-run (list
             (concat "--infile="
                     (buffer-file-name))
             "--replace-input"
             (concat "--rotate=+90:"
                     (number-to-string (image-mode-window-get 'page)))
             )))

;;; keycast mode
(use-package! keycast
  :commands keycast-mode
  :config
  (define-minor-mode keycast-mode
    "Show current command and its key binding in the mode line."
    :global t
    (if keycast-mode
        (progn
          (add-hook 'pre-command-hook 'keycast--update t)
          (add-to-list 'global-mode-string '("" keycast-mode-line " ")))
      (remove-hook 'pre-command-hook 'keycast--update)
      (setq global-mode-string (remove '("" keycast-mode-line " ") global-mode-string)))))

;;; info-variable-pitch
(add-hook! 'Info-mode-hook #'info-variable-pitch-mode)


;; (require 'tree-sitter)
;; (require 'tree-sitter-hl)
;; (require 'tree-sitter-langs)
;; (require 'tree-sitter-debug)
;; (require 'tree-sitter-query)
