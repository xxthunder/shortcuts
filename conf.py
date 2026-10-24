"""Sphinx configuration of the shortcuts documentation (SC-073b).

The needs configuration lives in ubproject.toml, which ubCode reads as well; this file
only wires Sphinx to it.
"""

import tomllib
from pathlib import Path

_UBPROJECT = "ubproject.toml"

project = "shortcuts"
author = "Karsten Günther"
copyright = author

extensions = [
    "myst_parser",
    "sphinx_needs",
    "sphinx_codelinks",
]

needs_from_toml = _UBPROJECT
src_trace_config_from_toml = _UBPROJECT

# Sphinx reads its configuration here and its sources from docs/ (`-c .` in the docs task),
# so the published site starts at docs/index.md.
_SOURCE_DIR = "docs/"
root_doc = "index"
# The same document set as the md parser's `include` in ubproject.toml, read from there so
# the two readers cannot drift apart. ubCode resolves it from the repository root, Sphinx
# from docs/.
_ubcode_include = tomllib.loads((Path(__file__).parent / _UBPROJECT).read_text(encoding="utf-8"))[
    "parse"
]["parsers"]["md"]["include"]
if not all(pattern.startswith(_SOURCE_DIR) for pattern in _ubcode_include):
    raise ValueError(f"every md parser include in {_UBPROJECT} must lie under {_SOURCE_DIR}")
include_patterns = [pattern.removeprefix(_SOURCE_DIR) for pattern in _ubcode_include]

# GitHub's heading slugs, so that a link to a heading works on GitHub and in the build alike.
myst_heading_anchors = 6
myst_enable_extensions = ["tasklist"]

html_theme = "furo"
html_title = "shortcuts"
html_logo = "docs/images/shortcuts_logo_title_transparent.png"
html_theme_options = {"sidebar_hide_name": True}
