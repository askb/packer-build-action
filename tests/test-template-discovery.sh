#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation

#############################################################################
# Regression cover for Packer template discovery
#
# validate-packer.sh used to collect templates into a newline-separated
# string and iterate it unquoted, which split any path containing
# whitespace into several non-existent paths.
#
# Running the action end to end cannot cover this reliably: the test
# repository exposes its templates through a `common-packer` symlink,
# and find does not descend a symlinked starting point, so discovery
# returns nothing and the run passes without validating anything.
#
# This exercises the real script against controlled fixture trees with a
# stub packer on PATH, so template discovery is what is under test
# rather than Packer itself. It needs no network and no Packer install.
#############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/../scripts/validate-packer.sh"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Stub packer records each argument on its own line, so a path
# containing a space can be told apart from several separate arguments.
stub_dir="$workdir/stub"
mkdir -p "$stub_dir"
cat > "$stub_dir/packer" <<'STUB'
#!/usr/bin/env bash
{
  printf 'argc=%s\n' "$#"
  printf 'arg=%s\n' "$@"
} >> "$STUB_LOG"
exit 0
STUB
chmod +x "$stub_dir/packer"
export PATH="$stub_dir:$PATH"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

write_template() {
    printf '%s\n' \
        'variable "discovery_fixture" {' \
        '  type    = string' \
        '  default = "regression cover"' \
        '}' > "$1"
}

#############################################################################
# A template at a path containing spaces reaches packer intact.
#
# The fixture uses `packer/`, the script's first-priority directory, so
# discovery is deterministic regardless of the rest of the tree.
#############################################################################
case1="$workdir/spaced"
mkdir -p "$case1/packer/my templates"
write_template "$case1/packer/my templates/spaced name.pkr.hcl"

export STUB_LOG="$workdir/spaced.log"
: > "$STUB_LOG"

if ! (cd "$case1" && bash "$VALIDATE") > "$workdir/spaced.out" 2>&1; then
    fail "spaced path failed validation: $(cat "$workdir/spaced.out")"
fi

grep -q 'Passed: 1' "$workdir/spaced.out" ||
    fail "expected exactly one template: $(cat "$workdir/spaced.out")"
grep -q 'Failed: 0' "$workdir/spaced.out" ||
    fail "expected no failures: $(cat "$workdir/spaced.out")"

# The decisive assertion. Were the unquoted loop restored, this path
# would arrive as three arguments rather than one.
grep -qx 'arg=packer/my templates/spaced name.pkr.hcl' "$STUB_LOG" ||
    fail "path did not reach packer intact: $(cat "$STUB_LOG")"

echo 'ok: template path containing spaces reaches packer as one argument'

#############################################################################
# An empty tree reports that plainly and exits zero.
#
# This path changed shape with the fix, from a -z test on a string to a
# length test on an array, so it is worth pinning.
#############################################################################
case2="$workdir/empty"
mkdir -p "$case2/packer"

export STUB_LOG="$workdir/empty.log"
: > "$STUB_LOG"

if ! (cd "$case2" && bash "$VALIDATE") > "$workdir/empty.out" 2>&1; then
    fail "empty tree should exit zero: $(cat "$workdir/empty.out")"
fi

grep -q 'No Packer templates found' "$workdir/empty.out" ||
    fail "empty tree message missing: $(cat "$workdir/empty.out")"

[ ! -s "$STUB_LOG" ] ||
    fail "packer ran despite there being no templates: $(cat "$STUB_LOG")"

echo 'ok: empty tree reported without invoking packer'

#############################################################################
# The plugin-init fallback in action.yaml handles spaces too.
#
# That loop lives inline in the action, so it is read out of the
# metadata rather than copied here, and cannot drift from it. It is a
# separate implementation from the one above and needs its own cover.
#############################################################################
init_script="$workdir/init-fallback.sh"
python3 - "$SCRIPT_DIR/../action.yaml" > "$init_script" <<'EXTRACT'
import sys

import yaml

with open(sys.argv[1], encoding="utf-8") as handle:
    action = yaml.safe_load(handle)

wanted = "Initialize Packer plugins"
for step in action["runs"]["steps"]:
    if step.get("name") == wanted:
        print(step["run"])
        break
else:  # pragma: no cover - guards against a rename
    raise SystemExit(f"step not found in action.yaml: {wanted}")
EXTRACT

case3="$workdir/init"
mkdir -p "$case3/my templates"
write_template "$case3/my templates/spaced name.pkr.hcl"

export STUB_LOG="$workdir/init.log"
: > "$STUB_LOG"

# The fallback runs when no explicit template is supplied.
if ! (cd "$case3" && PACKER_TEMPLATE='' bash "$init_script") \
    > "$workdir/init.out" 2>&1; then
    fail "init fallback failed: $(cat "$workdir/init.out")"
fi

grep -qx 'arg=./my templates/spaced name.pkr.hcl' "$STUB_LOG" ||
    fail "init fallback split the path: $(cat "$STUB_LOG")"

# One template means exactly one init invocation.
[ "$(grep -c '^argc=' "$STUB_LOG")" -eq 1 ] ||
    fail "expected a single packer init: $(cat "$STUB_LOG")"

echo 'ok: init fallback passes a spaced path to packer intact'

#############################################################################
# A symlinked search directory is followed.
#
# common-packer is conventionally a symlink, and find does not descend
# a symlinked starting point. Without the trailing slash on the search
# directory, discovery returns nothing and validation reports success
# having checked no templates at all.
#############################################################################
case4="$workdir/symlink"
mkdir -p "$case4/templates"
write_template "$case4/templates/via-symlink.pkr.hcl"
ln -s . "$case4/common-packer"

export STUB_LOG="$workdir/symlink.log"
: > "$STUB_LOG"

if ! (cd "$case4" && bash "$VALIDATE") > "$workdir/symlink.out" 2>&1; then
    fail "symlinked directory failed: $(cat "$workdir/symlink.out")"
fi

if grep -q 'No Packer templates found' "$workdir/symlink.out"; then
    fail "discovery skipped the symlink: $(cat "$workdir/symlink.out")"
fi

grep -q 'Passed: 1' "$workdir/symlink.out" ||
    fail "expected one template via symlink: $(cat "$workdir/symlink.out")"

echo 'ok: symlinked search directory is followed'

echo 'All template discovery checks passed ✅'
