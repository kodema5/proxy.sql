
// deno run --watch -A --unstable app.js

// configuration flags
//
//
import { config } from "https://deno.land/x/dotenv/mod.ts"
import { parse } from "https://deno.land/std@0.134.0/flags/mod.ts";
let ConfigFlags = {
    p: 'PORT',
    debug: 'PGDEBUG',
}
let Config = Object.assign(
    // application default values
    //
    {
        PORT: 8080,             // listens to

        PGHOST: 'localhost',    // pg connections
        PGPORT: 5432,
        PGDATABASE: 'web',
        PGUSER: 'web',
        PGPASSWORD: 'rei',
        PGPOOLSIZE: 10,
        PGIDLE_TIMEOUT: 0,      // in s
        PGCONNECT_TIMEOUT: 30,  // in s
    },

    // read from .env / .env.defaults
    //
    config(),

    // command line arguments
    //
    Object.entries(parse(Deno.args))
        .map( ([k,v]) => ({
            [ConfigFlags[k] || k.toUpperCase().replaceAll('-','_')] : v
        }))
        .reduce((x,a) => Object.assign(x,a), {})
)

// postgres API
//
//
import postgres from 'https://deno.land/x/postgresjs/mod.js'
const sql = postgres({
    host: Config.PGHOST,
    port: Config.PGPORT,
    user: Config.PGUSER,
    pass: Config.PGPASSWORD,
    database: Config.PGDATABASE,

    max: Config.PGPOOLSIZE,
    idle_timeout: Config.PGIDLE_TIMEOUT,
    connect_timeout: Config.PGCONNECT_TIMEOUT,

    onnotice: (msg) => console.log(msg.severity, msg.message),
})

// routing
//
let route = async (req) => {
    let s = `select proxy.web_route('${
        JSON.stringify(req)
    }'::jsonb) as x`
    return (await sql.unsafe(s))?.[0]?.x || {}
}

// logging result
//
let log = async (id, res) => {
    let s = `select proxy.log('${id}', '${
        JSON.stringify(res)
    }'::jsonb) as x`
    return (await sql.unsafe(s))?.[0]?.x || {}
}

// http-server
//
//
import { serve, getCookies, } from "https://deno.land/std@0.153.0/http/mod.ts";
console.log(`HTTP webserver running. Access it at: http://localhost:${Config.PORT}/`)
/* await */ serve(

    async (req, connInfo) => {
        let hs = Object.fromEntries(req.headers.entries())
        let u = new URL(req.url)
        let {
            id:reqId, url, method, headers,
            status, body,
        } = await route({
            url: {
                href: u.href,
                hash: u.hash,
                host: u.host,
                hostname: u.host,
                origin: u.origin,
                password: u.password,
                pathname: u.pathname,
                protocol: u.protocol,
                search: u.search,
                search_params: Object.fromEntries(u.searchParams.entries()),
                username: u.username,
            },
            method: req.method,
            headers: hs,
            cookies: getCookies(req.headers),
            origin: connInfo?.remoteAddr?.hostname,
            // body is not passed for size/performance
        })

        console.log('> routing', req.method, req.url, 'to', url)

        // early termination
        if (status>0) {
            return new Response(typeof body==='object' ? JSON.stringify(body) : body, { status: status || 404 })
        }

        // unknown path
        if (!url) {
            return new Response(body, { status: 404 })
        }

        return await fetch(url, {
            method: method || req.method,
            headers: {
                ...(hs),
                ...(headers),
            },

            // original body to be passed
            body: req.body,
        }).then(async (res) => {
            await log(reqId, {
                status: res.status,
                url: res.url,
            })
            return res
        }).catch(async (err) => {
            await log(reqId, {
                status: 500,
                err: '' + err.message,
            })
            throw err
        })
    },

    { port: Config.PORT },
)
