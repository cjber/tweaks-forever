#!/bin/sh
set -eu

cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
revision=d0b5b51fac4c52c493371b9b18e66ce604ea4326
library=.types/vscode-wow-api
if [ ! -d "$library/.git" ]; then
    mkdir -p .types
    git init -q "$library"
    git -C "$library" remote add origin https://github.com/Ketho/vscode-wow-api.git
    git -C "$library" fetch --depth=1 origin "$revision"
    git -C "$library" checkout -q --detach FETCH_HEAD
fi
if [ "$(git -C "$library" rev-parse HEAD)" != "$revision" ]; then
    echo "$library: expected pinned revision $revision" >&2
    exit 1
fi
# The gitlink pins FrameXML too; never follow the submodule's moving branch.
git -C "$library" submodule update --init --depth=1 Annotations/FrameXML
if [ -n "$(git -C "$library" status --porcelain --untracked-files=all)" ]; then
    echo "$library: annotations must match the pinned checkout" >&2
    exit 1
fi
if [ "$(lua-language-server --version)" != '3.19.1' ]; then
    echo 'typecheck requires lua-language-server 3.19.1 on PATH' >&2
    exit 1
fi

python3 -m unittest discover -s tools -p '*_test.py'
python3 tools/lint_multivalue.py
python3 -m tools.lint_taint
python3 -m tools.phrases --check
# A fresh output path prevents a crashed checker from reusing an earlier green report.
report=$(mktemp -d "${TMPDIR:-/tmp}/tweaks-typecheck.XXXXXX")
trap 'rm -rf "$report"' EXIT HUP INT TERM
status=0
lua-language-server --check . --checklevel=Information --check_format=json \
    --check_out_path="$report/diagnostics.json" >"$report/server.log" 2>&1 || status=$?
python3 tools/typecheck_report.py "$report/diagnostics.json" "$status" "$report/server.log"
