# -----------------------------------------------------------------------------
# File:        conf.py
# Path:        docs/conf.py
#
# Project:     Hazard3-Doom
# Purpose:     Configure Sphinx and Read the Docs builds, including translated
#              documentation source selection and HTML presentation.
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

import os
from datetime import datetime

project = "Hazard3-Doom"
author = "Hazard3-Doom contributors"
copyright = f"{datetime.now().year}, {author}"
release = os.environ.get("READTHEDOCS_VERSION", "develop")
version = release

hazard3_repo = "https://github.com/ulx3s/Hazard3"
hazard3_commit = "3c0aca063517bb7fdbe869019c984954c7dd5c97"

extensions = ["sphinx.ext.extlinks"]

rst_epilog = f"""
.. |hazard3_commit| replace:: ``{hazard3_commit}``
"""

extlinks = {
    "hazard3-src": (
        f"{hazard3_repo}/blob/{hazard3_commit}/%s",
        "%s",
    ),
    "hazard3-tree": (
        f"{hazard3_repo}/tree/{hazard3_commit}%s",
        "%s",
    ),
}

extlinks_detect_hardcoded_links = True
templates_path = []
language = os.environ.get("READTHEDOCS_LANGUAGE", "en").lower().replace("-", "_")

# The special case exists because Sphinx has Croatian support for the generated
# documentation/UI language, but its HTML search index does not have a
# Croatian search stemmer. French and English do, so they don't need a fallback.
html_search_language = "en" if language == "hr" else language

translation_languages = {
    "fr": "French",
    "hr": "Croatian",
}
translation_language = language.split("_", 1)[0]
translation_name = translation_languages.get(translation_language)
exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
    *[f"{code}/**" for code in translation_languages],
]


def _use_translated_source(app, docname, source):
    if translation_name is None:
        return

    translated = os.path.join(
        os.path.dirname(__file__), translation_language, f"{docname}.rst"
    )
    if not os.path.isfile(translated):
        raise RuntimeError(
            f"Missing {translation_name} documentation source: {translated}"
        )

    app.env.note_dependency(translated)
    with open(translated, encoding="utf-8") as stream:
        source[0] = stream.read()


def setup(app):
    app.connect("source-read", _use_translated_source)

html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "/")

html_theme_options = {
    "collapse_navigation": False,
    "sticky_navigation": True,
    "navigation_depth": 4,
    "includehidden": True,
    "titles_only": False,
}

html_context = {
    "display_github": True,
    "github_user": "ulx3s",
    "github_repo": "Hazard3-Doom",
    "github_version": os.environ.get("READTHEDOCS_GIT_IDENTIFIER", "main"),
    "conf_py_path": (
        f"/docs/{translation_language}/" if translation_name is not None else "/docs/"
    ),
}
