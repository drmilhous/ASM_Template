#!/bin/bash
# Kept for compatibility: run setup.sh instead (it records the install and project folders).
exec "$(dirname "${BASH_SOURCE[0]}")/setup.sh" "$@"
