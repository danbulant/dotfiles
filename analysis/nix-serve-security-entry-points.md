# nix-serve security entry points

Target deployment:

- Local: `nix-serve` / Starman directly on `:5000`.
- Public: `nix.fern.danbulant.cloud:80` via Caddy `reverse_proxy http://localhost:${config.services.nix-serve.port}` in `servers/fern/configuration.nix`.

Primary application code:

- `analysis/nix-serve/nix-serve.psgi`
- `analysis/p5-http-parser-xs/XS.xs`
- `analysis/p5-http-parser-xs/picohttpparser/picohttpparser.c`
- `analysis/HTTP-Entity-Parser/lib/HTTP/Entity/Parser*.pm`

## Request Flow

External request reaches Caddy, then Starman, then the PSGI app. Starman uses `HTTP::Parser::XS` to parse the request line and headers into PSGI env values. `nix-serve.psgi` routes only on `$env->{PATH_INFO}` and ignores method, query string, and request body.

Application routes in `nix-serve.psgi`:

- `/nix-cache-info`: static cache metadata.
- `/<hash>.narinfo`: maps hash prefix to a store path and returns NAR metadata/signatures.
- `/nar/<hash>-<narhash>.nar`: maps hash prefix, checks NAR hash, then spawns `nix store dump-path -- <storePath>`.
- `/nar/<hash>.nar`: legacy endpoint, maps hash prefix, then spawns `nix store dump-path -- <storePath>` without the NAR hash check.
- `/log/<hash>-<name>`: constructs `/nix/store/<hash>-<name>` and spawns `nix log <storePath>` without first proving that the path is valid or present.

## Confirmed Active Behaviors

### A. Incomplete `Content-Length` kills a Starman worker

Starman reads request bodies before dispatching to `nix-serve.psgi`, even though the app ignores bodies. In `Starman/Server.pm:450-462`, a positive `CONTENT_LENGTH` causes `_prepare_env` to read until the declared length is consumed. If the client closes early, it executes `die "Read error: $!\n"` outside an eval around request processing.

Confirmed behavior:

- Direct `:5000`: sending `Content-Length: 999999` with a one-byte body and closing replaces one worker process.
- Through Caddy: the same incomplete request to `nix.fern.danbulant.cloud:80` also replaces one Starman worker.
- The master process respawns the worker, so this is a repeatable worker-crash / availability issue rather than a one-shot full service crash.

Observed worker replacement example:

```text
before: 2529 2530 2532 2533 1239489
after:  2530 2532 2533 1239489 1240067
```

Root cause code:

```perl
elsif (my $cl = $env->{CONTENT_LENGTH}) {
    my $buf = Plack::TempBuffer->new($cl);
    while ($cl > 0) {
        my($chunk, $read) = $get_chunk->();
        if ( !defined $read || $read == 0 ) {
            die "Read error: $!\n";
        }
        $cl -= $read;
        $buf->print($chunk);
    }
    $env->{'psgi.input'} = $buf->rewind;
}
```

### B. Direct Starman accepts invalid `Content-Length` values

`HTTP::Parser::XS` copies `Content-Length` as a header value and Starman relies on Perl numeric coercion instead of strict decimal validation.

Parser-level results:

```text
CL=-1 ret=48 CONTENT_LENGTH=-1
CL=1x ret=48 CONTENT_LENGTH=1x
CL=1e9 ret=49 CONTENT_LENGTH=1e9
CL=+1 ret=48 CONTENT_LENGTH=+1
```

Confirmed direct behavior:

- `Content-Length: -1` to direct `:5000` returns `200 OK` for `/nix-cache-info`.
- `Content-Length: 1x` with a one-byte body to direct `:5000` returns `200 OK`.

Confirmed Caddy behavior:

- Caddy rejects these invalid content lengths with `400 Bad Request`, so this is currently direct-port-only unless another frontend forwards such requests.

### C. `%00` in path actively changes the routed endpoint

As noted below, `%00` truncates `PATH_INFO`. This is not just parser API behavior: both direct Starman and Caddy route `GET /nix-cache-info%00suffix HTTP/1.1` to the `/nix-cache-info` handler and return `200 OK`.

Current impact is endpoint confusion rather than data exposure because Caddy has no path-level allow/deny rules and the suffix does not select a protected app route. It would become a bypass if path filtering were added at Caddy or middleware while Starman still receives the raw encoded target.

### D. Missing `/log/...` returns `200 OK` with an empty body

Requests for a non-existent valid-looking log path return `200 OK` and an empty body through both direct Starman and Caddy:

```text
GET /log/00000000000000000000000000000000-test -> HTTP/1.1 200 OK
```

This is not data exposure, but it is undesired behavior for clients and monitoring because errors from `nix log` are not converted into HTTP errors. The route streams the child stdout without checking exit status.

## Candidate Entry Points

### 1. Percent-decoded `PATH_INFO` before routing

`HTTP::Parser::XS::parse_http_request` stores the original target in `REQUEST_URI`, then percent-decodes the path portion into `PATH_INFO` before `nix-serve.psgi` sees it:

- `XS.xs:186-201`
- `nix-serve.psgi:24`

This makes encoded delimiters and control bytes relevant to app routing. The app regexes are written as if `$path` is a normal textual URL path, but it is already decoded by the server parser.

Most interesting subcase: `%00`. In `XS.xs:136-144`, decoded values are stored with `newSVpv(decoded, 0)`. `newSVpv(..., 0)` treats the decoded buffer as a C string, so an embedded NUL produced from `%00` truncates the Perl scalar. A request target such as `/nix-cache-info%00suffix` becomes `PATH_INFO == "/nix-cache-info"` at the PSGI layer.

