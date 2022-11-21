;;; Set ssh-controlmaster options to improve TRAMP.
(setq tramp-ssh-controlmaster-options
      "-o ControlMaster=auto -o ControlPath='tramp.%%C' -o ControlPersist=yes")

;;; Make sure gt/gT can be used to switch between workspaces.
(with-eval-after-load 'evil-maps
  (when (featurep 'tab-bar)
    (define-key evil-normal-state-map "gt" nil)
    (define-key evil-normal-state-map "gT" nil)))

;;; Disable Babel execute confirm prompt
(require 'org)
(setq org-confirm-babel-evaluate nil)

;;; Improve icons for org mode check boxes
(add-hook 'org-mode-hook (lambda ()
                            "Beautify Org Checkbox Symbol"
                            (push '("[ ]" . "☐") prettify-symbols-alist)
                            (push '("[X]" . "☑" ) prettify-symbols-alist)
                            (push '("[-]" . "❍" ) prettify-symbols-alist)
                            (prettify-symbols-mode)))
(defface org-checkbox-done-text
  '((t (:foreground "#71696A")))
  "Face for the text part of a checked org-mode checkbox.")

;;; Latex configuration
(setq exec-path (append exec-path '("/Library/TeX/texbin")))
(setq exec-path (append exec-path '("/opt/local/bin")))
(setq org-latex-create-formula-image-program 'dvipng)
(setq org-format-latex-options (plist-put org-format-latex-options :scale 2.0))

;;; Paradox GitHub token
(setq paradox-github-token "ghp_REDACTED_GITHUB_TOKEN_XXX")

;;; Org TODO keywords
(with-eval-after-load 'org
  (setq org-todo-keywords
        '((sequence "TODO" "DOING" "BLOCKED" "REVIEW" "|" "DONE" "ARCHIVED")))
  (setq org-log-done 'time)
  (setq org-todo-keyword-faces
        '(("TODO" . "SlateGray")
          ("DOING" . "DarkOrchid")
          ("BLOCKED" . "Firebrick")
          ("REVIEW" . "Teal")
          ("DONE" . "ForestGreen")
          ("ARCHIVED" .  "SlateBlue"))))

;;; Add PlantUML to Org Babel src langs
(add-to-list
  'org-src-lang-modes '("plantuml" . plantuml))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Org Present ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load the hide-mode-line package for presentation mode.
(use-package hide-mode-line)
;; Load org-faces to make sure we can set appropriate faces
(require 'org-faces)

;; Center by default for visual fill column
(setq-default visual-fill-column-center-text t)

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
  ;; (spacemacs/toggle-vim-empty-lines-mode-on)

  (org-present-small)
  (org-remove-inline-images)
  (org-present-show-cursor)
  (org-present-read-write))

;; Register hooks with org-present
(with-eval-after-load 'org-present
  (add-hook 'org-present-mode-hook 'my/org-present-start)
  (add-hook 'org-present-mode-quit-hook 'my/org-present-end)
  (add-hook 'org-present-after-navigate-functions 'my/org-present-prepare-slide))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Org tools ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Org-roam and bibtex setup.
(use-package org-roam-bibtex
  :after org-roam
  :hook (org-roam-mode . org-roam-bibtex-mode)
  :custom
  (orb-preformat-keywords '("citekey" "title" "url" "author-or-editor" "keywords" "file"))
  (orb-file-field-extensions '("pdf" "epub" "html")))

(use-package org-pdftools
  :hook (org-load . org-pdftools-setup-link))

(use-package org-noter
  :after (:any org pdf-view)
  :custom
  (org-noter-always-create-frame nil)
  (org-noter-separate-notes-from-heading t)
  (org-noter-default-notes-file-names '("notes.org"))
  (org-noter-notes-search-path (list org-roam-directory)))

(use-package org-noter-pdftools
  :after org-noter
  :config
  (with-eval-after-load 'pdf-annot
    (add-hook 'pdf-annot-activate-handler-functions #'org-noter-pdftools-jump-to-note)))

(spacemacs/set-leader-keys "od" 'org-roam-dailies-goto-today)

;;; Sync org files to github.
(defun sync-org-directory-to-github ()
  (interactive)
  (let ((default-directory org-directory))
    (async-shell-command
      (format "git add *.org roam/*.org roam/daily/*.org && git commit -m 'org directory auto-commit script @ %s' && git pull --rebase origin main && git push origin main"
              (format-time-string "%FT%T%z")))))

;;; Fix for lsp-ui-sideline wrapping.
(eval-after-load 'lsp-ui-sideline
  '(progn
      (defun lsp-ui-sideline--align (&rest lengths)
        "Align sideline string by LENGTHS from the right of the window."
        (cons (+ (apply '+ lengths)
                (if (display-graphic-p) 1 2))
              'width))))

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

;;; Setup org pandoc latex export.
(setq org-src-fontify-natively t)
(add-to-list 'org-latex-packages-alist '("" "minted"))
(setq org-latex-listings 'minted)
(setq org-pandoc-options-for-latex-pdf '((pdf-engine . "pdflatex")
                                          (pdf-engine-opt . "-shell-escape:-output-directory=/tmp")
                                          (lua-filter . "minted.lua")
                                          (no-highlight)))

;;; Key-bindings for multi-vterm
(use-package multi-vterm
  :config
  (define-key vterm-mode-map [return]                      #'vterm-send-return)

  (setq vterm-keymap-exceptions nil)
  (evil-define-key 'insert vterm-mode-map (kbd "C-e")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-f")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-a")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-v")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-b")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-w")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-u")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-d")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-n")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-m")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-p")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-j")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-k")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-r")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-t")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-g")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-c")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-SPC")    #'vterm--self-insert)
  (evil-define-key 'normal vterm-mode-map (kbd "C-d")      #'vterm--self-insert)
  (evil-define-key 'normal vterm-mode-map (kbd ",c")       #'multi-vterm)
  (evil-define-key 'normal vterm-mode-map (kbd ",n")       #'multi-vterm-next)
  (evil-define-key 'normal vterm-mode-map (kbd ",p")       #'multi-vterm-prev)
  (evil-define-key 'normal vterm-mode-map (kbd "i")        #'evil-insert-resume)
  (evil-define-key 'normal vterm-mode-map (kbd "o")        #'evil-insert-resume)
  (evil-define-key 'normal vterm-mode-map (kbd "<return>") #'evil-insert-resume))

;;; Clipetty setup
(use-package clipetty
  :ensure t
  :hook (after-init . global-clipetty-mode))

;;; Set DAP-python debugger to pydebug
(setq dap-python-debugger 'debugpy)

;; Scrolling setup
(setq pixel-scroll-precision-large-scroll-height 40.0)
(setq pixel-scroll-precision-interpolation-factor 30)
;; scroll one line at a time (less "jumpy" than defaults)

(setq mouse-wheel-scroll-amount '(1 ((shift) . 1))) ;; one line at a time

(setq mouse-wheel-progressive-speed nil) ;; don't accelerate scrolling

(setq mouse-wheel-follow-mouse 't) ;; scroll window under mouse

(setq scroll-step 1) ;; keyboard scroll one line at a time'))

(provide 'preston-utils)
