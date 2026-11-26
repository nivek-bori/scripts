#!/bin/zsh
# In Automator, set "Pass input" to "as arguments".
(( $# )) || exit 0
exec "$HOME/bin/subs" -- "$@"