Confirmed with the packaged parser:

```text
ret=50
PATH_INFO=/nix-cache-info len=15
REQUEST_URI=/nix-cache-info%00suffix len=24
```

Confirmed through both local Starman and the Caddy reverse proxy: `GET /nix-cache-info%00suffix HTTP/1.1` returns the `/nix-cache-info` response.

Impact:

- Route suffix bypasses if any future route-level filtering is added before Starman decoding is understood.
- Caddy/Starman disagreement: Caddy forwards the raw target, while Starman truncates `PATH_INFO` after decoding.
- Possible endpoint confusion for `/nar/...` or `/log/...` where suffix data is invisible to the app but present in `REQUEST_URI` and access logs.

### 2. Out-of-bounds read on malformed percent escapes

`url_decode` in `XS.xs:97-128` scans for `%`, allocates `len - 1`, then reads `s[i + 1]` and `s[i + 2]` without first checking that two bytes remain:

```c
if ((hi = hex_decode(s[i + 1])) == -1
    || (lo = hex_decode(s[i + 2])) == -1) {
```

For a path ending in `%` or `%0`, this reads past the logical end of the Perl string. Perl SV buffers are usually NUL-terminated, so this is likely a small out-of-bounds read rather than an immediate crash, but it is still memory-unsafe C on request-controlled input. Packaged-parser behavior for `/%`, `/%0`, `/%GG`, and `/%0G` is `ret=-1` with no env entries; ASAN/debug-allocator validation is still needed for the actual memory read.

Impact to investigate:

- Whether ASAN or a hardened allocator catches reads for trailing `%` / `%0`.
- Whether Caddy rejects those targets before forwarding; direct `:5000` remains exposed locally.

### 3. `/log/...` prefix regex and subprocess spawning

`nix-serve.psgi:82-86` matches logs with:

```perl
elsif ($path =~ /^\/log\/([0-9a-z]+-[0-9a-zA-Z\+\-\.\_\?\=]+)/) {
```

The regex is not anchored at the end. Any path beginning with a valid-looking store basename is accepted, and the suffix is ignored. The route then runs `nix log $storePath` for the captured value without checking it with `queryPathFromHashPart` or `queryPathInfo` first.

There is no shell injection because `open` is called with an argument list, not a shell string. The interesting angle is resource use and Nix behavior on attacker-chosen valid-looking store paths.

Local command timing for a missing valid-looking path:

```text
$ time nix --extra-experimental-features nix-command log /nix/store/00000000000000000000000000000000-test
error: build log of '/nix/store/00000000000000000000000000000000-test' is not available
real    0m1.892s
```

That is enough per request to make `/log/...` a plausible low-rate process/CPU DoS surface, especially because the app does not validate the path against the store before spawning `nix log`.

Impact:

- CPU/process exhaustion from repeated `nix log` subprocesses.
- Missing paths still cost roughly 1.9s locally in a direct command test.
- Whether ignored suffixes create Caddy/Starman/app log ambiguity.

### 4. `/nar/...` subprocess fan-out

Both NAR routes spawn a `nix store dump-path` process per request:

- Checked route: `nix-serve.psgi:58-68`
- Legacy unchecked-hash route: `nix-serve.psgi:72-79`

The checked route validates that the requested NAR hash matches current path info. The legacy route only checks the hash prefix maps to a path and then dumps it.

Impact to investigate:

- Bandwidth/process DoS by repeatedly requesting large store paths.
- Whether the legacy route should be disabled in this deployment.
- Whether Caddy should apply rate limits or buffering constraints.

### 5. Request body parser inconsistencies in `HTTP::Entity::Parser`

`nix-serve.psgi` does not call `HTTP::Entity::Parser`, so this is probably not reachable through the current app unless Starman/Plack middleware invokes it. It is still in the service closure and should be treated as a package-level finding.

Potential issues:

- `HTTP::Entity::Parser.pm:76-90`: if both `Content-Length` and `Transfer-Encoding: chunked` exist, `Content-Length` wins. RFC 7230 says transfer coding overrides content length; this can create request-smuggling-style disagreement when another component follows the standard.
- `HTTP::Entity::Parser.pm:77-88`: `CONTENT_LENGTH` is not strictly parsed as decimal digits. Perl numeric coercion can accept weird values like `10foo`, scientific notation, or negative values differently from other components.
- `HTTP::Entity::Parser.pm:102-115`: chunk header parsing accepts `^(([0-9a-fA-F]+).*\r\n)` and does not require the CRLF after chunk data; it merely tries to remove it with `s/^\r\n//`. Malformed chunk bodies can be accepted with parser state disagreement.
- `UrlEncoded.pm` and `JSON.pm` accumulate the full body in memory before final parsing. Large bodies are memory DoS if an app registers these parsers without external limits.
- `MultiPart.pm` writes uploaded file parts to temp files and accumulates non-file fields in memory. There are no per-field, per-file, part-count, or aggregate limits here.

## Initial Priority

1. Decide whether to block `%00` at Caddy or patch/replace `HTTP::Parser::XS` path decoding.
2. Validate malformed percent escape behavior under ASAN or a debug allocator if practical.
3. Inspect `nix log` behavior for missing/attacker-chosen valid-looking store paths and decide whether `/log` needs validation/rate-limiting.
4. Decide whether the legacy `/nar/<hash>.nar` route is still needed.
5. Treat `HTTP::Entity::Parser` as lower priority for this app unless a middleware path is found that parses request bodies.
