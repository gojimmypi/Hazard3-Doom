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

Project with [multiple languages](https://docs.readthedocs.com/platform/latest/localization.html): 

> Each language must have its own project on Read the Docs. You will choose one to be the parent project, and add each of the other projects as “Translations” of the parent project.

Create the new project with the same name and a language suffix, [for example](./images/readthedocs-localization-project.png) `-hr`. 

Add the new project as a [translation](./images/readthedocs-add-translation.png).

Build the Croatian documentation with:

```bash
READTHEDOCS_LANGUAGE=hr python -m sphinx -W --keep-going -b html docs docs/_build/html-hr
```

Open `docs/_build/html-hr/index.html`.

The repository-root `.readthedocs.yaml` is the build configuration used by Read the Docs.
The Croatian Read the Docs project should use language `Croatian (hr)` and be linked as a translation of the English project. Both projects can use the same repository and branch; `docs/conf.py` selects the Croatian source tree from `READTHEDOCS_LANGUAGE`.

## ULX3S Chat and support

### Discord channel

- [https://discord.gg/qwMUk6W](https://discord.gg/qwMUk6W) (problems/question/general chat)

### Gitter channel

- [https://gitter.im/ulx3s/Lobby](https://gitter.im/ulx3s/Lobby) (Focused on development)

### Email

- [ulx3s.fpga@gmail.com](ulx3s.fpga@gmail.com) (If you do not use chats)
