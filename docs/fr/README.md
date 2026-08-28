# French documentation source

This directory mirrors the relative `.rst` paths under `docs/` and contains the French text used when Sphinx builds with `READTHEDOCS_LANGUAGE=fr`.

The files here are not a separate Sphinx project. `docs/conf.py` uses Sphinx's `source-read` event to substitute the French source for the matching English document name. This keeps English and French output URLs identical apart from Read the Docs' language prefix.

When adding or removing an English `.rst` page, make the corresponding change here. The French build intentionally fails if Sphinx reads an English document that has no matching French source file.

French prose is UTF-8 and should use correct French characters such as `é`, `è`, `ê`, `à`, `ç`, and `œ`. Keep code blocks, command names, filenames, addresses, URLs, reStructuredText labels, `:doc:` / `:ref:` targets, image paths, protocol strings, and toctree targets synchronized with the English page unless the referenced resource itself is language-specific.

Local build:

```bash
READTHEDOCS_LANGUAGE=fr python -m sphinx -W --keep-going -b html docs docs/_build/html-fr
```
