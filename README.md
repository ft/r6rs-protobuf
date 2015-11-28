Protocol Buffers for R6RS Scheme
================================

What is it?
-----------

This project provides a pure Scheme implementation of Protocol Buffers, including parsing and code generation. Visit the Protocol Buffers [project page](https://developers.google.com/protocol-buffers/) for information about the Protocol Buffers description language and the Protocol Buffers wire protocol.

Latest Updates
--------------

<https://gitlab.com/joolean/r6rs-protobuf/blob/master/CHANGELOG.txt>

Documentation
-------------

Read the [documentation](https://gitlab.com/joolean/r6rs-protobuf/blob/master/HOWTO).

Quick Example
-------------

You write a .proto file like this

    package protobuf.person;

    message Person {
      required int32 id = 1;
      required string name = 2;
      optional string email = 3;
    }

and compile it like this

    (import (protobuf compile))
    (define proto (protoc:read-proto (open-input-file "Person.proto")))
    (protoc:generate-libraries proto)

to produce an R6RS library form like this

    (library (protobuf person)
      (export make-Person-builder     
              Person-builder?
              Person-builder-build
          
              Person-builder-id
              set-Person-builder-id!
              has-Person-builder-id?
              clear-Person-builder-id!

              Person-builder-name
              set-Person-builder-name!
              has-Person-builder-name?
              clear-Person-builder-name!

              Person-builder-email
              set-Person-builder-email!
              has-Person-builder-email?
              clear-Person-builder-email!

              Person-builder-extension
              set-Person-builder-extension!
              has-Person-builder-extension?
              clear-Person-builder-extension!

              Person?
              Person-id
              Person-name
              Person-email
              has-Person-email?

              has-Person-extension?
              Person-extension

              Person-read
              Person-write)

      (import (rnrs base)
              (rnrs enums)
              (rnrs records syntactic)
              (protobuf private))

      ...
    )
