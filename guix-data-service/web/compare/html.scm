;;; Guix Data Service -- Information about Guix over time
;;; Copyright © 2019 Christopher Baines <mail@cbaines.net>
;;;
;;; This program is free software: you can redistribute it and/or
;;; modify it under the terms of the GNU Affero General Public License
;;; as published by the Free Software Foundation, either version 3 of
;;; the License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Affero General Public License for more details.
;;;
;;; You should have received a copy of the GNU Affero General Public
;;; License along with this program.  If not, see
;;; <http://www.gnu.org/licenses/>.

(define-module (guix-data-service web compare html)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (ice-9 vlist)
  #:use-module (guix-data-service web query-parameters)
  #:use-module (guix-data-service web view html)
  #:export (compare
            compare/derivations
            compare-by-datetime/derivations
            compare/packages
            compare-invalid-parameters))

(define (compare query-parameters
                 cgit-url-bases
                 new-packages
                 removed-packages
                 version-changes
                 lint-warnings-data)
  (define base-commit
    (assq-ref query-parameters 'base_commit))

  (define target-commit
    (assq-ref query-parameters 'target_commit))

  (define query-params
    (string-append "?base_commit=" base-commit
                   "&target_commit=" target-commit))

  (layout
   #:body
   `(,(header)
     (div
      (@ (class "container"))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-8"))
        (h1 "Comparing "
            (samp ,(string-take base-commit 8) "…")
            " and "
            (samp ,(string-take target-commit 8) "…"))
        ,@(if (apply string=? cgit-url-bases)
              `((a (@ (href ,(string-append
                              (first cgit-url-bases)
                              "log/?qt=range&q="
                              base-commit ".." target-commit)))
                   "(View cgit)"))
              '()))
       (div
        (@ (class "col-sm-4"))
        (div
         (@ (class "btn-group-vertical btn-group-lg pull-right")
            (style "margin-top: 2em;")
            (role "group"))
         (a (@ (class "btn btn-default")
               (href ,(string-append "/compare/packages" query-params)))
            "Compare packages")
         (a (@ (class "btn btn-default")
               (href ,(string-append "/compare/derivations" query-params)))
            "Compare derivations"))))
      (div
       (@ (class "row") (style "clear: left;"))
       (div
        (@ (class "col-sm-12"))
        (a (@ (class "btn btn-default btn-lg")
              (href ,(string-append
                      "/compare.json" query-params)))
           "View JSON")))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h3 (@ (style "clear: both;"))
            "New packages")
        ,(if (null? new-packages)
             '(p "No new packages")
             `(table
               (@ (class "table"))
               (thead
                (tr
                 (th (@ (class "col-md-4")) "Name")
                 (th (@ (class "col-md-4")) "Version")
                 (th (@ (class "col-md-4")) "")))
               (tbody
                ,@(map
                   (match-lambda
                     ((('name . name)
                       ('version . version))
                      `(tr
                        (td ,name)
                        (td ,version)
                        (td (@ (class "text-right"))
                            (a (@ (href ,(string-append
                                          "/revision/" target-commit
                                          "/package/" name "/" version)))
                               "More information")))))
                   new-packages))))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h3 "Removed packages")
        ,(if (null? removed-packages)
             '(p "No removed packages")
             `(table
               (@ (class "table"))
               (thead
                (tr
                 (th (@ (class "col-md-4")) "Name")
                 (th (@ (class "col-md-4")) "Version")
                 (th (@ (class "col-md-4")) "")))
               (tbody
                ,@(map
                   (match-lambda
                     ((('name . name)
                       ('version . version))
                      `(tr
                        (td ,name)
                        (td ,version)
                        (td (@ (class "text-right"))
                            (a (@ (href ,(string-append
                                          "/revision/" base-commit
                                          "/package/" name "/" version)))
                               "More information")))))
                   removed-packages))))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h3 "Version changes")
        ,(if
          (null? version-changes)
          '(p "No version changes")
          `(table
            (@ (class "table"))
            (thead
             (tr
              (th (@ (class "col-md-3")) "Name")
              (th (@ (class "col-md-9")) "Versions")))
            (tbody
             ,@(map
                (match-lambda
                  ((name . versions)
                   `(tr
                     (td ,name)
                     (td
                      (ul
                       ,@(map
                          (match-lambda
                            ((type . versions)
                             `(li (@ (class ,(if (eq? type 'base)
                                                 "text-danger"
                                                 "text-success")))
                                  (ul
                                   (@ (class "list-inline")
                                      (style "display: inline-block;"))
                                   ,@(map
                                      (lambda (version)
                                        `(li (a (@ (href
                                                    ,(string-append
                                                      "/revision/"
                                                      (if (eq? type 'base)
                                                          base-commit
                                                          target-commit)
                                                      "/package/"
                                                      name "/" version)))
                                                ,version)))
                                      (vector->list versions)))
                                  ,(if (eq? type 'base)
                                       " (old)"
                                       " (new)"))))
                          versions))))))
                version-changes))))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h2 "Lint warnings")
        ,@(if
           (null? lint-warnings-data)
           '((p "No lint warning changes"))
           (map
            (match-lambda
              (((package-name package-version) . warnings)
               `((h4 ,package-name " (version: " ,package-version ")")
                 (table
                  (@ (class "table"))
                  (thead
                   (tr
                    (th "")
                    (th "Linter")
                    (th "Message")))
                  (tbody
                   ,@(map (match-lambda
                            ((lint-checker-name
                              message
                              lint-checker-description
                              lint-checker-network-dependent
                              file line column-number ;; TODO Maybe use the location?
                              change)

                             `(tr
                               (td (@ (class ,(if (string=? change "new")
                                                  "text-danger"
                                                  "text-success"))
                                      (style "font-weight: bold"))
                                   ,(if (string=? change "new")
                                        "New warning"
                                        "Resolved warning"))
                               (td (span (@ (style "font-family: monospace; display: block;"))
                                         ,lint-checker-name)
                                   (p (@ (style "font-size: small; margin: 6px 0 0px;"))
                                      ,lint-checker-description))
                               (td ,message))))
                          warnings))))))
            lint-warnings-data))))))))

