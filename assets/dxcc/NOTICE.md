# DXCC Prefix Table — Source & License

`dxcc_prefix_table.json` is derived from `cty.dat`, maintained by
Jim Reisert, AD1C (https://www.country-files.com).

Copyright © 1994– Jim Reisert, AD1C. Licensed under the MIT License
(https://www.country-files.com/copyright/):

> Permission is hereby granted, free of charge, to any person obtaining a
> copy of this software and associated documentation files (the
> "Software"), to deal in the Software without restriction, including
> without limitation the rights to use, copy, modify, merge, publish,
> distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to
> the following conditions: the above copyright notice and this
> permission notice shall be included in all copies or substantial
> portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
> OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
> MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
> IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
> CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
> TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
> SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Format

`dxcc_prefix_table.json` maps each DXCC entity's cty.dat "primary prefix"
to the full list of known prefix variants for that entity (deduplicated,
zone/lat-long/continent-override annotations and single-callsign
exceptions stripped). Regenerated from the standard (non-"Big CTY")
`cty.dat` release. See `lib/core/dxcc/dxcc_prefix_matcher.dart` for how
the app joins this table against the live Wavelog server's
`/api/v2/catalog?topic=dxcc` entity list.

## Updating

Re-download `cty.dat` from https://www.country-files.com/cty-dat-format/
and re-run the parser (kept in project history / PR description) to
regenerate this file. Not automated — update manually alongside version
bumps if entity prefixes have materially changed.
