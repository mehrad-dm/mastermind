#!/usr/bin/env bash
# Stands in for claude in the validate-plugin.sh self-test. STUB_MODE picks what a strict run says.
case "$*" in
  --version) echo '99.0.0 (Claude Code)'; exit 0 ;;
  'plugin validate --help') echo 'Usage: claude plugin validate <path> [--strict]'; exit 0 ;;
esac
case "$*" in *--strict*) ;; *) exit 0 ;; esac
case "${STUB_MODE:-}" in
  clean) echo 'Validating plugin manifest'; exit 0 ;;
  accepted) printf 'Validating plugin manifest\n  ❯ CLAUDE.md at the plugin root is not loaded\n'; exit 1 ;;
  silent) printf 'Validating plugin manifest\nwarnings were treated as errors\n'; exit 1 ;;
  real) printf 'Validating plugin manifest\n  ❯ unknown field "triggers" in plugin.json\n'; exit 1 ;;
esac
exit 3
