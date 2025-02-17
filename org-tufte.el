;;; org-tufte.el --- Export org to tufte html -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Zilong Li
;;
;; Author: Zilong Li <zilong.dk@gmail.com>
;; Maintainer: Zilong Li <zilong.dk@gmail.com>
;; Created: March 08, 2023
;; Modified: March 08, 2023
;; Version: 0.0.1
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex tools unix vc wp
;; Homepage: https://github.com/Zilong-Li/org-tufte
;; Package-Requires: ((emacs "24.4"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;  blabla
;;
;;
;;; Code:

(require 's)
(require 'ox)
(require 'ox-html)

;;; User-Configurable Variables

(defgroup org-tufte-export nil
  "Options specific to Tufte export back-end."
  :tag "Org Tufte"
  :group 'org-export
  :version "24.4"
  :package-version '(Org . "8.0"))

(defcustom org-tufte-include-footnotes-at-bottom nil
  "Non-nil means to include footnotes at the bottom of the page
  in addition to being included as sidenotes. Sidenotes are not
  shown on very narrow screens (phones), so it may be useful to
  additionally include them at the bottom."
  :group 'org-tufte-export
  :type 'boolean)

(defcustom org-tufte-katex-template "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.16.4/dist/katex.min.css\" integrity=\"sha384-vKruj+a13U8yHIkAyGgK1J3ArTLzrFGBbBc0tDp4ad/EyewESeXE/Iv67Aj8gKZ0\" crossorigin=\"anonymous\">
<script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.16.4/dist/katex.min.js\" integrity=\"sha384-PwRUT/YqbnEjkZO0zZxNqcxACrXe+j766U2amXcgMg5457rve2Y7I6ZJSm2A0mS4\" crossorigin=\"anonymous\"></script>
<script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.16.4/dist/contrib/auto-render.min.js\" integrity=\"sha384-+VBxd3r6XgURycqtZ117nYw44OOcIax56Z4dCRWbxyPt0Koah1uHoK0o4+/RRE05\" crossorigin=\"anonymous\"
    onload=\"renderMathInElement(document.body);\"></script>"
  "Katex api as backend"
  :group 'org-export-html
  :type 'string)

;;; Define Back-End

(org-export-define-derived-backend 'tufte-html 'html
  :menu-entry
  '(?T "Export to Tufte-HTML"
       ((?T "To temporary buffer"
            (lambda (a s v b) (org-tufte-export-to-buffer a s v)))
        (?t "To file" (lambda (a s v b) (org-tufte-export-to-file a s v)))
        (?o "To file and open"
            (lambda (a s v b)
              (if a (org-tufte-export-to-file t s v)
                (org-open-file (org-tufte-export-to-file nil s v)))))))
  :translate-alist '((footnote-reference . org-tufte-footnote-reference)
                     (src-block . org-tufte-src-block)
                     (link . org-tufte-maybe-margin-note-link)
                     (quote-block . org-tufte-quote-block)
                     (verse-block . org-tufte-verse-block)
                     (template . org-tufte-modern-html-template)
                     (section . org-tufte-modern-html-section)
                     (headline . org-tufte-modern-html-headline)
                     (item . org-html-item)))

;;; Transcode Functions

(defun org-tufte-quote-block (quote-block contents info)
  "Transform a quote block into an epigraph in Tufte HTML style"
  (format "<div class=\"epigraph\"><blockquote>\n%s\n%s</blockquote></div>"
          contents
          (if (org-element-property :name quote-block)
              (format "<footer>%s</footer>"
                      (org-element-property :name quote-block))
            "")))

(defun org-tufte-verse-block (verse-block contents info)
  "Transcode a VERSE-BLOCK element from Org to HTML.
CONTENTS is verse block contents.  INFO is a plist holding
contextual information."
  ;; Replace each newline character with line break.  Also replace
  ;; each blank line with a line break.
  (setq contents (replace-regexp-in-string
                  "^ *\\\\\\\\$" (format "%s\n" (org-html-close-tag "br" nil info))
                  (replace-regexp-in-string
                   "\\(\\\\\\\\\\)?[ \t]*\n"
                   (format "%s\n" (org-html-close-tag "br" nil info)) contents)))
  ;; Replace each white space at beginning of a line with a
  ;; non-breaking space.
  (while (string-match "^[ \t]+" contents)
    (let* ((num-ws (length (match-string 0 contents)))
           (ws (let (out) (dotimes (i num-ws out)
                            (setq out (concat out "&#xa0;"))))))
      (setq contents (replace-match ws nil t contents))))
  (format "<div class=\"epigraph\"><blockquote>\n%s\n%s</blockquote></div>"
          contents
          (if (org-element-property :name verse-block)
              (format "<footer>%s</footer>"
                      (org-element-property :name verse-block))
            "")))

(defun org-tufte-footnote-reference (footnote-reference contents info)
  "Create a footnote according to the tufte css format.
FOOTNOTE-REFERENCE is the org element, CONTENTS is nil. INFO is a
plist holding contextual information."
  (format
   (concat "<label for=\"%s\" class=\"margin-toggle sidenote-number\"></label>"
           "<input type=\"checkbox\" id=\"%s\" class=\"margin-toggle\"/>"
           "<span class=\"sidenote\">%s</span>")
   (org-export-get-footnote-number footnote-reference info)
   (org-export-get-footnote-number footnote-reference info)
   (let ((fn-data (org-trim
                   (org-export-data
                    (org-export-get-footnote-definition footnote-reference info)
                    info))))
     ;; footnotes must have spurious <p> tags removed or they will not work
     (replace-regexp-in-string "</?p.*>" "" fn-data))))

(defun org-tufte-maybe-margin-note-link (link desc info)
  "Render LINK as a margin note if it starts with `mn:', for
  example, `[[mn:1][this is some text]]' is margin note 1 that
  will show \"this is some text\" in the margin.

If it does not, it will be passed onto the original function in
order to be handled properly. DESC is the description part of the
link. INFO is a plist holding contextual information."
  (let ((path (split-string (org-element-property :path link) ":")))
    (if (and (string= (org-element-property :type link) "fuzzy")
             (string= (car path) "mn"))
        (format
         (concat "<label for=\"%s\" class=\"margin-toggle\">&#8853;</label>"
                 "<input type=\"checkbox\" id=\"%s\" class=\"margin-toggle\"/>"
                 "<span class=\"marginnote\">%s</span>")
         (cadr path) (cadr path)
         (replace-regexp-in-string "</?p.*>" "" desc))
      (org-html-link link desc info))))

(defun org-tufte-src-block (src-block contents info)
  "Transcode SRC-BLOCK element into Tufte HTML format. CONTENTS
is nil. INFO is a plist used as a communication channel."
  (format "<pre class=\"code\"><code>%s</code></pre>"
          (org-html-format-code src-block info)))

;;; https://github.com/sulami/sulami.github.io/blob/develop/config.el
(defun org-tufte-modern-html-template (contents info)
  (concat
   "<!DOCTYPE html>\n"
   (format "<html lang=\"%s\">\n" (plist-get info :language))
   "<head>\n"
   (format "<meta charset=\"%s\">\n"
           (coding-system-get org-html-coding-system 'mime-charset))
   "<meta name=\"viewport\" content=\"width=device-width\">\n"
   (format "<meta name=\"author\" content=\"%s\">\n"
           (org-export-data (plist-get info :author) info))
   "<link rel=\"stylesheet\" href=\"https://zilongli.org/code/normalize.css\" type=\"text/css\" />\n"
   "<link rel=\"stylesheet\" href=\"https://zilongli.org/code/tufte.css\" type=\"text/css\" />\n"
   "<link rel=\"stylesheet\" href=\"https://zilongli.org/code/org.css\" type=\"text/css\" />\n"
   org-tufte-katex-template
   "</head>\n"
   "<body>\n"
   "<div id=\"body\"><div id=\"container\">"
   "<div id=\"content\"><article>"
   (format "<h1 class=\"title\">%s</h1>\n"
           (org-export-data (or (plist-get info :title) "") info))
   (when (plist-get info :date)
     (format "<div class=\"info\">Posted on %s</div>\n"
             (car (plist-get info :date))))
   contents
   "</article></div></div></div>
        </script>
   </body>\n"
   "</html>\n"))

;; setq session-num nil
(defun org-tufte-modern-html-section (section contents info)
  (let* ((headline (org-export-get-parent-headline section))
         (level (org-element-property :level headline)))
    (concat
     "<section>"
     (when headline
       (concat
        (format "<h%s>" (1+ level))
        ;; NB Fix for that one post that has subscript in headlines.
        (format "%s" (s-replace-regexp (rx "_{" (group-n 1 (1+ anything)) "}")
                                       "<sub>\\1</sub>"
                                       (org-element-property :raw-value headline)))
        (format "</h%s>\n" (1+ level))))
     contents
     "</section>\n")))


(defun org-tufte-modern-html-headline (headline contents info)
  contents)

;;; Export functions

;;;###autoload
(defun org-tufte-export-to-buffer (&optional async subtreep visible-only)
  "Export current buffer to a Tufte HTML buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Export is done in a buffer named \"*Org Tufte Export*\", which will
be displayed when `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (let (;; need to bind this because tufte treats footnotes specially, so we
        ;; don't want to display them at the bottom
        (org-html-footnotes-section (if org-tufte-include-footnotes-at-bottom
                                        org-html-footnotes-section
                                      "<!-- %s --><!-- %s -->")))
    (org-export-to-buffer 'tufte-html "*Org Tufte Export*"
      async subtreep visible-only nil nil (lambda () (text-mode)))))

;;;###autoload
(defun org-tufte-export-to-file (&optional async subtreep visible-only)
  "Export current buffer to a Tufte HTML file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Return output file's name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".html" subtreep))
        ;; need to bind this because tufte treats footnotes specially, so we
        ;; don't want to display them at the bottom
        (org-html-footnotes-section (if org-tufte-include-footnotes-at-bottom
                                        org-html-footnotes-section
                                      "<!-- %s --><!-- %s -->")))
    (org-export-to-file 'tufte-html outfile async subtreep visible-only)))

;;; publishing function

;;;###autoload
(defun org-tufte-publish-to-html (plist filename pub-dir)
  "Publish an org file to Tufte-styled HTML.

PLIST is the property list for the given project.  FILENAME is
the filename of the Org file to be published.  PUB-DIR is the
publishing directory.

Return output file name."
  (org-publish-org-to 'tufte-html filename
                      (concat "." (or (plist-get plist :html-extension)
                                      org-html-extension
                                      "html"))
                      plist pub-dir))

;;; export command

(fset 'export-org-tufte-html
   (kmacro-lambda-form [?\C-c ?\C-e ?T ?o] 0 "%d"))


(provide 'org-tufte)
;;; org-tufte.el ends here
