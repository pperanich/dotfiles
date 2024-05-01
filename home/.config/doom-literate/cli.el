;;; cli.el -*- lexical-binding: t; -*-
(setq org-confirm-babel-evaluate nil)

(defun doom-shut-up-a (orig-fn &rest args)
  (quiet! (apply orig-fn args)))

(advice-add 'org-babel-execute-src-block :around #'doom-shut-up-a)

(defcli! htmlize (file)
  "Export a FILE buffer to HTML."

  (print! "Htmlizing %s" file)

  (doom-initialize)
  (require 'highlight-numbers)
  (require 'highlight-quoted)
  (require 'rainbow-delimiters)
  (require 'engrave-faces-html)

  ;; Lighten org-mode
  (when (string= "org" (file-name-extension file))
    (setcdr (assoc 'org after-load-alist) nil)
    (setq org-load-hook nil)
    (require 'org)
    (setq org-mode-hook nil)
    (add-hook 'engrave-faces-before-hook
              (lambda () (if (eq major-mode 'org-mode)
                        (org-show-all)))))

  (engrave-faces-html-file file))
