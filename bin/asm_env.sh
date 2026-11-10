#!/bin/bash
# Shared locations for the ASM_Template scripts. Source this file; do not run it.
#   ASM_TEMPLATE_HOME : where ASM_Template is installed
#   ASM_PROJECTS      : where new projects are created
# Values come from (highest priority first): environment variables,
# ~/.asm_template.conf (written by setup.sh), then defaults.
_asm_conf="${ASM_TEMPLATE_CONF:-$HOME/.asm_template.conf}"
if [ -f "$_asm_conf" ]; then
    _h="$ASM_TEMPLATE_HOME"; _p="$ASM_PROJECTS"
    . "$_asm_conf"
    [ -n "$_h" ] && ASM_TEMPLATE_HOME="$_h"
    [ -n "$_p" ] && ASM_PROJECTS="$_p"
    unset _h _p
fi
if [ -z "$ASM_TEMPLATE_HOME" ]; then
    ASM_TEMPLATE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
ASM_PROJECTS="${ASM_PROJECTS:-$HOME/projects}"
export ASM_TEMPLATE_HOME ASM_PROJECTS
unset _asm_conf
