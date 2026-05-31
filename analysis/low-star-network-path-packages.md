# Low-Star Packages On Plausible Network/Data Paths

Generated from `analysis/network-library-review.csv` and GitHub metadata on 2026-05-30. Star counts are GitHub stars at collection time. Dependency paths are Nix derivation/package paths, so they show that a package is reachable from the configured service package closure; they do not prove every library is loaded on every runtime request path.

Selection criteria: GitHub-backed dependency with relatively low stars, used by a network-facing root (`nix-serve`, `prowlarr`, `jellyfin`, `sonarr`, `radarr`), and plausibly involved in HTTP parsing, socket handling, JSON/XML/HTML parsing, remote metadata parsing, text normalization, database access, or similar externally influenced data handling.

## Highest Priority

| Project | Stars | Used by | Version in use | Latest seen | Why it may matter |
| --- | ---: | --- | --- | --- | --- |
| [kazeburo/HTTP-Entity-Parser](https://github.com/kazeburo/HTTP-Entity-Parser) | 5 | `nix-serve` | `0.25` | `0.25` | PSGI-compliant HTTP entity/body parser, directly adjacent to HTTP request handling. |
| [kazuho/p5-http-parser-xs](https://github.com/kazuho/p5-http-parser-xs) | 30 | `nix-serve` | `0.17` | `0.17` | Fast C/XS HTTP parser used through the Perl web stack; low-level parser code is a high-value review target. |
| [shlomif/perl-io-socket-inet6](https://github.com/shlomif/perl-io-socket-inet6) | 0 | `nix-serve` | `2.73` | `2.73` | IPv6 socket support library in the `nix-serve` Perl closure. Socket plumbing is network-path relevant. |
| [AngleSharp/AngleSharp.Xml](https://github.com/AngleSharp/AngleSharp.Xml) | 20 | `prowlarr` | `1.0.0` | `1.0.0` | XML and DTD parser extension for AngleSharp. Prowlarr handles indexer feeds/pages from remote sources. |
| [p5sagit/JSON-MaybeXS](https://github.com/p5sagit/JSON-MaybeXS) | 4 | `nix-serve` | `1.004005` | `1.004008` | JSON backend selection/compatibility module in the HTTP service closure. JSON parsing often receives externally supplied data. |

## Medium Priority

| Project | Stars | Used by | Version in use | Latest seen | Notes |
| --- | ---: | --- | --- | --- | --- |
| [madsen/io-html](https://github.com/madsen/io-html) | 3 | `nix-serve` | `1.004` | `1.004` | Perl module for opening files with automatic charset detection. Less directly exposed than HTTP parsers, but charset detection can be input-sensitive. |
| [Zastai/MetaBrainz.MusicBrainz](https://github.com/Zastai/MetaBrainz.MusicBrainz) | 41 | `jellyfin` | `6.1.0` | `v8.0.1` | Native .NET implementation of MusicBrainz client/data model. Jellyfin can ingest remote metadata responses. |
| [Zastai/MetaBrainz.Common.Json](https://github.com/Zastai/MetaBrainz.Common.Json) | 1 | `jellyfin` | `6.0.2` | `v7.2.0` | JSON helper classes for MetaBrainz packages. Relevant to parsing remote metadata. |
| [Zastai/MetaBrainz.Common](https://github.com/Zastai/MetaBrainz.Common) | 0 | `jellyfin` | `3.0.0` | `v4.1.1` | Shared classes for MetaBrainz packages. Low stars and in the metadata path, but not itself a parser entry point. |
| [NightOwl888/ICU4N](https://github.com/NightOwl888/ICU4N) | 44 | `jellyfin` | `60.1.0-alpha.356` | `60.1.0-alpha.439` | Unicode/text normalization and transliteration library. Useful to review because media metadata and filenames are attacker-influenced in many deployments. |

## Lower Priority But Network-Adjacent

| Project | Stars | Used by | Version in use | Latest seen | Notes |
| --- | ---: | --- | --- | --- | --- |
| [ericsink/SQLitePCL.raw](https://github.com/ericsink/SQLitePCL.raw) | 609 | `jellyfin` | `2.1.10` | `v3.0.3` | Low-level SQLite access layer. Not a network parser, but stores/query data derived from remote/user-controlled metadata. |
| [dotnet/SqlClient](https://github.com/dotnet/SqlClient) | 974 | `sonarr`, `radarr` | `2.1.7`, `6.1.1`, SNI runtime `2.1.1`, `6.0.2` | `v7.0.1` | SQL Server connectivity. Relevant if these apps are configured to use SQL Server or process DB connection data, but less relevant for the default SQLite-style local deployment path. |

## Candidate Details

### kazeburo/HTTP-Entity-Parser

Project: [https://github.com/kazeburo/HTTP-Entity-Parser](https://github.com/kazeburo/HTTP-Entity-Parser)

Description: PSGI compliant HTTP Entity Parser.

Used by: `nix-serve`

Dependency path: `nix-serve -> perl-5.42.0-env -> HTTP-Entity-Parser`

Version in use: `0.25`

Latest/release data: latest `0.25`, latest release date `2020-11-28T02:35:43`

Other data: Perl, 5 stars, 8 forks, 2 open issues, not archived, last pushed `2020-11-28T02:35:43Z`, license `NOASSERTION`

Assessment: Directly relevant to HTTP body parsing for `nix-serve`; worth manual review if `nix-serve` is publicly exposed through Caddy.

### kazuho/p5-http-parser-xs

Project: [https://github.com/kazuho/p5-http-parser-xs](https://github.com/kazuho/p5-http-parser-xs)

Description: Fast HTTP parser.

Used by: `nix-serve`

Dependency path: `nix-serve -> perl-5.42.0-env -> HTTP-Parser-XS`

Version in use: `0.17`

Latest/release data: latest `0.17`, latest release date `2014-12-15T07:53:06`

Other data: C, 30 stars, 11 forks, 9 open issues, not archived, last pushed `2024-06-13T04:08:54Z`

Assessment: Highest-value low-star item because it is C parser code close to HTTP request parsing.

### shlomif/perl-io-socket-inet6

Project: [https://github.com/shlomif/perl-io-socket-inet6](https://github.com/shlomif/perl-io-socket-inet6)

Description: CPAN IPv6 socket module mirror/repository.

Used by: `nix-serve`

Dependency path: `nix-serve -> perl-5.42.0-env -> IO-Socket-INET6`

Version in use: `2.73`

Latest/release data: latest `2.73`, latest release date `2021-12-10T07:31:35`

Other data: Perl, 0 stars, 1 fork, 0 open issues, not archived, last pushed `2021-12-10T07:31:26Z`, license `NOASSERTION`

Assessment: Network plumbing dependency. Lower parser risk than HTTP parsers, but the star count is effectively zero.

### AngleSharp/AngleSharp.Xml

Project: [https://github.com/AngleSharp/AngleSharp.Xml](https://github.com/AngleSharp/AngleSharp.Xml)

Description: Library adding XML and DTD parsing capabilities to AngleSharp.

Used by: `prowlarr`

Dependency path: `prowlarr -> AngleSharp.Xml`

Version in use: `1.0.0`

Latest/release data: latest `1.0.0`, release date `2023-01-15T12:45:03.84Z`, latest release date `2023-01-15T12:45:04Z`

Other data: C#, 20 stars, 6 forks, 5 open issues, not archived, last pushed `2025-01-26T20:54:26Z`, license `MIT`

Assessment: XML/DTD parsing in an indexer-facing service is plausibly exposed to remote feed/page content. Worth checking DTD/external entity behavior and parser limits.

### p5sagit/JSON-MaybeXS

Project: [https://github.com/p5sagit/JSON-MaybeXS](https://github.com/p5sagit/JSON-MaybeXS)

Description: JSON backend compatibility/selecting module for Perl.

Used by: `nix-serve`

Dependency path: `nix-serve -> perl-5.42.0-env -> JSON-MaybeXS`

Version in use: `1.004005`

Latest/release data: latest `1.004008`, latest release date `2024-08-10T20:23:23`

Other data: Perl, 4 stars, 6 forks, 1 open issue, not archived, last pushed `2024-12-27T11:55:18Z`

Assessment: Probably a wrapper rather than the parser implementation itself, but it is in a web service closure and touches JSON handling.

### madsen/io-html

Project: [https://github.com/madsen/io-html](https://github.com/madsen/io-html)

Description: Perl module that opens a file and performs automatic charset detection.

Used by: `nix-serve`

Dependency path: `nix-serve -> perl-5.42.0-env -> IO-HTML`

Version in use: `1.004`

Latest/release data: latest `1.004`, latest release date `2020-09-26T16:52:29`

Other data: Perl, 3 stars, 1 fork, 0 open issues, not archived, last pushed `2020-09-26T16:51:31Z`

Assessment: Charset detection can be input-sensitive, but this is lower priority unless `nix-serve` uses it on request-supplied content.

### Zastai MetaBrainz packages

Projects: [MetaBrainz.Common](https://github.com/Zastai/MetaBrainz.Common), [MetaBrainz.Common.Json](https://github.com/Zastai/MetaBrainz.Common.Json), [MetaBrainz.MusicBrainz](https://github.com/Zastai/MetaBrainz.MusicBrainz)

Descriptions: Shared classes, JSON helpers, and native .NET implementation of libmusicbrainz.

Used by: `jellyfin`

Dependency paths: `jellyfin -> MetaBrainz.Common`, `jellyfin -> MetaBrainz.Common.Json`, `jellyfin -> MetaBrainz.MusicBrainz`

Versions in use: `3.0.0`, `6.0.2`, `6.1.0`

Latest/release data: latest `v4.1.1`, `v7.2.0`, `v8.0.1`; latest release dates in 2026 for all three

Other data: C#, 0/1/41 stars, 0/0/10 forks, not archived, MIT license

Assessment: These are in Jellyfin metadata handling. They are not direct socket parsers, but they process metadata structures that can originate from remote services or media tags.

### NightOwl888/ICU4N

Project: [https://github.com/NightOwl888/ICU4N](https://github.com/NightOwl888/ICU4N)

Description: International Components for Unicode for .NET.

Used by: `jellyfin`

Dependency paths: `jellyfin -> ICU4N`, `jellyfin -> ICU4N.Transliterator`

Version in use: `60.1.0-alpha.356`

Latest/release data: latest `60.1.0-alpha.439` for `ICU4N`; latest `60.1.0-alpha.356` for `ICU4N.Transliterator`; NuGet release dates were not exposed in the cached data

Other data: C#, 44 stars, 8 forks, 22 open issues, not archived, last pushed `2026-05-08T23:25:53Z`, license `Apache-2.0`

Assessment: Text normalization/transliteration libraries can receive untrusted metadata, filenames, subtitles, and tags. Alpha-version package in use is notable.

### ericsink/SQLitePCL.raw

Project: [https://github.com/ericsink/SQLitePCL.raw](https://github.com/ericsink/SQLitePCL.raw)

Description: Portable Class Library for low-level raw access to SQLite.

Used by: `jellyfin`

Dependency paths: `jellyfin -> SQLitePCLRaw.core`, `jellyfin -> SQLitePCLRaw.bundle_e_sqlite3`, `jellyfin -> SQLitePCLRaw.lib.e_sqlite3`, `jellyfin -> SQLitePCLRaw.provider.e_sqlite3`

Version in use: `2.1.10`

Latest/release data: latest `v3.0.3`, release dates around `2024-09-11`, latest release date `2026-05-07T17:28:57Z`

Other data: C#, 609 stars, 134 forks, 36 open issues, not archived, last pushed `2026-05-07T17:23:42Z`, license `Apache-2.0`

Assessment: Not a network parser, but stores and queries data derived from network/media metadata. Lower priority than parser/socket libraries.

### dotnet/SqlClient

Project: [https://github.com/dotnet/SqlClient](https://github.com/dotnet/SqlClient)

Description: Microsoft.Data.SqlClient provides database connectivity to SQL Server for .NET applications.

Used by: `sonarr`, `radarr`

Dependency paths: `sonarr -> Microsoft.Data.SqlClient`, `radarr -> Microsoft.Data.SqlClient`, and corresponding `Microsoft.Data.SqlClient.SNI.runtime` rows

Versions in use: `2.1.7`, `6.1.1`, SNI runtime `2.1.1`, `6.0.2`

Latest/release data: latest `v7.0.1`, latest release date `2026-04-24T19:34:24Z`

Other data: C#, 974 stars, 330 forks, 276 open issues, not archived, last pushed `2026-05-30T11:30:25Z`, license `MIT`

Assessment: Network-adjacent database client. Relevant mainly if Sonarr/Radarr are configured to use SQL Server or expose database connection handling.

## Low-Star Items Not Prioritized

These appeared in the low-star scan but are less plausibly on a network/data parsing path: [garu/data-dump](https://github.com/garu/data-dump), [garu/Clone](https://github.com/garu/Clone), Serilog extension/sink packages, NUnit test adapters, and `buildcatrust`. They may still matter for build integrity or diagnostics, but they are not obvious request/response parser or socket-facing dependencies from the current dependency paths.

## Suggested Follow-Up

Review `nix-serve` first because it is exposed through Caddy and has several very low-star Perl HTTP/socket parser dependencies. Then check `prowlarr` XML/HTML parsing behavior, especially external entity handling and parser size/time limits. Finally, decide whether Jellyfin remote metadata providers are enabled and exposed enough to justify deeper review of the MetaBrainz and ICU4N paths.
