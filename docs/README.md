# Hazard3-Doom Read the Docs source

This directory contains the Sphinx documentation for Hazard3-Doom.

See [app.readthedocs.org/dashboard](https://app.readthedocs.org/dashboard/) for publishing status.

## Local build

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
python -m pip install -r docs/requirements.txt
python -m sphinx -W --keep-going -b html docs docs/_build/html
```

Open `docs/_build/html/index.html`.


## Localization

Hazard3-Doom uses Read the Docs projects with [multiple languages](https://docs.readthedocs.com/platform/latest/localization.html):

> Each language must have its own project on Read the Docs. You will choose one to be the parent project, and add each of the other projects as "Translations" of the parent project.

Create each translation project from the same repository and branch, with a language suffix in the Read the Docs project name, for example `-hr` or `-fr`.

Add each new project as a [translation](./images/readthedocs-add-translation.png) of the English parent project. The [Croatian project setup](./images/readthedocs-localization-project.png) is an example.

Build the Croatian documentation with:

```bash
READTHEDOCS_LANGUAGE=hr python -m sphinx -W --keep-going -b html docs docs/_build/html-hr
```

Build the French documentation with:

```bash
READTHEDOCS_LANGUAGE=fr python -m sphinx -W --keep-going -b html docs docs/_build/html-fr
```

Open `docs/_build/html-hr/index.html` or `docs/_build/html-fr/index.html`.

The repository-root `.readthedocs.yaml` is the build configuration used by Read the Docs. Each translated Read the Docs project should use its matching language and be linked as a translation of the English project. All language projects can use the same repository and branch; `docs/conf.py` selects the translated source tree from `READTHEDOCS_LANGUAGE`.

Translated human-language prose under `docs/<language>/` is UTF-8 and should use the native characters required by that language. Keep source code, scripts, CI, filenames, command literals, identifiers, paths, protocol strings, and other machine-facing text unchanged unless the underlying interface itself changes.

## ULX3S Chat and support

### Discord channel

- [https://discord.gg/qwMUk6W](https://discord.gg/qwMUk6W) (problems/question/general chat)

### Gitter channel

- [https://gitter.im/ulx3s/Lobby](https://gitter.im/ulx3s/Lobby) (Focused on development)

### Email

- [ulx3s.fpga@gmail.com](ulx3s.fpga@gmail.com) (If you do not use chats)