(define (compare/derivations query-parameters
                             valid-systems
                             valid-build-statuses
                             derivation-changes)
  (layout
   #:body
   `(,(header)
     (div
      (@ (class "container"))
      (div
       (@ (class "row"))
       (h1 ,@(let ((base-commit (assq-ref query-parameters 'base_commit))
                   (target-commit (assq-ref query-parameters 'target_commit)))
               (if (every string? (list base-commit target-commit))
                   `("Comparing "
                     (samp ,(string-take base-commit 8) "…")
                     " and "
                     (samp ,(string-take target-commit 8) "…"))
                   '("Comparing derivations")))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-md-12"))
        (div
         (@ (class "well"))
         (form
          (@ (method "get")
             (action "")
             (class "form-horizontal"))
          ,(form-horizontal-control
            "Base commit" query-parameters
            #:required? #t
            #:help-text "The commit to use as the basis for the comparison."
            #:font-family "monospace")
          ,(form-horizontal-control
            "Target commit" query-parameters
            #:required? #t
            #:help-text "The commit to compare against the base commit."
            #:font-family "monospace")
          ,(form-horizontal-control
            "System" query-parameters
            #:options valid-systems
            #:help-text "Only include derivations for this system."
            #:font-family "monospace")
          ,(form-horizontal-control
            "Target" query-parameters
            #:options valid-systems
            #:help-text "Only include derivations that are build for this system."
            #:font-family "monospace")
          (div (@ (class "form-group form-group-lg"))
               (div (@ (class "col-sm-offset-2 col-sm-10"))
                    (button (@ (type "submit")
                               (class "btn btn-lg btn-primary"))
                            "Update results")))
          (a (@ (class "btn btn-default btn-lg pull-right")
                (href ,(let ((query-parameter-string
                              (query-parameters->string query-parameters)))
                         (string-append
                          "/compare/derivations.json"
                          (if (string-null? query-parameter-string)
                              ""
                              (string-append "?" query-parameter-string))))))
             "View JSON")))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h3 "Package derivation changes")
        ,(if
          (null? derivation-changes)
          '(p "No derivation changes")
          `(table
            (@ (class "table")
               (style "table-layout: fixed;"))
            (thead
             (tr
              (th "Name")
              (th "Version")
              (th "System")
              (th "Target")
              (th (@ (class "col-xs-5")) "Derivations")))
            (tbody
             ,@(append-map
                (match-lambda
                  ((('name . name)
                    ('version . version)
                    ('base . base-derivations)
                    ('target . target-derivations))
                   (let* ((system-and-versions
                           (delete-duplicates
                            (append (map (lambda (details)
                                           (cons (assq-ref details 'system)
                                                 (assq-ref details 'target)))
                                         (vector->list base-derivations))
                                    (map (lambda (details)
                                           (cons (assq-ref details 'system)
                                                 (assq-ref details 'target)))
                                         (vector->list target-derivations)))))
                          (data-columns
                           (map
                            (match-lambda
                              ((system . target)
                               (let ((base-derivation-file-name
                                      (assq-ref (find (lambda (details)
                                                        (and (string=? (assq-ref details 'system) system)
                                                             (string=? (assq-ref details 'target) target)))
                                                      (vector->list base-derivations))
                                                'derivation-file-name))
                                     (target-derivation-file-name
                                      (assq-ref (find (lambda (details)
                                                        (and (string=? (assq-ref details 'system) system)
                                                             (string=? (assq-ref details 'target) target)))
                                                      (vector->list target-derivations))
                                                'derivation-file-name)))
                                 `((td (samp (@ (style "white-space: nowrap;"))
                                             ,system))
                                   (td (samp (@ (style "white-space: nowrap;"))
                                             ,target))
                                   (td ,@(if base-derivation-file-name
                                             `((a (@ (style "display: block;")
                                                     (href ,base-derivation-file-name))
                                                  (span (@ (class "text-danger glyphicon glyphicon-minus pull-left")
                                                           (style "font-size: 1.5em; padding-right: 0.4em;")))
                                                  ,(display-store-item-short base-derivation-file-name)))
                                             '())
                                       ,@(if target-derivation-file-name
                                             `((a (@ (style "display: block; clear: left;")
                                                     (href ,target-derivation-file-name))
                                                  (span (@ (class "text-success glyphicon glyphicon-plus pull-left")
                                                           (style "font-size: 1.5em; padding-right: 0.4em;")))
                                                  ,(and=> target-derivation-file-name display-store-item-short)))
                                             '()))))))
                            system-and-versions)))

                     `((tr (td (@ (rowspan , (length system-and-versions)))
                               ,name)
                           (td (@ (rowspan , (length system-and-versions)))
                               ,version)
                           ,@(car data-columns))
                       ,@(map (lambda (data-row)
                                `(tr ,data-row))
                              (cdr data-columns))))))
                (vector->list derivation-changes)))))))))))

