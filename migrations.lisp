(in-package #:clsql-helper)
(clsql-sys:file-enable-sql-reader-syntax)

(defvar *migration-table-name* "clsql_helper_migrations"
  "the table name to use for migrations")

(defun ensure-migration-table ()
  (unless (clsql-sys:table-exists-p *migration-table-name*)
    (clsql-sys:create-table
     *migration-table-name*
     '(([hash] longchar :not-null :unique)
       ([query] longchar :not-null)
       ([date-entered] clsql-sys:wall-time :not-null)))))

(defun migration-done-p (hash)
  (clsql:select [date-entered] :from *migration-table-name*
                :where [= [hash] hash]
                :flatp T))

(defun sql-hash (sql-statement)
  (format nil "~{~x~}"
          (coerce (md5:md5sum-sequence sql-statement) 'list)))

(defun migrate (sql-statement &aux (hash (sql-hash sql-statement)))
  (unless (migration-done-p hash)
    (with-simple-restart (continue "Ignore error, consider this migration done.")
      (clsql-sys:execute-command sql-statement))
    (clsql-sys:insert-records
     :into *migration-table-name*
     :attributes (list [hash] [query] [date-entered])
     :values (list hash sql-statement (clsql-helper:current-sql-time)))))

(defun migrations (&rest sql-statements)
  (unless clsql-sys:*default-database* (error "must have a database connection open."))
  (ensure-migration-table)
  (mapc #'migrate (alexandria:flatten sql-statements)))