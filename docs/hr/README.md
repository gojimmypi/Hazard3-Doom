# Croatian documentation source

This directory mirrors the relative `.rst` paths under `docs/` and contains the Croatian text used when Sphinx builds with `READTHEDOCS_LANGUAGE=hr`.

The files here are not a separate Sphinx project. `docs/conf.py` uses Sphinx's `source-read` event to substitute the Croatian source for the matching English document name. This keeps English and Croatian output URLs identical apart from Read the Docs' language prefix.

When adding or removing an English `.rst` page, make the corresponding change here. The Croatian build intentionally fails if Sphinx reads an English document that has no matching Croatian source file.

Croatian prose is UTF-8 and should use correct Croatian characters such as `č`, `ć`, `đ`, `š`, and `ž`. Keep code blocks, command names, filenames, addresses, URLs, reStructuredText labels, `:doc:` / `:ref:` targets, image paths, protocol strings, and toctree targets synchronized with the English page unless the referenced resource itself is language-specific.

Local build:

```bash
READTHEDOCS_LANGUAGE=hr python -m sphinx -W --keep-going -b html docs docs/_build/html-hr
```
