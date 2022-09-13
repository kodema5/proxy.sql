\if :test
\if :local
drop schema if exists _proxy cascade;
\endif
\endif
create schema if not exists _proxy;

create table if not exists _proxy.route (
    pathname text unique primary key,

    fn regprocedure, -- fn (_proxy.route, proxy.route_it) returns proxy.route_t
    arg jsonb default '{}'::jsonb,

    jwt_header_name text default 'x-authorization'
);

create table if not exists _proxy.log (
    id text default md5(uuid_generate_v4()::text),
    req jsonb,
    rut jsonb,
    begin_tz timestamp with time zone default current_timestamp,

    res jsonb,
    end_tz timestamp with time zone
);
