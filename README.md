<div align="center">

# sluice

A command-line summariser for web server access logs, written in Perl with nothing outside core.

![License](https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge)  ![Language](https://img.shields.io/badge/PERL-39457e?style=for-the-badge&logo=perl&logoColor=white)  ![Tests](https://img.shields.io/badge/TESTS-27-brightgreen?style=for-the-badge)

Refer to [LICENSE](LICENSE) for the legal bits.

</div>

## What's in it

- **Parser** for Common Log Format and Combined Log Format lines. One regex pulls out host, user, time, method, path, protocol, status, bytes, referrer and agent. A `-` for bytes becomes zero, and the referrer and agent are empty strings when the line is Common format.
- **Filters** built with `make_filter`: exact status, status class (2, 3, 4, 5), method (case-insensitive), host, and a regex on the path. They run before anything is counted.
- **Counters** for status, path, host, method and hour of day, plus total requests, total bytes and a count of lines that didn't parse, so a bad log can't quietly skew the numbers.
- **Reports**: a plain-text summary with a 5xx rate and human-readable transfer size, or the same data as canonical, pretty-printed JSON via `JSON::PP`.
- **`bin/sluice`**, a thin `Getopt::Long` wrapper that reads files or standard input.

```perl
use Sluice;

my $sluice = Sluice->new(filter => Sluice::make_filter(class => 4));
$sluice->add_handle(\*STDIN);
printf "%s %d\n", @$_ for $sluice->top('path', 5);
```

## 🏗️ Architecture

```
 bin/sluice  (Getopt::Long, files or STDIN)
      |
      v
 +---------------------------------------------------+
 | lib/Sluice.pm                                     |
 |                                                   |
 |  parse_line  -->  make_filter  -->  add_line      |
 |   (one qr//)       (closure)         |            |
 |                                      v            |
 |   counts: status path host method hour            |
 |   scalars: total bytes malformed                  |
 |                                      |            |
 |   top / classes / error_rate  <------+            |
 |   summary (hashref)    report (text)              |
 +---------------------------------------------------+
 t/sluice.t   Makefile.PL
```

- `parse_line` returns a hashref or nothing. Unparseable lines bump `malformed` and are never filtered or counted.
- `make_filter` returns a closure, so the object only ever asks "does this record pass?".
- Everything is held as hash counts. Memory grows with the number of distinct paths and hosts, not the number of lines.
- `top` sorts by count descending, then key ascending, so output is stable between runs. Asking for a field it doesn't track dies.
- The hourly breakdown uses the hour as written in the log, in whatever zone the server logged. Timestamps aren't converted to epoch time.
- Only the two standard formats are recognised. Custom `log_format` layouts need a change to the regex.

## 🚀 Quick start

```
perl -Ilib t/sluice.t
bin/sluice access.log
bin/sluice --class 5 --top 20 access.log
bin/sluice --method POST --path '^/api/' access.log
zcat access.log.*.gz | bin/sluice --json
```

A quick taste with five good lines and one junk line, `--top 2`:

```
requests   5
transfer   2.9 KB
malformed  1
5xx rate   20.00%

status
         2  200
         1  304

path
         2  /index.html
         1  /about

host
         2  198.51.100.4
         2  203.0.113.9

method
         4  GET
         1  POST

hour
         2  13
         2  14
         1  15
```

## 🧪 Testing

27 tests, all passing (`prove -l t` runs the same file):

- Parsing: host, user, method, path, status, bytes and agent on a Combined line, dash bytes as zero, no agent on a Common line, and junk rejected.
- Counting: totals, malformed count, summed bytes, top path, tie-breaking by name, status classes, error rate and hours seen.
- Filtering: class filter, and method plus path filter together.
- Formatting: `human_bytes` for bytes, kilobytes and megabytes, input from a filehandle, the report header and the JSON-ready summary.
- Errors: asking `top` for an unknown field dies.

## Licence

MIT.

