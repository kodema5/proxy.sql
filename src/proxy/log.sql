-- starts a log
--
create function proxy.log (
    req proxy.route_it,
    rut proxy.route_t
)
    returns proxy.route_t
    language plpgsql
    security definer
as $$
declare
    l _proxy.log;
begin
    insert into _proxy.log (req, rut)
    values (
        to_jsonb(req),
        to_jsonb(rut)
    )
    returning * into l;

    rut.id = l.id;
    return rut;
end;
$$;

-- ends a log
--
create function proxy.log (
    id_ text,
    res_ jsonb
)
    returns void
    language plpgsql
    security definer
as $$
begin
    update _proxy.log
    set
        res = res_,
        end_tz = current_timestamp
    where id = id_;
end;
$$;