;;; -*- mode: lisp; package:list-edit-mode -*-
;;;
;;; list-edit.l --- �ӏ�������ҏW���邽�߂̃}�C�i�[���[�h

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
          ;; �ݒ�p�ϐ�
          -list-edit-context- -list-edit-indent-level-
          ;; �R�}���h
          goto-beginning-of-list-item--or-original
          new-list-item--or-original
          start-list-item--or-original
          dedent-or-unlist-line--or-original
          ))


;;;; �ݒ�p�ϐ�

(defvar-local -list-edit-context- '(:comment)
  "*�ӏ������ҏW��L���ɂ���R���e�L�X�g�����X�g�Ŏw�肵�܂��B
nil ���w�肷��ƃR���e�L�X�g�Ɋւ�炸�L���ɂȂ�܂��B

:comment -- �R�����g��
:string  -- �������
:tag     -- �^�O�Ɉ͂܂ꂽ�͈͓�
:other   -- ��L�ȊO")

(defvar-local -list-edit-indent-level- 2
  "*�ӏ������ŊK�w���Ƃ̃C���f���g�ʂ��w�肵�܂��B")



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
  "���X�g�̊J�n�ʒu�ֈړ����܂��B
���X�g��ł͂Ȃ����A���Ƀ��X�g�̊J�n�ʒu�ɂ���ꍇ�͌��̃R�}���h�����s���܂��B"
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
  "���݂̍s�����X�g�ł���΃C���f���g���܂��B
���X�g�łȂ���Ό��̃R�}���h�����s���܂��B"
  (multiple-value-bind (indent marker spaces start end)
      (%parse-current-list-item)
    (unless marker
      (original))
    (%indent-list-item-to (+ indent n))))



(defcommand start-or-indent-list-item--or-original (&optional (n 1))
  "���݂̍s�����X�g�ɂ�����A�C���f���g�����肵�܂��B

* ���X�g�̐擪�����ɂ���:
    ���݂̍s��1�i�C���f���g���܂��B

* ���X�g�ł͂Ȃ��s�̐擪�����ɂ���:
    �O�̍s�����X�g�ł���΁A���݂̍s�����X�g�ɂ��A�O�̍s�Ɠ��������C���f���g���܂��B

* ����ȊO:
    ���̃R�}���h�����s���܂��B"
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
  "���s���Ď��̍s�����X�g�ɂ����肵�܂��B

* ���X�g�̓r�����Ōォ��:
    ���s���Ď��̍s�����X�g�ɂ��܂��B

* ���X�g���}�[�J�[��������:
    ���s���Ď��̍s�̓��X�g�ł͂Ȃ����܂��B

* ���X�g�̐擪��������:
    ���s���Ď��̍s�̓��X�g�ł͂Ȃ����܂��B

* ����ȊO:
    ���̃R�}���h�����s���܂��B"
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
  "���X�g�̊K�w���グ����A���̍s�����X�g�łȂ������肵�܂��B

* �C���f���g���ꂽ���X�g�̐擪����:
    �C���f���g�����炵�A���̍s�̊K�w���グ�܂��B

* �C���f���g����Ă��Ȃ����X�g�̐擪����:
    ���̍s�����X�g�ł͂Ȃ����܂��B

* ����ȊO:
    ���̃R�}���h�����s���܂��B"
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
  "�ӏ�������ҏW���邽�߂̃L�[�}�b�v")

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
  "�ӏ�������ҏW���邽�߂̃}�C�i�[���[�h"
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