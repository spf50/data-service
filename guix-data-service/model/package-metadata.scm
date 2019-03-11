(define-module (guix-data-service model package-metadata)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 vlist)
  #:use-module (ice-9 match)
  #:use-module (squee)
  #:use-module (gcrypt hash)
  #:use-module (rnrs bytevectors)
  #:use-module (guix base16)
  #:use-module (guix inferior)
  #:use-module (guix-data-service model utils)
  #:export (select-package-metadata
            select-package-metadata-by-revision-name-and-version
            insert-package-metadata
            inferior-packages->package-metadata-ids))

(define (select-package-metadata hashes)
  (string-append "SELECT id, sha1_hash "
                 "FROM package_metadata "
                 "WHERE sha1_hash IN ("
                 (string-join (map (lambda (hash)
                                     (simple-format #f "'~A'" hash))
                                   hashes)
                              ",")
                 ");"))

(define (select-package-metadata-by-revision-name-and-version
         conn revision-commit-hash name version)
  (define query "
SELECT package_metadata.synopsis, package_metadata.description,
  package_metadata.home_page
FROM package_metadata
INNER JOIN packages
  ON package_metadata.id = packages.package_metadata_id
WHERE packages.id IN (
  SELECT package_derivations.package_id
  FROM package_derivations
  INNER JOIN guix_revision_package_derivations
    ON package_derivations.id =
    guix_revision_package_derivations.package_derivation_id
  INNER JOIN guix_revisions
    ON guix_revision_package_derivations.revision_id = guix_revisions.id
  WHERE guix_revisions.commit = $1
)
  AND packages.name = $2
  AND packages.version = $3")

  (exec-query conn query (list revision-commit-hash name version)))

(define (insert-package-metadata metadata-rows)
  (string-append "INSERT INTO package_metadata "
                 "(sha1_hash, synopsis, description, home_page) "
                 "VALUES "
                 (string-join
                  (map (match-lambda
                         ((sha1_hash synopsis description home_page)
                          (string-append
                           "('" sha1_hash "',"
                           (value->quoted-string-or-null synopsis) ","
                           (value->quoted-string-or-null description) ","
                           (value->quoted-string-or-null home_page) ")")))
                       metadata-rows)
                  ",")
                 " RETURNING id"
                 ";"))


(define (inferior-packages->package-metadata-ids conn packages)
  (define package-metadata
    (map (lambda (package)
           (let ((data (list (inferior-package-synopsis package)
                             (inferior-package-description package)
                             (inferior-package-home-page package))))
             `(,(bytevector->base16-string
                 (sha1 (string->utf8
                        (string-join
                         (map (lambda (d)
                                (cond
                                 ((string? d) d)
                                 ((boolean? d) (simple-format #f "~A" d))
                                 (else d)))
                              data)
                         ":"))))
               ,@data)))
         packages))

  (define package-metadata-hashes
    (map first package-metadata))

  (let* ((existing-package-metadata-entries
          (exec-query->vhash conn
                             (select-package-metadata
                              package-metadata-hashes)
                             second ;; sha1_hash
                             first)) ;; id))
         (missing-package-metadata-entries
          (delete-duplicates
           (filter (lambda (metadata)
                     (not (vhash-assoc (first metadata)
                                       existing-package-metadata-entries)))
                   package-metadata)))
         (new-package-metadata-entries
          (if (null? missing-package-metadata-entries)
              '()
              (map car (exec-query conn
                                   (insert-package-metadata
                                    missing-package-metadata-entries)))))
         (new-entries-id-lookup-vhash
          (two-lists->vhash (map first missing-package-metadata-entries)
                            new-package-metadata-entries)))

    (map (lambda (sha1-hash)
           (cdr
            (or (vhash-assoc sha1-hash
                             existing-package-metadata-entries)
                (vhash-assoc sha1-hash
                             new-entries-id-lookup-vhash)
                (begin
                  sha1-hash
                  (error "missing package-metadata entry")))))
         package-metadata-hashes)))
