\if :{?proxy_sql}
\else
\set proxy_sql true


\set skip_test false
\if :test
    \set skip_test true
    \set test false
\endif
\ir jwt.sql/jwt.sql
\if :skip_test
    \set test true
\endif

\ir src/_proxy/index.sql
\ir src/proxy/index.sql

\endif