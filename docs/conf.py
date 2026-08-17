import os
from datetime import datetime

project = "Hazard3-Doom"
author = "Hazard3-Doom contributors"
copyright = f"{datetime.now().year}, {author}"
release = "develop"
version = release

extensions = []
templates_path = []
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

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
    "conf_py_path": "/docs/",
}
