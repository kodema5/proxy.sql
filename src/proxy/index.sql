drop schema if exists proxy cascade;
create schema proxy;
create type proxy.url_t as (
    hash text,
    host text,
    hostname text,
    href text,
    password text,
    pathname text,
    port text,
    protocol text,
    search text,
    search_params jsonb,
    username text
);

create type proxy.route_it as (
    url proxy.url_t,
    method text,
    headers jsonb,
    cookies jsonb,
    jwt jsonb -- system generated
);

create type proxy.route_t as (
    id text,
    url text,
    status int,
    body jsonb,
    headers jsonb,
    method text
);

\ir log.sql
\ir route.sql
\ir route_host.sql

\if :test
    insert into _proxy.route (
        pathname,
        fn,
        arg,
        jwt_header_name
    ) values
        ('/', 'proxy.route_host(_proxy.route, proxy.route_it)'::regprocedure, default, default),
        ('/http-bin', 'proxy.route_host(_proxy.route, proxy.route_it)'::regprocedure, '{"host":"https://httpbin.org"}'::jsonb, null)
        ;

    insert into _jwt.key(id, value)
    values
        (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
        (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
        (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
        (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text));


    create function tests.test_jwt() returns setof text language plpgsql as $$
    declare
        req jsonb;
        rut jsonb;
    begin
        req = jsonb_build_object(
            'headers', jsonb_build_object(
                'x-authorization', jwt.encode(jsonb_build_object('sid', 'abc'))
            )
        );
        rut = proxy.web_route(req);
        return next ok(rut->'headers'->'x-auth'->>'sid' = 'abc', 'parses jwt');
    end;
    $$;
\endif


-- -- create function proxy.log (
-- --     req proxy.route_it,
-- --     rut proxy.route_t
-- -- )
-- --     returns proxy.route_t
-- --     language plpgsql
-- --     security definer
-- -- as $$
-- -- declare
-- --     l _proxy.log;
-- -- begin
-- --     insert into _proxy.log (req, rut)
-- --     values (
-- --         to_jsonb(req),
-- --         to_jsonb(rut)
-- --     )
-- --     returning * into l;

-- --     rut.id = l.id;
-- --     return rut;
-- -- end;
-- -- $$;

-- -- create function proxy.log (
-- --     id_ text,
-- --     res_ jsonb
-- -- )
-- --     returns void
-- --     language plpgsql
-- --     security definer
-- -- as $$
-- -- begin
-- --     update _proxy.log
-- --     set
-- --         res = res_,
-- --         end_tz = current_timestamp
-- --     where id = id_;
-- -- end;
-- -- $$;

-- create function proxy.route (
--     req proxy.route_it
-- )
--     returns proxy.route_t
--     language plpgsql
--     security definer
-- as $$
-- declare
--     rut proxy.route_t;
--     rec _proxy.route;
--     jwt jsonb;
-- begin
--     select *
--     into rec
--     from _proxy.route a
--     where coalesce((req.url).pathname, '/') like (a.pathname || '%')
--     order by length(a.pathname) desc
--     limit 1;

--     if rec is null then
--         raise warning 'unable to route %', (req.url).pathname;
--         rut.status = 404;
--         return proxy.log(req, rut);
--     end if;

--     -- checks for jwt/auth
--     if rec.jwt_header_name is not null then
--         req.jwt = jwt.decode( (req.headers)->>rec.jwt_header_name);
--         if req.jwt is null then
--             rut.status = 401;
--             rut.body = jsonb_build_object('error', 'unauthorized');
--             return proxy.log(req, rut);
--         end if;
--     end if;


--     -- redirection
--     begin
--         -- select (%s($1)).* made multi-calls
--         -- approach needed to avoid multi-calls
--         --
--         execute format(
--             'select (fn.a).* from (select %s($1, $2) as a) fn',
--             (rec.fn)::regproc
--         )
--         into rut
--         using rec, req;

--         return proxy.log(req, rut);
--     exception
--         when others then
--             rut.status = 500;
--             rut.body = jsonb_build_object('error', sqlerrm);
--             return proxy.log(req, rut);
--     end;
-- end;
-- $$;

-- create function proxy.route (
--     req jsonb
-- )
--     returns proxy.route_t
--     language sql
--     security definer
--     stable
-- as $$
--     select proxy.route(jsonb_populate_record(
--         null::proxy.route_it,
--         req
--     ))
-- $$;

-- create function proxy.web_route (
--     req jsonb
-- )
--     returns jsonb
--     language sql
--     security definer
-- as $$
--     select to_jsonb(proxy.route(req))
-- $$;

-- create type proxy.route_arg_t as (
--     host text
-- );

-- create function proxy.route (
--     rec _proxy.route,
--     req proxy.route_it
-- )
--     returns proxy.route_t
--     language plpgsql
--     security definer
-- as $$
-- declare
--     rut proxy.route_t;
--     arg proxy.route_arg_t = jsonb_populate_record(null::proxy.route_arg_t, rec.arg);
--     qry text = coalesce((req.url).search, '');
--     a jsonb;
-- begin
--     rut.url = arg.host -- 'https://httpbin.org'
--         || replace((req.url).pathname, rec.pathname, '')
--         || qry;

--     if req.jwt is not null then
--         rut.headers = jsonb_build_object('x-auth', req.jwt);
--     end if;

--     rut.status = 0;
--     return rut;
-- end;
-- $$;

-- \if :test
--     insert into _proxy.route (
--         pathname,
--         fn,
--         arg,
--         jwt_header_name
--     ) values
--         ('/', 'proxy.route(_proxy.route, proxy.route_it)'::regprocedure, default, default),
--         ('/http-bin', 'proxy.route(_proxy.route, proxy.route_it)'::regprocedure, '{"host":"https://httpbin.org"}'::jsonb, null)
--         ;

--     insert into _jwt.key(id, value)
--     values
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text));


--     create function tests.test_routing() returns setof text language plpgsql as $$
--     declare
--         req jsonb;
--         rut jsonb;
--     begin
--         req = jsonb_build_object(
--             'headers', jsonb_build_object(
--                 'x-authorization', jwt.encode(jsonb_build_object('sid', 'abc'))
--             )
--         );
--         rut = proxy.web_route(req);
--         return next ok(rut->'headers'->'x-auth'->>'sid' = 'abc', 'parses jwt');
--     end;
--     $$;
-- \endif
