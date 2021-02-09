;;; delve-pp.el --- Pretty printer for delve         -*- lexical-binding: t; -*-

;; Copyright (C) 2021  

;; Author:  <joerg@joergvolbers.de>
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Utilities for pretty printing delve objects.

;;; Code:

(require 'cl-lib)

;; TODO Make propertizing dependend on global variable (delve-pp-inhibit-propertizing)
;; TODO Implement pprinter (including the one for "optional icons")

(defvar delve-pp-inhibit-faces nil
  "If set, never add any faces when using the pretty printer.")

(defun delve-pp-apply-mods (s mod arg)
  "Return S modified by applying MOD using ARG.
If MOD is not defined, return S unmodified.

The following mods are currently defined:

 (:width <n>)                    ;; restrict or pad output to <n> characters
 (:face <facename or spec>))     ;; return string with this face
 (:format  \"format-string\")    ;; pass nonempty value to format"
  (pcase (list mod arg)
    (`(:format ,format-spec) (funcall #'format s format-spec))
    (`(:width  ,width)       (let* ((pad (- width (string-width s))))
			       (if (<= pad 0)
				   (setq s (substring s 0 width))
				 (setq s (concat s (make-string pad ?\s))))))
    (`(:face ,face-or-spec)  (if delve-pp-inhibit-faces
				 s
			       (funcall #'propertize s 'face face-or-spec)))
    (_ s)))

(defun delve-pp-item (object pprinter mods)
  "Convert OBJECT to a string by passing it to PPRINTER and applying MODS.

OBJECT is passed as argument to PPRINTER, which has to return a
string or nil.

As a special case, PPRINTER can also be a string, which is then
returned unchanged.

MODS modify the resulting string. The argument can be either nil,
meaning to not modify it, or a property list, which is passed to
`delve-pp-apply-mods', which see."
  (let* ((s (if (stringp pprinter)
		pprinter
	      (funcall pprinter object))))
    (if (null mods)
	s
      (let ((mod-walker mods))
	(while mod-walker
	  (setq s (delve-pp-apply-mods s
				       (cl-first mod-walker)
				       (cl-second mod-walker)))
	  (setq mod-walker (seq-drop mod-walker 2)))))
    s))

(defun delve-pp-line (object pp-schemes)
  "Returns a pretty printed representation of OBJECT.

PP-SCHEMES is a list. Each item of this list can either be a
string, which is used as-is, or a pretty printer function
returning a string, to which the object is passed, or a list with
a pretty printer function and two arguments determining how to
further modify its result. The resulting string will be created
by joining all these results, ignoring nil values."
  (apply #'concat 
	 (mapcar (lambda (it)
		   (pcase it
		     ((pred stringp)             it)
		     ((pred functionp)           (funcall it object))
		     (`(,fn ,mod-key ,mod-arg)   (delve-pp-item object ,fn (list ,mod-key ,mod-arg)))
		     (`(,fn (,mod-key ,mod-arg)) (delve-pp-item object ,fn (list ,mod-key ,mod-arg)))
		     (_ (format "invalid pp-scheme: %s" it))))
		 pp-schemes)))
  

(provide 'delve-pp)
;;; delve-pp.el ends here
