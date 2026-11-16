#!/usr/bin/env bash
# Run the vv test suite against a throwaway jj repo.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT

export JJ_CONFIG="$repo/.jjconfig.toml"   # isolate from the user's config
export JJ_USER="Test User" JJ_EMAIL="test@example.com"
: > "$JJ_CONFIG"

cd "$repo"
jj git init --quiet .
echo one > a.txt && jj describe --quiet -m "first" && jj new --quiet
echo two > b.txt && jj describe --quiet -m "second" && jj new --quiet
echo three > c.txt && jj describe --quiet -m "third"

VV_ROOT="$here" vim --not-a-term -Nu NONE -i NONE -n -es \
  -c "set rtp^=$here | filetype plugin on | syntax on | runtime plugin/vv.vim" \
  -c "try | source $here/test/test_vv.vim | catch | call writefile([v:exception, v:throwpoint], '/dev/stdout') | cquit! | endtry"
