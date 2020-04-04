;; This file is part of the libmdal library.
;; Copyright (c) utz/irrlicht project 2018
;; See LICENSE for license details.

;;; md-module record types and additional accessors
(module md-types *

  (import scheme (chicken base) (chicken string)
	  srfi-1 srfi-13 md-helpers)

  ;; ---------------------------------------------------------------------------
  ;;; ## MDMOD: Input Nodes
  ;; ---------------------------------------------------------------------------

  ;;; Returns the subnode with the given SUBNODE-ID.
  (define (subnode-ref subnode-id inode-instance)
    (assv subnode-id (cddr inode-instance)))

  ;;; Returns the inode instance witht the given INSTANCE-ID.
  (define (inode-instance-ref instance-id inode)
    (assq instance-id (cdr inode)))

  ;;; Returns the value of the field at FIELD-INDEX in ROW of
  ;;; `block-instance`. Returns null if the requested ROW does not exist.
  (define (block-field-ref block-instance row field-index)
    (let ((rows (cddr block-instance)))
      (if (>= row (length rows))
	  '()
	  (list-ref (list-ref rows row)
		    field-index))))

  ;; TODO obsolete?
  ;;; Return the number of instances in the given inode
  (define (inode-count-instances node)
    (length (cdr node)))


  ;; ---------------------------------------------------------------------------
  ;;; ## MDMOD: Module
  ;; ---------------------------------------------------------------------------

  ;;; The internal representation of an MDAL module is a pair containing
  ;;; an MDAL `config` as the first element, and the global module node as the
  ;;; second element, so `(config . global-node)`. libmdal provides the
  ;;; accessors `mdmod-config` and `mdmod-global-node` for dealing with the
  ;;; elements of a module.
  ;;;
  ;;; The structure of `global-node` mirrors that of the MDAL module
  ;;; s-expression, with the following changes:
  ;;;
  ;;; - The GLOBAL node is explicit.
  ;;; - Each node is represented as an element in an alist, where the key is
  ;;;   the node ID, and the value (remainder) is an alist of node instances.
  ;;; - Each node instance is represented as an element in an alist, where the
  ;;;   key is the instance ID, the first value of the remainder is the node
  ;;;   instance name (or `#f` if none was given), and the rest of the remainder
  ;;;   is the actual node instance value, depending on the node type.
  ;;; - In block node instances, all rows are expanded to a list containing the
  ;;;   values for each block field subnode. Unset (empty) fields are
  ;;;   represented by `null` (the empty list).

  (define (mdmod-config m) (car m))
  (define (mdmod-global-node m) (cdr m))

  ;;----------------------------------------------------------------------------
  ;;; ### mod accessor functions
  ;;----------------------------------------------------------------------------

  ;;; Generate a function that takes an inode as parameter, and returns the
  ;;; subnode or node instance matching the given path P, which must be a
  ;;; string in the form "instance-id/node-id...". For example,
  ;;;
  ;;; ```Scheme
  ;;; (node-path "0/PATTERNS/0/CH1")
  ;;; ```
  ;;;
  ;;; will return a procedure that, when called with the global node as
  ;;; argument, will return the node CH1 in instance 0 of the PATTERN node,
  ;;; assuming that the node exists and is defined in the module's
  ;;; configuration.
  (define (node-path p)
    (let* ((path (string-split p "/"))
	   (path-suffix (last path))
	   (last-path-elem (or (string->number path-suffix)
			       (string->symbol path-suffix)))
	   (accessor-proc
	    (apply
	     compose
	     (cons (lambda (contents)
		     (assv last-path-elem contents))
		   (cdr (reverse
			 (map (lambda (path-elem subnode-access)
				(if subnode-access
				    (lambda (contents)
				      (alist-ref (string->symbol path-elem)
						 contents))
				    (lambda (contents)
				      (cdr (alist-ref (string->number path-elem)
						      contents)))))
			      path (circular-list #f #t))))))))
      (lambda (node)
	(accessor-proc (cdr node)))))

  ;;; Returns the values of all field node instances of the given ROW of the
  ;;; given non-order block-instances in the given GROUP-INSTANCE as a
  ;;; flat list.
  ;;; BLOCK-INSTANCE-IDS must be a list containing the requested numerical
  ;;; block instance IDs for each non-order block in the group.
  ;;; Values are returned as strings, except for trigger fields.
  ;;; Empty (unset) instance values will be returned as `#f`.
  (define (mod-get-row-values group-instance block-instance-ids row)
    (flatten
     (map (lambda (block-inst-id block-node)
	    (let ((block-contents (cddr (inode-instance-ref block-inst-id
							    block-node))))
	      (map (lambda (value)
		     (and (not (null? value))
			  (if (boolean? value)
			      value
			      (->string value))))
		   (if (>= row (length block-contents))
		       ;; TODO using row 0 to construct an empty row here. This
		       ;; is unsafe, because even row 0 may not exist.
		       (make-list (length (car block-contents)) '())
		       (list-ref block-contents row)))))
	  block-instance-ids
	  (remove (lambda (node)
		    (symbol-contains (car node) "_ORDER"))
		  (cddr group-instance)))))

  ;;; Returns the values of all field node instances of the non-order block
  ;;; instances in the given `group-instance`, as a list of row value sets.
  ;;; Effectively calls md-mod-get-row-values on each row of the relevant
  ;;; blocks.
  (define (mod-get-block-values group-instance block-instance-ids)
    (map (cute mod-get-row-values group-instance block-instance-ids <>)
  	 (iota (length (cdr (alist-ref
			     (car block-instance-ids)
			     (cdr (find (lambda (subnode)
					  (not (symbol-contains (car subnode)
								"_ORDER")))
  					(cddr group-instance)))))))))

  ;;; Returns the group instance's order node (instance 0)
  (define (mod-get-group-instance-order igroup-instance igroup-id)
    (cadr (subnode-ref (symbol-append igroup-id '_ORDER) igroup-instance)))

  ;;; Helper for `mod-get-order-values.
  ;;; Given the contents of a block instance, return the contents such that
  ;;; empty fields are replaced with the last set value.
  (define (repeat-block-row-values rows)
    (letrec ((repeat-values
	      (lambda (rows previous-row)
		(if (null-list? rows)
  		    '()
  		    (cons (map (lambda (pos previous-pos)
  				 (if (null? pos)
  				     previous-pos pos))
  			       (car rows) previous-row)
  			  (repeat-values (cdr rows) (car rows)))))))
      (repeat-values rows (make-list (length (car rows))
				     0))))

  ;; TODO swap argument order
  ;;; Returns the values of all order fields as a list of row value sets.
  ;;; Values are normalized, ie. empty positions are replaced with repeated
  ;;; values from an earlier row.
  (define (mod-get-order-values group-id group-instance)
    (repeat-block-row-values (cddr (mod-get-group-instance-order group-instance
								 group-id))))

  ;; TODO swap argument order
  ;;; Returns the total number of all block rows in the given group node
  ;;; instance. The containing group node must be ordered. The result is equal
  ;;; to the length of the block nodes as if they were combined into a single
  ;;; instance after being mapped onto the order node.
  (define (get-ordered-group-length group-id group-instance)
    (apply + (map car (mod-get-order-values group-id group-instance))))

  ) ;; end module md-types
