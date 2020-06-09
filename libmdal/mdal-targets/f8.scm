(asm-target

 endian: big

 registers: ((dc 0) (is 0) (ku 0) (kl 1) (qu 2) (ql 3) (hu 10) (hl 11) (q #xe)
	     (h #xf) (s 12) (i 13) (d 14) (a 0))

 register-sets: ((rkq (ku kl qu ql))
		 (rh (hu hl))
		 (rqh (q h))
		 (isar (s i d)))

 extra: ((const-4bit (bind (as-string
			    (any-of (sequence (is #\1)
					      (in (string->char-set "012345")))
				    (in char-set:digit)))
			   (lambda (r) (result (string->number r)))))
	 (const-3bit (bind (as-string (in (string->char-set "01234567")))
			   (lambda (r) (result (string->number r))))))

 instructions:
 ((adc (0 (#x8e)))
  (ai (1 ((numeric (#x24 (lsb %op1))))))
  (amd (0 (#x89)))
  (am (0 (#x88)))
  (asd (1 (((extras 'const-4bit) ((+ #xd0 %op1)))
	   ((register 'isar) ((+ #xd0 (register-value %op1)))))))
  (as (1 (((extras 'const-4bit) ((+ #xc0 %op1)))
	  ((register 'isar) ((+ #xc0 (register-value %op1)))))))
  (bc (1 (((signed-number-range 8) (#x82 (lsb %op1)))
  	  (numeric (#x82 (lsb (- %op1 1 current-origin)))))))
  (bf (2 (((extras 'const-3bit) (((signed-number-range 8) ((+ #x90 %op1)
  							   (lsb %op2)))
  				 (numeric ((#x90 %op1)
  					   (lsb
					    (- %op2 1 current-origin)))))))))
  (bm (1 (((signed-number-range 8) (#x91 (lsb %op1)))
  	  (numeric (#x91 (lsb (- %op1 1 current-origin)))))))
  (bnc (1 (((signed-number-range 8) (#x92 (lsb %op1)))
  	   (numeric (#x92 (lsb (- %op1 1 current-origin)))))))
  (bno (1 (((signed-number-range 8) (#x98 (lsb %op1)))
  	   (numeric (#x98 (lsb (- %op1 1 current-origin)))))))
  (bnz (1 (((signed-number-range 8) (#x94 (lsb %op1)))
  	   (numeric (#x94 (lsb (- %op1 1 current-origin)))))))
  (bp (1 (((signed-number-range 8) (#x81 (lsb %op1)))
  	  (numeric (#x81 (lsb (- %op1 1 current-origin)))))))
  (br7 (1 (((signed-number-range 8) (#x8f (lsb %op1)))
  	   (numeric (#x8f (lsb (- %op1 1 current-origin)))))))
  (br (1 (((signed-number-range 8) (#x90 (lsb %op1)))
  	  (numeric (#x90 (lsb (- %op1 1 current-origin)))))))
  (bt (2 (((extras 'const-3bit) (((signed-number-range 8) ((+ #x80 %op1)
  							   (lsb %op2)))
  				 (numeric ((+ #x80 %op1)
  					   (lsb
					    (- %op2 2 current-origin)))))))))
  (bz (1 (((signed-number-range 8) (#x84 (lsb %op1)))
  	  (numeric (#x84 (lsb (- %op1 1 current-origin)))))))
  (ci (1 ((numeric (#x25 (lsb %op1))))))
  (clr (0 (#x70)))
  (cm (0 (#x8d)))
  (com (0 (#x18)))
  (dci (1 ((numeric (#x2a (msb %op1) (lsb %op1))))))
  (di (0 (#x1a)))
  (ds (1 (((extras 'const-4bit) ((+ #x30 %op1)))
	  ((register 'isar) ((+ #x30 (register-value %op1)))))))
  (ei (0 (#x1b)))
  (inc (0 (#x1f)))
  (ins (1 (((extras 'const-3bit) ((+ #xa0 %op1))))))
  (in (1 ((numeric (#x26 (lsb %op1))))))
  (jmp (1 ((numeric (#x29 (msb %op1) (lsb %op1))))))
  ;; TODO these should allow numeric
  (lisu (1 (((extras 'const-3bit) ((+ #x60 %op1))))))
  (lisl (1 (((extras 'const-3bit) ((+ #x68 %op1))))))
  (lis (1 ((numeric ((+ #x70 (bitwise-and %op1 #xf)))))))
  (li (1 ((numeric (#x20 (lsb %op1))))))
  (lm (0 (#x16)))
  (lnk (0 (#x19)))
  (lr (2 (((is #\a) (((register 'rkq) ((register-value %op2)))
  		     ((register 'rh) ((+ #x40 (register-value %op2))))
  		     ((char-seq "is") (#x0a))
  		     ((extras 'const-4bit) ((+ #x40 %op2)))
		     ((register 'isar) ((+ #x40 (register-value %op2))))))
  	  ((register 'rkq) (((is #\a) ((+ 4 (register-value %op1))))))
  	  ((register 'rh) (((is #\a) ((+ #x50 (register-value %op1))))))
  	  ((char-seq "is") (((is #\a) (#x0b))))
	  ((char-seq "dc") (((is #\h) (#x10))
			    ((is #\q) (#x0f))))
  	  ((extras 'const-4bit) (((is #\a) ((+ #x50 %op1)))))
	  ((register 'isar) (((is #\a) ((+ #x50 (register-value %op1))))))
  	  ((is #\k) (((is #\p) (8))))
  	  ((char-seq "p0") (((is #\q) (#x0d))))
  	  ((is #\p) (((is #\k) (9))))
  	  ((is #\j) (((is #\w) (#x1e))))
  	  ((is #\w) (((is #\j) (#x1d))))
  	  ((is #\h) (((char-seq "dc") (#x11))))
	  ((is #\q) (((char-seq "dc") (#x0e)))))))
  (ni (1 ((numeric (#x21 (lsb %op1))))))
  (nop (0 (#x2b)))
  (nm (0 (#x8a)))
  (ns (1 (((extras 'const-4bit) ((+ #xf0 %op1)))
	  ((register 'isar) ((+ #xf0 (register-value %op1)))))))
  (oi (1 ((numeric (#x22 (lsb %op1))))))
  (om (0 (#x8b)))
  (outs (1 (((extras 'const-3bit) ((+ #xb0 %op1))))))
  (out (1 ((numeric (#x27 (lsb %op1))))))
  (pi (1 ((numeric (#x28 (msb %op1) (lsb %op1))))))
  (pk (0 (#xc)))
  (pop (0 (#x1c)))
  (sl (1 (((is #x1) (#x13))
  	  ((is #x4) (#x15)))))
  (sr (1 (((is #x1) (#x12))
  	  ((is #x4) (#x14)))))
  (st (0 (#x17)))
  (xdc (0 (#x2c)))
  (xi (1 ((numeric (#x23 (lsb %op1))))))
  (xm (0 (#x8c)))
  (xs (1 (((extras 'const-4bit) (+ #xe0 %op1))
	  ((register 'isar) ((+ #xe0 (register-value %op1)))))))))
