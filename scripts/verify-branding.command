#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

fail() {
    print -u2 "Brand verification failed: $*"
    exit 1
}

readonly launcher_word="Launcher"
readonly launcher_word_lower="launcher"
readonly tactician_tail="Tician"
readonly old_product_pattern="TFT-PBE-$launcher_word|TFTPBE $launcher_word|tft-pbe-$launcher_word_lower|tft_pbe_$launcher_word_lower|TFTPBE$launcher_word|TFT$launcher_word"
readonly old_titled_product="TFT PBE $launcher_word"
readonly wrong_casing="Mac$tactician_tail"
readonly forbidden_suffix="Mactician $launcher_word"

typeset content_matches
content_matches="$(rg -n -i --hidden \
    --glob '!.git/**' \
    --glob '!dist/**' \
    --glob '!launcher/.build/**' \
    --glob '!build/**' \
    --glob '!DerivedData/**' \
    "$old_product_pattern|$forbidden_suffix" . \
    | grep -vE '^\./docs/releasing[.]md:[0-9]+:(`tft-pbe-'"$launcher_word_lower"'`[.] This locator is not secret[.] Its public key must be|export MACTICIAN_SPARKLE_ACCOUNT="\$\{MACTICIAN_SPARKLE_ACCOUNT:-tft-pbe-'"$launcher_word_lower"'\}")$' \
    || true)"
[[ -z "$content_matches" ]] || {
    print -r -- "$content_matches" >&2
    fail "obsolete or forbidden product naming remains in repository content"
}

content_matches="$(rg -n --hidden \
    --glob '!.git/**' \
    --glob '!dist/**' \
    --glob '!launcher/.build/**' \
    --glob '!build/**' \
    --glob '!DerivedData/**' \
    "$old_titled_product|$wrong_casing" . || true)"
[[ -z "$content_matches" ]] || {
    print -r -- "$content_matches" >&2
    fail "incorrect Mactician casing remains in repository content"
}

typeset filename_matches
filename_matches="$(find . \
    -path './.git' -prune -o \
    -path './dist' -prune -o \
    -path './launcher/.build' -prune -o \
    -path './build' -prune -o \
    -path './DerivedData' -prune -o \
    -print | LC_ALL=C grep -Ei "$old_product_pattern|$forbidden_suffix" || true)"
[[ -z "$filename_matches" ]] || {
    print -r -- "$filename_matches" >&2
    fail "obsolete or forbidden product naming remains in repository paths"
}

filename_matches="$(find . \
    -path './.git' -prune -o \
    -path './dist' -prune -o \
    -path './launcher/.build' -prune -o \
    -path './build' -prune -o \
    -path './DerivedData' -prune -o \
    -print | LC_ALL=C grep -E "$old_titled_product|$wrong_casing" || true)"
[[ -z "$filename_matches" ]] || {
    print -r -- "$filename_matches" >&2
    fail "incorrect Mactician casing remains in repository paths"
}

print "Brand verification: OK"
