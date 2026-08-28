Contributing Documentation
==========================

Local documentation build
-------------------------

Create a dedicated virtual environment:

.. code-block:: bash

   python3 -m venv .venv-docs
   source .venv-docs/bin/activate
   python -m pip install -r docs/requirements.txt
   python -m sphinx -W --keep-going -b html docs docs/_build/html

On PowerShell:

.. code-block:: powershell

   py -m venv .venv-docs
   .\.venv-docs\Scripts\Activate.ps1
   py -m pip install -r .\docs\requirements.txt
   py -m sphinx -W --keep-going -b html .\docs .\docs\_build\html

Open ``docs/_build/html/index.html`` after a successful build.

Documentation rules
-------------------

* Prefer commands copied from the current scripts rather than paraphrased shell syntax.
* Keep hardware addresses and memory maps synchronized with the pinned Hazard3 submodule.
* Mark branch-only or experimental features explicitly.
* Do not include commercial IWAD content.
* Keep board-specific wiring in board-specific sections.
* Add troubleshooting entries when a failure mode has a repeatable diagnosis.
* Translated human-language prose under ``docs/<language>/`` is UTF-8 and should preserve the native characters required by that language. Keep source code, scripts, CI, filenames, command literals, identifiers, paths, protocol strings, and other machine-facing text unchanged unless the underlying interface itself changes.

Read the Docs publishing
------------------------

The repository-root ``.readthedocs.yaml`` points Read the Docs at ``docs/conf.py`` and installs ``docs/requirements.txt``. After the files are committed, import the GitHub repository into Read the Docs and select the branch/version to publish.
