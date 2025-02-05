;; This file is part of Bintracker.
;; Copyright (c) utz/irrlicht project 2019-2020
;; See LICENSE for license details.

(module bt-emulation
    *
  (import scheme (chicken base) (chicken file posix)
	  (chicken process) (chicken string) (chicken condition)
	  (only (chicken file) file-exists? file-executable?)
	  (only (chicken process-context) get-environment-variable)
	  (only (chicken pathname) make-pathname)
	  (only (chicken platform) software-type)
	  srfi-1 srfi-13 srfi-18 base64)

  ;;;

  ;;; Check if the executable PROGRAM-NAME exists in $PATH and user has the
  ;;; necessary permissions to run it.
  (define (executable-exists? program-name)
    (cond-expand
      (windows (and (file-exists? program-name)
		    (file-executable? program-name)))
      (else (find (lambda (dir)
		    (let ((path (make-pathname dir program-name)))
		      (and (file-exists? path)
			   (file-executable? path))))
		  (string-split (get-environment-variable "PATH") ":")))))

  ;;; Create an emulator interface for the emulator PROGRAM. PROGRAM-ARGS
  ;;; shall be a list of command line argument strings that are passed to
  ;;; `program` on startup.
  ;;;
  ;;; The returned emulator is not yet running. To run it, call
  ;;; `(EMULATOR 'start)`.
  ;;;
  ;;; The following other commands may be available, depending on the features
  ;;; of the emulator application:
  ;;;
  ;;; * `'exec CMD` - Execute raw command on the emulator's interpreter. The
  ;;; details of CMD depend on the receiving emulator. For MAME commands, see
  ;;; `mame-bridge/mame-startup.lua`.
  ;;; * `'info` - Display information about the emulated machine.
  ;;; * `'run ADDRESS CODE` - Load and run the list of bytes CODE at ADDRESS.
  ;;; * `'pause` - Pause emulation.
  ;;; * `'unpause` - Unpause emulation.
  ;;; * `'start` - Launch emulator program in new thread.
  ;;; * `'quit` - Exit the Emulator.
  (define (make-emulator program program-args)
    (unless (executable-exists? program)
      (error 'make-emulator
	     (string-append "Emulator \""
			    program
			    "\" not found or not runnable.")))
    (letrec* ((emul-started #f)
	      (emul-input-port #f)
	      (emul-output-port #f)
	      (emul-pid #f)
	      (emul-thread #f)
	      (emul-input-chars '())
	      (emul-initialized #f)

	      (launch-emul-process
	       (lambda ()
		 (call-with-values
		     (lambda () (process program program-args))
		   (lambda (in out pid)
		     (set! emul-input-port in)
		     (set! emul-output-port out)
		     (set! emul-pid pid)))))

	      (emul-event-loop
	       (lambda ()
		 (let ((read-result (read-char emul-input-port)))
		   (unless (eof-object? read-result)
		     (if (eqv? read-result #\newline)
			 (begin
			   (display (list->string (reverse emul-input-chars)))
			   (newline)
			   (set! emul-input-chars '()))
			 (set! emul-input-chars
			   (cons read-result emul-input-chars)))
		     (emul-event-loop)))))

	      (send-command (lambda (cmd)
			      (when emul-started
				(display cmd emul-output-port)
				(newline emul-output-port))))

	      (start-emul (lambda ()
			    (set! emul-thread
			      (make-thread (lambda ()
					     (launch-emul-process)
					     (emul-event-loop))))
			    (thread-start! emul-thread)
			    (set! emul-started #t))))
      (lambda args
	(case (car args)
	  ((info) (send-command "i"))
	  ((start) (unless emul-started (start-emul)))
	  ((quit) (when emul-started
		    (send-command "q")
		    (call-with-values
			(lambda () (process-wait emul-pid))
		      (lambda args
			(unless (cadr args)
			  (warning "Emulator process exited abnormally"))))
		    ;; TODO exn handling
		    (thread-join! emul-thread)
		    (set! emul-started #f)))
	  ((pause) (send-command "p"))
	  ((unpause) (send-command "u"))
	  ((run) (begin
		   (unless emul-initialized
		     (set! emul-initialized #t))
		   (send-command
			 (string-append "b" (number->string (cadr args))
					"%" (base64-encode
					     (list->string (caddr args)))))))
	  ((reset) (send-command (if (and (not (null? (cdr args)))
					  (eqv? 'hard (cadr args)))
				     "rh" "rs")))
	  ;; ((setpc) (send-command
	  ;; 	    (string-append "s" (number->string (cadr args)))))
	  ((exec) (send-command (string-append "x" (cadr args))))
	  (else (warning (string-append "Unsupported emulator action"
					(->string args))))))))

  ;;; Generate an emulator object suitable for the target system with the MDAL
  ;;; platform id PLATFORM. This relies on the system.scm and emulators.scm
  ;;; lists in the Bintracker config directory. An exception is raised if no
  ;;; entry is found for either the target system, or the emulator program that
  ;;; the target system requests.
  (define (platform->emulator platform)
    (let* ((platform-config
	    (let ((pf (or (alist-ref platform
				     (read (open-input-file
					    "config/systems.scm"))
				     string=)
			  (error (string-append "Unknown target system "
						platform)))))
	      (apply (lambda (#!key emulator (startup-args '()))
		       `(,emulator ,startup-args))
		     pf)))
	   (emulator-args
	    (let ((emul (or (alist-ref
			     (car platform-config)
			     (read (open-input-file
				    (cond-expand
				      (windows "config/emulators.windows.scm")
				      (else "config/emulators.scm")))))
			    (error (string-append "Unknown emulator "
						  (car platform-config))))))
	      (apply (lambda (#!key program-name (default-args '()))
		       `(,program-name . ,default-args))
		     emul))))
      (make-emulator (car emulator-args)
		     (append (cdr emulator-args) (cadr platform-config)))))

  ) ;; end module bt-emulation
