;; test-private.scm: private API test routines for r6rs-protobuf
;; Copyright (C) 2020 Julian Graham

;; r6rs-protobuf is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

#!r6rs

(import (rnrs))
(import (protobuf private))
(import (srfi :64))

(test-begin "private")
(test-begin "read")

(define-record-type read-test-message
  (fields foo) (opaque #t) (parent protobuf:message) (sealed #t))

(define-record-type read-test-message-builder
  (fields (mutable foo))
  (parent protobuf:message-builder)
  (protocol 
   (lambda (p)
     (lambda ()
       (let ((n (p read-test-message
		   (list (protobuf:make-field-descriptor 
			  0 "foo" protobuf:field-type-string #f #t #f)))))
	 (n #f))))))

(define (make-field-header field-number wire-type-num)
  (bitwise-ior (bitwise-arithmetic-shift-left field-number 3) wire-type-num))

(test-begin "unknown-fields")
(test-group "varint"
  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-varint bv-out (make-field-header 1 0))
    (protobuf:write-varint bv-out 256)
    (protobuf:write-varint bv-out (make-field-header 0 2))
    (protobuf:write-string bv-out "Test")
    (let ((m (protobuf:message-read 
	      (make-read-test-message-builder)
	      (open-bytevector-input-port (bv-proc)))))
      (test-assert (read-test-message? m))
      (test-equal "Test" (read-test-message-foo m)))))

(test-group "64-bit"
  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-varint bv-out (make-field-header 1 1))
    (protobuf:write-fixed64 bv-out 256)
    (protobuf:write-varint bv-out (make-field-header 0 2))
    (protobuf:write-string bv-out "Test")
    (let ((m (protobuf:message-read 
	      (make-read-test-message-builder)
	      (open-bytevector-input-port (bv-proc)))))
      (test-assert (read-test-message? m))
      (test-equal "Test" (read-test-message-foo m))))

  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-int64 bv-out -1)
    (let ((b (bv-proc)))
      (test-assert
       (bytevector=?
	b #vu8(#xff #xff #xff #xff #xff #xff #xff #xff #xff #x01))))))

(test-group "length-delimited"
  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-varint bv-out (make-field-header 1 2))
    (protobuf:write-string bv-out "Ignore")
    (protobuf:write-varint bv-out (make-field-header 0 2))
    (protobuf:write-string bv-out "Test")
    (let ((m (protobuf:message-read 
	      (make-read-test-message-builder)
	      (open-bytevector-input-port (bv-proc)))))
      (test-assert (read-test-message? m))
      (test-equal "Test" (read-test-message-foo m)))))

(test-group "groups"
  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-varint bv-out (make-field-header 1 3))
    (protobuf:write-string bv-out "[group contents]")
    (protobuf:write-varint bv-out (make-field-header 1 4))
    (protobuf:write-varint bv-out (make-field-header 0 2))
    (protobuf:write-string bv-out "Test")
    (let ((m (protobuf:message-read 
	      (make-read-test-message-builder)
	      (open-bytevector-input-port (bv-proc)))))
      (test-assert (read-test-message? m))
      (test-equal "Test" (read-test-message-foo m)))))

(test-group "32-bit"
  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-varint bv-out (make-field-header 1 5))
    (protobuf:write-fixed32 bv-out 256)
    (protobuf:write-varint bv-out (make-field-header 0 2))
    (protobuf:write-string bv-out "Test")
    (let ((m (protobuf:message-read 
	      (make-read-test-message-builder)
	      (open-bytevector-input-port (bv-proc)))))
      (test-assert (read-test-message? m))
      (test-equal "Test" (read-test-message-foo m))))

  (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
    (protobuf:write-int32 bv-out -1)
    (let ((b (bv-proc)))
      (test-assert
       (bytevector=?
	b #vu8(#xff #xff #xff #xff #xff #xff #xff #xff #xff #x01))))))

(test-end "unknown-fields")
(test-end "read")

(test-begin "write")

(test-group "repeated"
  (test-group "primitive"
    (let* ((counter 0)
	   (decorated-int32-serializer
	    (lambda (p int32) 
	      (set! counter (+ counter 1)) (protobuf:write-int32 p int32)))

	   (ftd (protobuf:make-field-type-descriptor
		 "test" 'varint decorated-int32-serializer #f integer? 0))
	   
	   (m (protobuf:make-message
	       (list (protobuf:make-field
		      (protobuf:make-field-descriptor 0 "test" ftd #t #f #f)
		      (vector 1 2 3)))
	       (make-eqv-hashtable))))

      (let-values (((bv-out bv-proc) (open-bytevector-output-port)))
	(protobuf:message-write m bv-out)
	(test-equal 3 counter)))))

(test-end "write")

(test-begin "predicates")

(test-group "uint32"
  (let ((uint32? (protobuf:field-type-descriptor-predicate
		  protobuf:field-type-uint32)))
    (test-assert (uint32? 0))
    (test-assert (uint32? 4294967295))
    (test-assert (not (uint32? -1)))
    (test-assert (not (uint32? 0.5)))
    (test-assert (not (uint32? 4294967296)))))

(test-group "uint64"
  (let ((uint64? (protobuf:field-type-descriptor-predicate
		  protobuf:field-type-uint64)))
    (test-assert (uint64? 0))
    (test-assert (uint64? 18446744073709551615))
    (test-assert (not (uint64? -1)))
    (test-assert (not (uint64? 0.5)))
    (test-assert (not (uint64? 18446744073709551616)))))

(test-end "predicates")

(test-end "private")