(define (compare-by-datetime/derivations query-parameters
                                         valid-systems
                                         valid-build-statuses
                                         base-revision-details
                                         target-revision-details
                                         derivation-changes)
  (layout
   #:body
   `(,(header)
     (div
      (@ (class "container"))
      (div
       (@ (class "row"))
       (h1 ,@(let ((base-commit (assq-ref query-parameters 'base_commit))
                   (target-commit (assq-ref query-parameters 'target_commit)))
               (if (every string? (list base-commit target-commit))
                   `("Comparing "
                     (samp ,(string-take base-commit 8) "…")
                     " and "
                     (samp ,(string-take target-commit 8) "…"))
                   '("Comparing derivations")))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-md-12"))
        (div
         (@ (class "well"))
         (form
          (@ (method "get")
             (action "")
             (class "form-horizontal"))
          ,(form-horizontal-control
            "Base branch" query-parameters
            #:required? #t
            #:help-text "The branch to compare from."
            #:font-family "monospace")
          ,(form-horizontal-control
            "Base datetime" query-parameters
            #:required? #t
            #:help-text "The date and time to compare from."
            #:font-family "monospace")
          ,(form-horizontal-control
            "Target branch" query-parameters
            #:required? #t
            #:help-text "The branch to compare to."
            #:font-family "monospace")
          ,(form-horizontal-control
            "Target datetime" query-parameters
            #:required? #t
            #:help-text "The date and time to compare to."
            #:font-family "monospace")
          ,(form-horizontal-control
            "System" query-parameters
            #:options valid-systems
            #:help-text "Only include derivations for this system."
            #:font-family "monospace")
          ,(form-horizontal-control
            "Target" query-parameters
            #:options valid-systems
            #:help-text "Only include derivations that are build for this system."
            #:font-family "monospace")
          (div (@ (class "form-group form-group-lg"))
               (div (@ (class "col-sm-offset-2 col-sm-10"))
                    (button (@ (type "submit")
                               (class "btn btn-lg btn-primary"))
                            "Update results")))
          (a (@ (class "btn btn-default btn-lg pull-right")
                (href ,(let ((query-parameter-string
                              (query-parameters->string query-parameters)))
                         (string-append
                          "/compare/derivations.json"
                          (if (string-null? query-parameter-string)
                              ""
                              (string-append "?" query-parameter-string))))))
             "View JSON")))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (div
         (a (@ (href ,(string-append "/revision/" (second base-revision-details))))
            "Base revision: " ,(second base-revision-details)))
        (div
         (a (@ (href ,(string-append "/revision/" (second target-revision-details))))
            "Target revision: " ,(second target-revision-details)))
        (h3 "Package derivation changes")
        ,(if
          (null? derivation-changes)
          '(p "No derivation changes")
          `(table
            (@ (class "table")
               (style "table-layout: fixed;"))
            (thead
             (tr
              (th "Name")
              (th "Version")
              (th "System")
              (th "Target")
              (th (@ (class "col-xs-5")) "Derivations")))
            (tbody
             ,@(append-map
                (match-lambda
                  ((('name . name)
                    ('version . version)
                    ('base . base-derivations)
                    ('target . target-derivations))
                   (let* ((system-and-versions
                           (delete-duplicates
                            (append (map (lambda (details)
                                           (cons (assq-ref details 'system)
                                                 (assq-ref details 'target)))
                                         (vector->list base-derivations))
                                    (map (lambda (details)
                                           (cons (assq-ref details 'system)
                                                 (assq-ref details 'target)))
                                         (vector->list target-derivations)))))
                          (data-columns
                           (map
                            (match-lambda
                              ((system . target)
                               (let ((base-derivation-file-name
                                      (assq-ref (find (lambda (details)
                                                        (and (string=? (assq-ref details 'system) system)
                                                             (string=? (assq-ref details 'target) target)))
                                                      (vector->list base-derivations))
                                                'derivation-file-name))
                                     (target-derivation-file-name
                                      (assq-ref (find (lambda (details)
                                                        (and (string=? (assq-ref details 'system) system)
                                                             (string=? (assq-ref details 'target) target)))
                                                      (vector->list target-derivations))
                                                'derivation-file-name)))
                                 `((td (samp (@ (style "white-space: nowrap;"))
                                             ,system))
                                   (td (samp (@ (style "white-space: nowrap;"))
                                             ,target))
                                   (td ,@(if base-derivation-file-name
                                             `((a (@ (style "display: block;")
                                                     (href ,base-derivation-file-name))
                                                  (span (@ (class "text-danger glyphicon glyphicon-minus pull-left")
                                                           (style "font-size: 1.5em; padding-right: 0.4em;")))
                                                  ,(display-store-item-short base-derivation-file-name)))
                                             '())
                                       ,@(if target-derivation-file-name
                                             `((a (@ (style "display: block; clear: left;")
                                                     (href ,target-derivation-file-name))
                                                  (span (@ (class "text-success glyphicon glyphicon-plus pull-left")
                                                           (style "font-size: 1.5em; padding-right: 0.4em;")))
                                                  ,(and=> target-derivation-file-name display-store-item-short)))
                                             '()))))))
                            system-and-versions)))

                     `((tr (td (@ (rowspan , (length system-and-versions)))
                               ,name)
                           (td (@ (rowspan , (length system-and-versions)))
                               ,version)
                           ,@(car data-columns))
                       ,@(map (lambda (data-row)
                                `(tr ,data-row))
                              (cdr data-columns))))))
                (vector->list derivation-changes)))))))))))

