# fujprog notice

Hazard3-Doom documentation identifies a bundled Windows executable named
`bin/fujprog-v48-win64.exe` for ULX3S programming.

Upstream:
https://github.com/kost/fujprog

Upstream identifies fujprog as BSD-2-Clause and credits:

- Marko Zec - original ujprog author; copyright 2008-2018, University of Zagreb.
- EMARD - contributions; copyright 2014-2019.
- gojimmypi - contributions credited by upstream.
- kost - contributions/maintenance; copyright 2020.
- all other fujprog/ujprog contributors.

A historical Hazard3-Doom development log identifies a v4.8 binary built from
git revision `96ebb45`, but the release process must verify that this is the
same executable currently shipped rather than relying on that historical log.

Before a public binary release:

1. Record SHA-256 and file version of the exact executable.
2. Record the exact source commit used to build it.
3. Copy that source revision's original LICENSE file into the release.
4. Preserve its copyright/credits and source location.

`BSD-2-Clause-fujprog-reference.txt` is a convenience reference, not a
substitute for step 3.
