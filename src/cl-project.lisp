#|
  This file is a part of CL-Project package.
  URL: http://github.com/fukamachi/cl-project
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  CL-Project is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage cl-project
  (:use :cl
        :anaphora)
  (:import-from :cl-fad
                :directory-exists-p
                :list-directory)
  (:import-from :cl-ppcre
                :scan
                :regex-replace
                :regex-replace-all)
  (:import-from :cl-emb
                :execute-emb))
(in-package :cl-project)

(cl-syntax:use-syntax :annot)

@export
(defvar *skeleton-directory*
    #.(asdf:system-relative-pathname
       :cl-project
       #p"skeleton/"))

(defvar *skeleton-parameters* nil)

@export
(defun make-project (path &rest params &key name description author email license depends-on &allow-other-keys)
  "Generate a skeleton.
`path' must be a pathname or a string."
  (declare (ignorable name description author email license depends-on))
  (when (directory-exists-p path)
    (error (format nil "~A: Directory exists" path)))
  ;; Ensure `path' ends with a slash(/).
  (setf path
        (pathname (ppcre:regex-replace "/?$" (namestring path) "/")))
  (sunless (getf params :name)
    (setf it
          (car (last (pathname-directory path)))))
  (generate-skeleton
   *skeleton-directory*
   path
   :env params)
  (load (merge-pathnames (concatenate 'string (getf params :name) ".asd")
                         path))
  (load (merge-pathnames (concatenate 'string (getf params :name) "-test.asd")
                         path)))

@export
(defun generate-skeleton (source-dir target-dir &key env)
  "General skeleton generator."
  (let ((*skeleton-parameters* env))
    (copy-directory source-dir target-dir)))

(defun copy-directory (source-dir target-dir)
  "Copy a directory recursively."
  (ensure-directories-exist target-dir)
  #+allegro
  (excl:copy-directory source-dir target-dir :quiet t)
  #-allegro
  (loop for file in (cl-fad:list-directory source-dir)
        if (cl-fad:directory-pathname-p file)
          do (copy-directory
                  file
                  (concatenate 'string
                               (directory-namestring target-dir)
                               (car (last (pathname-directory file))) "/"))
        else
          do (copy-file-to-dir file target-dir))
  t)

(defun copy-file-to-dir (source-path target-dir)
  "Copy a file to target directory."
  (let ((target-path (make-pathname
                      :directory (directory-namestring target-dir)
                      :name (regex-replace-all
                             "skeleton"
                             (pathname-name source-path)
                             (getf *skeleton-parameters* :name))
                      :type (pathname-type source-path))))
    (copy-file-to-file source-path target-path)))

(defun copy-file-to-file (source-path target-path)
  "Copy a file `source-path` to the `target-path`."
  (format t "~&writing ~A~%" target-path)
  (with-open-file (stream target-path :direction :output :if-exists :supersede)
    (write-sequence
     (cl-emb:execute-emb source-path :env *skeleton-parameters*)
     stream)))
