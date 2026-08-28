import os
from datetime import datetime

project = "Hazard3-Doom"
author = "Hazard3-Doom contributors"
copyright = f"{datetime.now().year}, {author}"
release = "develop"
version = release

extensions = []
templates_path = []
language = os.environ.get("READTHEDOCS_LANGUAGE", "en").lower().replace("-", "_")
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store", "hr/**"]


def _use_croatian_source(app, docname, source):
    if language != "hr":
        return

    translated = os.path.join(os.path.dirname(__file__), "hr", f"{docname}.rst")
    if not os.path.isfile(translated):
        raise RuntimeError(f"Missing Croatian documentation source: {translated}")

    app.env.note_dependency(translated)
    with open(translated, encoding="utf-8") as stream:
        source[0] = stream.read()


def setup(app):
    app.connect("source-read", _use_croatian_source)

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
    "github_user": "gojimmypi",
    "github_repo": "Hazard3-Doom",
    "github_version": "develop",
    "conf_py_path": "/docs/hr/" if language == "hr" else "/docs/",
}
