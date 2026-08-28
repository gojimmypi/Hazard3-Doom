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
    "github_user": "gojimmypi",
    "github_repo": "Hazard3-Doom",
    "github_version": "develop",
    "conf_py_path": (
        f"/docs/{translation_language}/" if translation_name is not None else "/docs/"
    ),
}
