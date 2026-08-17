# Hazard3-Doom Read the Docs source

This directory contains the Sphinx documentation for Hazard3-Doom.

## Local build

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
python -m pip install -r docs/requirements.txt
python -m sphinx -W --keep-going -b html docs docs/_build/html
```

Open `docs/_build/html/index.html`.

The repository-root `.readthedocs.yaml` is the build configuration used by Read the Docs.