(define (compare/packages query-parameters
                          base-packages-vhash
                          target-packages-vhash)
  (define base-commit
    (assq-ref query-parameters 'base_commit))

  (define target-commit
    (assq-ref query-parameters 'target_commit))

  (define query-params
    (string-append "?base_commit=" base-commit
                   "&target_commit=" target-commit))

  (layout
   #:body
   `(,(header)
     (div
      (@ (class "container"))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h1 "Comparing "
            (samp ,(string-take base-commit 8) "…")
            " and "
            (samp ,(string-take target-commit 8) "…"))
        (a (@ (class "btn btn-default btn-lg")
              (href ,(string-append
                      "/compare/packages.json" query-params)))
           "View JSON")))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h3 "Base ("
            (samp ,base-commit)
            ")")
        (p "Packages found in the base revision.")
        (table
         (@ (class "table"))
         (thead
          (tr
           (th (@ (class "col-md-4")) "Name")
           (th (@ (class "col-md-4")) "Version")
           (th (@ (class "col-md-4")) "")))
         (tbody
          ,@(map
             (match-lambda
               ((name version)
                `(tr
                  (td ,name)
                  (td ,version)
                  (td (@ (class "text-right"))
                      (a (@ (href ,(string-append
                                    "/revision/" base-commit
                                    "/package/" name "/" version)))
                         "More information")))))
             (delete-duplicates
              (map (lambda (data)
                     (take data 2))
                   (vlist->list base-packages-vhash))))))))
      (div
       (@ (class "row"))
       (div
        (@ (class "col-sm-12"))
        (h3 "Target ("
            (samp ,target-commit)
            ")")
        (p "Packages found in the target revision.")
        (table
         (@ (class "table"))
         (thead
          (tr
           (th (@ (class "col-md-4")) "Name")
           (th (@ (class "col-md-4")) "Version")
           (th (@ (class "col-md-4")) "")))
         (tbody
          ,@(map
             (match-lambda
               ((name version)
                `(tr
                  (td ,name)
                  (td ,version)
                  (td (@ (class "text-right"))
                      (a (@ (href ,(string-append
                                    "/revision/" target-commit
                                    "/package/" name "/" version)))
                         "More information")))))
             (delete-duplicates
              (map (lambda (data)
                     (take data 2))
                   (vlist->list target-packages-vhash))))))))))))

(define (compare-invalid-parameters query-parameters
                                    base-job
                                    target-job)
  (define base-commit
    (assq-ref query-parameters 'base_commit))

  (define target-commit
    (peek (assq-ref query-parameters 'target_commit)))

  (layout
   #:body
   `(,(header)
     (div (@ (class "container"))
          (h1 "Unknown commit")
          ,(if (invalid-query-parameter? base-commit)
               `(p "No known revision with commit "
                   (strong (samp ,(invalid-query-parameter-value base-commit)))
                   ,(if (null? base-job)
                        " and it is not currently queued for processing"
                        " but it is queued for processing"))
               '())
          ,(if (invalid-query-parameter? target-commit)
               `(p "No known revision with commit "
                   (strong (samp ,(invalid-query-parameter-value target-commit)))
                   ,(if (null? target-job)
                        " and it is not currently queued for processing"
                        " but it is queued for processing"))
               '())))))