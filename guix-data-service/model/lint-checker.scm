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

(define-module (guix-data-service model lint-checker)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (squee)
  #:use-module (guix-data-service model utils)
  #:export (lint-checkers->lint-checker-ids
            lint-warning-count-by-lint-checker-for-revision
            insert-guix-revision-lint-checkers
            lint-checkers-for-revision))

(define (lint-checkers->lint-checker-ids conn lint-checkers-data)
  (insert-missing-data-and-return-all-ids
   conn
   "lint_checkers"
   '(name description network_dependent)
   lint-checkers-data))

(define (lint-warning-count-by-lint-checker-for-revision conn commit-hash)
  (define query
    "
SELECT lint_checkers.name, lint_checkers.description,
       lint_checkers.network_dependent, revision_data.count
FROM lint_checkers
INNER JOIN (
  SELECT lint_checker_id, COUNT(*)
  FROM lint_warnings
  WHERE id IN (
    SELECT lint_warning_id
    FROM guix_revision_lint_warnings
    INNER JOIN guix_revisions
    ON guix_revision_lint_warnings.guix_revision_id = guix_revisions.id
    WHERE commit = $1
  )
  GROUP BY lint_checker_id
) AS revision_data ON lint_checkers.id = revision_data.lint_checker_id
ORDER BY count DESC")

  (exec-query conn query (list commit-hash)))

(define (insert-guix-revision-lint-checkers conn
                                            guix-revision-id
                                            lint-checker-ids)
  (exec-query
   conn
   (string-append
    "INSERT INTO guix_revision_lint_checkers (lint_checker_id, guix_revision_id) "
    "VALUES "
    (string-join
     (map (lambda (lint-checker-id)
            (simple-format
             #f
             "(~A, ~A)"
             lint-checker-id
             guix-revision-id))
          lint-checker-ids)
     ", "))))

(define (lint-checkers-for-revision conn commit-hash)
  (exec-query
   conn
   "
SELECT name, description, network_dependent
FROM lint_checkers
WHERE id IN (
  SELECT lint_checker_id
  FROM guix_revision_lint_checkers
  INNER JOIN guix_revisions
    ON guix_revisions.id = guix_revision_lint_checkers.guix_revision_id
  WHERE commit = $1
)"
   (list commit-hash)))
