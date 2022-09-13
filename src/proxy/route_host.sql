-- route request to a host determined in arg
--
create type proxy.route_host_it as (
    host text
);

create function proxy.route_host (
    rec _proxy.route,
    req proxy.route_it
)
    returns proxy.route_t
    language plpgsql
    security definer
as $$
declare
    rut proxy.route_t;
    arg proxy.route_host_it = jsonb_populate_record(null::proxy.route_host_it, rec.arg);
    qry text = coalesce((req.url).search, '');
    a jsonb;
begin
    rut.url = arg.host -- 'https://httpbin.org'
        || replace((req.url).pathname, rec.pathname, '')
        || qry;

    if req.jwt is not null then
        rut.headers = jsonb_build_object('x-auth', req.jwt);
    end if;

    rut.status = 0;
    return rut;
end;
$$;