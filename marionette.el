;;; marionette.el --- Control Firefox via the Marionette Protocol  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Xu Chunyang

;; Author: Xu Chunyang
;; Homepage: https://github.com/xuchunyang/marionette.el
;; Package-Requires: ((emacs "25.1"))
;; Keywords: tools
;; Version: 0

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

;; https://firefox-source-docs.mozilla.org/testing/marionette/index.html

;;; Code:

(require 'json)
(require 'warnings)

(defun marionette--message (format &rest args)
  "Message out with FORMAT with ARGS."
  (message "[marionette] %s" (apply #'format format args)))

(defun marionette--warn (format &rest args)
  "Warning message with FORMAT and ARGS."
  (apply #'marionette--message (concat "(warning) " format) args)
  (let ((warning-minimum-level :error))
    (display-warning 'marionette
                     (apply #'format format args)
                     :warning)))

(defun marionette--json-read ()
  "Read JSON object in buffer, move point to end of buffer."
  (let ((json-false nil)
        (json-null nil)
        (json-array-type 'list)
        (json-object-type 'alist)
        (json-key-type 'symbol))
    (json-read)))

;; Adapted from jsonrpc.el
(defun marionette--process-filter (proc string)
  "Called when new data STRING has arrived for PROC."
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (let ((expected-bytes (process-get proc 'expected-bytes)))
        ;; Insert the text, advancing the process marker.
        ;;
        (save-excursion
          (goto-char (process-mark proc))
          (insert string)
          (set-marker (process-mark proc) (point)))
        ;; Loop (more than one message might have arrived)
        ;;
        (unwind-protect
            (let (done)
              (while (not done)
                (cond
                 ((not expected-bytes)
                  ;; Starting a new message
                  ;;
                  (setq expected-bytes
                        (and (re-search-forward "\\([1-9][0-9]*\\):" (+ (point) 10) t)
                             (string-to-number (match-string 1))))
                  (unless expected-bytes
                    (setq done :waiting-for-new-message)))
                 (t
                  ;; Attempt to complete a message body
                  ;;
                  (let ((available-bytes (- (position-bytes (process-mark proc))
                                            (position-bytes (point)))))
                    (cond
                     ((>= available-bytes expected-bytes)
                      (let ((message-end (byte-to-position
                                          (+ (position-bytes (point))
                                             expected-bytes))))
                        (unwind-protect
                            (save-restriction
                              (narrow-to-region (point) message-end)
                              (let ((json-message
                                     (condition-case-unless-debug oops
                                         (marionette--json-read)
                                       (error
                                        (marionette--warn "Invalid JSON: %s %s"
                                                          (cdr oops) (buffer-string))
                                        nil))))
                                (process-put proc 'response (cons (process-get proc 'id) json-message))))
                          (goto-char message-end)
                          (delete-region (point-min) (point))
                          (setq expected-bytes nil))))
                     (t
                      ;; Message is still incomplete
                      ;;
                      (setq done :waiting-for-more-bytes-in-this-message))))))))
          ;; Saved parsing state for next visit to this filter
          ;;
          (process-put proc 'expected-bytes expected-bytes))))))

(define-error 'marionette-error "marionette-error")

;; https://searchfox.org/mozilla-central/source/testing/marionette/driver.js
(defun marionette-request (proc command &rest params)
  "Make a request to PROC, wait for a reply.
COMMAND is webdriver command.
PARAMS is parameters for COMMAND.
Return the response (type, message ID, error, result)."
  (let* ((id (pcase (process-get proc 'id)
               ('nil 0)
               (i (1+ i))))
         (command (concat "WebDriver:" (symbol-name command)))
         (json (json-encode
                (vector 0 id command (or params #s(hash-table))))))
    (process-put proc 'id id)
    (process-put proc 'response nil)
    (process-send-string proc (format "%d:%s" (string-bytes json) json))
    (while (not (process-get proc 'response))
      (accept-process-output proc 30))
    (pcase-exhaustive (process-get proc 'response)
      (`(,_id . (,_type ,_id ,error ,result))
       (when error
         (signal 'marionette-error
                 (list
                  (format "request %s failed:" command) error)))
       result))))

(defun marionette-connect (&optional host port)
  "Make a connection, return the process.
Optional argument HOST defaults to \"localhost\".
Optional argument PORT defaults to 2828."
  (let ((proc (make-network-process
               :name "Marionette"
               :buffer " *Marionette*"
               :host (or host "localhost")
               :service (or port 2828)
               :coding 'utf-8
               :filter #'marionette--process-filter
               :filter-multibyte t)))
    ;; Skip the initial response
    (accept-process-output proc 0.01)
    proc))

(defun marionette-with-page (fn)
  "Setup Marionette and run FN with one argument: PROC."
  (let ((proc (marionette-connect)))
    (marionette-request proc 'NewSession)
    (let-alist (marionette-request proc 'NewWindow)
      (marionette-request proc
                          'SwitchToWindow
                          :focus t
                          :name .handle
                          :handle .handle))
    (unwind-protect
        (funcall fn proc)
      (marionette-request proc 'DeleteSession)
      (delete-process proc)
      (kill-buffer (process-buffer proc)))))

(provide 'marionette)
;;; marionette.el ends here
