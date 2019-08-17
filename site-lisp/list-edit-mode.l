;;; -*- mode: lisp; package:list-edit-mode -*-
;;;
;;; list-edit.l --- 箇条書きを編集するためのマイナーモード

;;; Development
#|
;; Do `eval-last-sexp` (`C-x C-e`) on this.
(pushnew :develop/list-edit *features*)
|#

;;; Code:

(defpackage :list-edit-mode
  (:use :lisp :editor))

(in-package :list-edit-mode)

(export '(list-edit-mode list-edit-mode-on list-edit-mode-off
          ;; 設定用変数
          -list-edit-context- -list-edit-indent-level-
          ;; コマンド
          goto-beginning-of-list-item--or-original
          new-list-item--or-original
          start-list-item--or-original
          dedent-or-unlist-line--or-original
          ))


;;;; 設定用変数

(defvar-local -list-edit-context- '(:comment)
  "*箇条書き編集を有効にするコンテキストをリストで指定します。
nil を指定するとコンテキストに関わらず有効になります。

:comment -- コメント内
:string  -- 文字列内
:tag     -- タグに囲まれた範囲内
:other   -- 上記以外")

(defvar-local -list-edit-indent-level- 2
  "*箇条書きで階層ごとのインデント量を指定します。")



;;;; Development support
#+develop/list-edit
(progn
  ;; Disable list-edit-mode completely.
  (dolist (buffer (buffer-list))
    (when (buffer-local-value buffer 'list-edit-mode)
      (save-excursion
        (with-set-buffer
          (set-buffer buffer)
          (list-edit-mode-off)))))
  ;; Delete keymap so that the keymap get re-initialized.
  (setf *list-edit-keymap* nil)
  )


;;;; Utilities

(defmacro with-save-buffer-stuff (&body body)
  `(let ((#1=#:goal-column (goal-column)))
     (save-excursion
       (save-restriction
         (ed::protect-match-data
           (unwind-protect
               (progn ,@body)
             (set-goal-column #1#)))))))
(setf (get 'with-save-buffer-stuff 'ed::lisp-indent-hook) 0)

#+develop/list-edit
(defmacro check (&rest forms)
  (let ((vars (mapcar (lambda (form) (gensym)) forms)))
    `(let (,@(mapcar (lambda (var form)
                       `(,var ,form))
                     vars
                     forms))
       (msgbox ,(format nil "~{~A = ~~S~^~%~}" forms) ,@vars)
       (values ,@vars))))

#-develop/list-edit
(defmacro check (&rest forms)
  `(values ,forms))

(defun original-command (key)
  (let ((bound (mapcar #'(lambda (x)
                           (when (and (keymapp x)
                                      (not (eql x *list-edit-keymap*)))
                             (lookup-keymap x key)))
                       (append (list (current-selection-keymap))
                               (minor-mode-map)
                               (list (local-keymap))
                               (list *global-keymap*)))))
    (or (find-if-not #'keymapp bound)
        (find-if #'identity bound))))

(defmacro defcommand (name arglist &body body &aux doc)
  (when (stringp (car body))
    (setf doc (car body)
          body (cdr body)))
  `(defun ,name ,arglist
     ,@(when doc `(,doc))
     (interactive "*p")
     (flet ((original ()
              (return-from ,name
                (call-interactively (original-command *last-command-char*)))))
       (unless (list-edit-applicable-p)
         (original))
       ,@body)))


#|
- hello
  - hello
|#

(defun list-edit-applicable-p ()
  (or (null -list-edit-context-)
      (member (or (parse-point-syntax) :other) -list-edit-context-)))



;;;; List Item

(defparameter +list-item-regexp+
  (compile-regexp "^\\([ \t]*\\)\\([-+*]\\)\\( +\\|\t\\)\\([^\n\r]*\\)\n"))



(defun %parse-current-list-item ()
  "Return followings if current line is a list item.
- indent level [number]
- list marker character [character]
- Spaces or Tab after list marker [string]
- list item contents start point [number]
- list item contents end point [number]"
  (with-save-buffer-stuff
    (goto-bol)
    (when (looking-at +list-item-regexp+)
      (values
       (/ (length (match-string 1)) -list-edit-indent-level-)
       (char (match-string 2) 0)
       (match-string 3)
       (match-beginning 4)
       (match-end 4)))))

(defun %parse-previous-list-item ()
  "Return same things as `%parse-current-list-item` for previous line."
  (with-save-buffer-stuff
    (previous-line)
    (%parse-current-list-item)))




;;;; Command: cursor movement

(defun goto-beginning-of-list-item ()
  (multiple-value-bind (indent marker spaces start end)
      (%parse-current-list-item)
    (when (and marker
               (/= (point) start))
      (goto-char start))))

;; C-a
(defcommand goto-beginning-of-list-item--or-original ()
  "リストの開始位置へ移動します。
リスト上ではないか、既にリストの開始位置にいる場合は元のコマンドを実行します。"
  (multiple-value-bind (indent marker spaces start end)
      (%parse-current-list-item)
    (if (or (not marker)
            (= start (point)))
      (original)
      (goto-char start))))


;;;; Indentation

(defun %indent-list-item-to (&optional (n 1))
  (goto-bol)
  (smart-indentation (* -list-edit-indent-level- n))
  (goto-beginning-of-list-item))



;;;; Command: edit

(defcommand indent-list-item--or-original (&optional (n 1))
  "現在の行がリストであればインデントします。
リストでなければ元のコマンドを実行します。"
  (multiple-value-bind (indent marker spaces start end)
      (%parse-current-list-item)
    (unless marker
      (original))
    (%indent-list-item-to (+ indent n))))



(defcommand start-or-indent-list-item--or-original (&optional (n 1))
  "現在の行をリストにしたり、インデントしたりします。

* リストの先頭部分にいる:
    現在の行を1段インデントします。

* リストではない行の先頭部分にいる:
    前の行がリストであれば、現在の行をリストにし、前の行と同じだけインデントします。

* それ以外:
    元のコマンドを実行します。"
  (if (%parse-current-list-item)
    (call-interactively 'indent-list-item--or-original)
    (multiple-value-bind (indent marker spaces)
        (%parse-previous-list-item)
      (if marker
        (progn
          (goto-bol)
          (when (looking-at "^[ \t]*")
            (delete-region (match-beginning 0) (match-end 0)))
          (smart-indentation (+ (current-column) indent))
          (insert (format nil "~A~A" marker spaces)))
        (original)))))

(defcommand new-list-item--or-original (&optional (n 1 sv))
  "改行して次の行もリストにしたりします。

* リストの途中か最後から:
    改行して次の行もリストにします。

* リストがマーカーしか無い:
    改行して次の行はリストではなくします。

* リストの先頭部分から:
    改行して次の行はリストではなくします。

* それ以外:
    元のコマンドを実行します。"
  (when sv
    (original))
  (multiple-value-bind (indent marker spaces start end)
      (%parse-current-list-item)
    (cond ((null marker)
            (original))
          ((or (<= (point) start)
               (= start end))
            (goto-bol)
            (delete-region (point) start)
            (insert #\LFD))
          (:otherwise
            (insert #\LFD)
            (smart-indentation (* indent -list-edit-indent-level-))
            (insert (format nil "~A~A" marker spaces))))))


(defcommand dedent-or-unlist-line--or-original (&optional (n 1))
  "リストの階層を上げたり、その行をリストでなくしたりします。

* インデントされたリストの先頭部分:
    インデントを減らし、その行の階層を上げます。

* インデントされていないリストの先頭部分:
    その行をリストではなくします。

* それ以外:
    元のコマンドを実行します。"
  (multiple-value-bind (indent marker spaces start end)
      (%parse-current-list-item)
    (cond ((or (not marker)
               (> (point) start))
            (original))
          ((= indent 0)
            (delete-region (progn (goto-bol) (point)) start))
          (:otherwise
            (%indent-list-item-to (1- indent))
            (when (> 1 n)
              (dedent-or-unlist-line--or-original (1- n)))))))



;;;; Command: list item movement #FIXME



;;;; Keymap

(defvar *list-edit-keymap* nil
  "箇条書きを編集するためのキーマップ")

(unless (keymapp *list-edit-keymap*)
  (setf *list-edit-keymap* (make-sparse-keymap))
  (labels ((bind (key command)
             (define-key *list-edit-keymap* key command)))
    (bind #\C-a 'goto-beginning-of-list-item--or-original)
    (bind #\TAB 'start-or-indent-list-item--or-original)
    (bind #\RET 'new-list-item--or-original)
    (bind #\Backspace 'dedent-or-unlist-line--or-original)
    ))


;;;; The minor mode

(defvar-local list-edit-mode nil)

(defun list-edit-mode (&optional (arg nil sv))
  "箇条書きを編集するためのマイナーモード"
  (interactive "*p")
  (ed::toggle-mode 'list-edit-mode arg sv)
  (if list-edit-mode
    (enter-list-edit-mode)
    (exit-list-edit-mode))
  (update-mode-line t))

(defun enter-list-edit-mode ()
  (set-minor-mode-map *list-edit-keymap*))

(defun exit-list-edit-mode ()
  (unset-minor-mode-map *list-edit-keymap*))

(defun list-edit-mode-on ()
  (list-edit-mode t))

(defun list-edit-mode-off ()
  (list-edit-mode nil))

(pushnew '(list-edit-mode . "ListEdit") *minor-mode-alist* :key #'car)


#+develop/list-edit
(when (yes-or-no-p "Turn on list-edit-mode?")
  (list-edit-mode-on))


(provide "list-edit")
;;; list-edit.l ends here.
