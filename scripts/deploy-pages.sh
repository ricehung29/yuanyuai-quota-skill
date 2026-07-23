#!/bin/sh
# deploy-pages.sh — push docs/ to gh-pages for GitHub Pages
set -eu

cd "$(git rev-parse --show-toplevel)"
git branch -D gh-pages 2>/dev/null || true
git subtree split --prefix docs -b gh-pages
git push -f origin gh-pages