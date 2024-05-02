;; -*- no-byte-compile: t; -*-

(package! rotate)

(package! emacs-everywhere :recipe (:host github :repo "tecosaur/emacs-everywhere" :files ("*.el")))

(package! vlf :recipe (:host github :repo "emacs-straight/vlf" :files ("*.el")))

(package! evil-escape :disable t)

;; (package! magit-delta :recipe (:host github :repo "dandavison/magit-delta"))

(package! aas :recipe (:host github :repo "ymarco/auto-activating-snippets"))

(package! screenshot :recipe (:host github :repo "tecosaur/screenshot"))

(package! etrace :recipe (:host github :repo "aspiers/etrace"))

(package! string-inflection)

(package! info-colors)

(package! modus-themes)

(package! ef-themes)

(package! spacemacs-theme)

(package! theme-magic)

(package! gif-screencast)

(package! page-break-lines :recipe (:host github :repo "purcell/page-break-lines"))

(package! xkcd)

(package! spray)

(package! elcord)

(package! systemd)

(package! calibredb)

(package! nov)

(package! calctex :recipe (:host github :repo "johnbcoughlin/calctex"
                           :files ("*.el" "calctex/*.el" "calctex-contrib/*.el" "org-calctex/*.el" "vendor")))

(package! org :pin "0ae9d86ef3ff08cfa8947fbda754b0282763a662")
(package! org-contrib
  :recipe (:host nil :repo "https://git.sr.ht/~bzg/org-contrib"
           :files ("lisp/*.el")))

(package! org-modern)

(package! org-appear :recipe (:host github :repo "awth13/org-appear"))

(package! org-ol-tree :recipe (:host github :repo "Townk/org-ol-tree"))

(package! ob-http)

(package! org-transclusion :recipe (:host github :repo "nobiot/org-transclusion"))

(package! org-graph-view :recipe (:host github :repo "alphapapa/org-graph-view"))

(package! org-chef)

(package! org-pandoc-import :recipe
  (:host github :repo "tecosaur/org-pandoc-import" :files ("*.el" "filters" "preprocessors")))

(package! org-glossary :recipe (:host github :repo "tecosaur/org-glossary"))

(package! org-music :recipe (:host github :repo "tecosaur/org-music"))

(package! org-tanglesync)

(package! org-cite-csl-activate :recipe (:host github :repo "andras-simonyi/org-cite-csl-activate"))

(package! org-super-agenda)

(package! doct
  :recipe (:host github :repo "progfolio/doct"))

(package! org-roam :disable t)

(package! org-roam-ui :recipe (:host github :repo "org-roam/org-roam-ui" :files ("*.el" "out")))
(package! websocket) ; dependency of `org-roam-ui'

(package! engrave-faces :recipe (:host github :repo "tecosaur/engrave-faces"))

(package! ox-chameleon :recipe (:host github :repo "tecosaur/ox-chameleon"))

(package! ox-gfm)

(package! micromamba )

;; (package! paper :recipe (:host github :repo "ymarco/paper-mode"
;;                          :files ("*.el" ".so")
;;                          :pre-build ("make")))

(package! graphviz-dot-mode)

(package! beancount :recipe (:host github :repo "beancount/beancount-mode"))
