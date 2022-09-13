-- authenticate and route a request
--
create function proxy.route (
    req proxy.route_it
)
    returns proxy.route_t
    language plpgsql
    security definer
as $$
declare
    rut proxy.route_t;
    rec _proxy.route;
    jwt jsonb;
begin
    select *
    into rec
    from _proxy.route a
    where coalesce((req.url).pathname, '/') like (a.pathname || '%')
    order by length(a.pathname) desc
    limit 1;

    if rec is null then
        raise warning 'unable to route %', (req.url).pathname;
        rut.status = 404;
        return proxy.log(req, rut);
    end if;

    -- checks for jwt/auth
    if rec.jwt_header_name is not null then
        req.jwt = jwt.decode( (req.headers)->>rec.jwt_header_name);
        if req.jwt is null then
            rut.status = 401;
            rut.body = jsonb_build_object('error', 'unauthorized');
            return proxy.log(req, rut);
        end if;
    end if;


    -- routing
    begin
        execute format(
            'select (fn.a).* from (select %s($1, $2) as a) fn',
            (rec.fn)::regproc
        )
        into rut
        using rec, req;

        -- start a log
        return proxy.log(req, rut);
    exception
        when others then
            rut.status = 500;
            rut.body = jsonb_build_object('error', sqlerrm);
            return proxy.log(req, rut);
    end;
end;
$$;

create function proxy.route (
    req jsonb
)
    returns proxy.route_t
    language sql
    security definer
    stable
as $$
    select proxy.route(jsonb_populate_record(
        null::proxy.route_it,
        req
    ))
$$;

create function proxy.web_route (
    req jsonb
)
    returns jsonb
    language sql
    security definer
as $$
    select to_jsonb(proxy.route(req))
$$;




-- create type proxy.route_host_it as (
--     host text
-- );

-- create function proxy.route_host (
--     rec _proxy.route,
--     req proxy.route_it
-- )
--     returns proxy.route_t
--     language plpgsql
--     security definer
-- as $$
-- declare
--     rut proxy.route_t;
--     arg proxy.route_host_it = jsonb_populate_record(null::proxy.route_host_it, rec.arg);
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
--         ('/', 'proxy.route_host(_proxy.route, proxy.route_it)'::regprocedure, default, default),
--         ('/http-bin', 'proxy.route_host(_proxy.route, proxy.route_it)'::regprocedure, '{"host":"https://httpbin.org"}'::jsonb, null)
--         ;

--     insert into _jwt.key(id, value)
--     values
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text)),
--         (md5(uuid_generate_v4()::text), md5(uuid_generate_v4()::text));


--     create function tests.test_jwt() returns setof text language plpgsql as $$
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
