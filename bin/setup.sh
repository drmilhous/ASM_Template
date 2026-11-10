#!/bin/bash
# Usage: setup.sh [project_folder]
# Run from the folder that holds ASM_Template (or from ASM_Template itself).
# The current folder becomes the install location; project_folder (default
# $HOME/projects) is where new projects are created.
CONF="${ASM_TEMPLATE_CONF:-$HOME/.asm_template.conf}"
CUR="$(pwd)"
if [ -d "$CUR/ASM_Template/bin" ]; then
    ASM_TEMPLATE_HOME="$CUR/ASM_Template"
elif [ -d "$CUR/bin" ] && [ -f "$CUR/bin/asm_env.sh" ]; then
    ASM_TEMPLATE_HOME="$CUR"
else
    echo "Run setup.sh from the ASM_Template folder (or its parent)." >&2
    exit 1
fi
ASM_PROJECTS="${1:-$HOME/projects}"
mkdir -p "$ASM_PROJECTS" || exit 1
ASM_PROJECTS="$(cd "$ASM_PROJECTS" && pwd)"

cat > "$CONF" <<EOT
ASM_TEMPLATE_HOME="$ASM_TEMPLATE_HOME"
ASM_PROJECTS="$ASM_PROJECTS"
EOT

case "$SHELL" in
    */zsh) RC="$HOME/.zshrc" ;;
    *)     RC="$HOME/.bashrc" ;;
esac
LINE='export PATH="$PATH:$(. "${ASM_TEMPLATE_CONF:-$HOME/.asm_template.conf}"; echo "$ASM_TEMPLATE_HOME")/bin"'
grep -qF "asm_template.conf" "$RC" 2>/dev/null || echo "$LINE" >> "$RC"

echo "Install folder : $ASM_TEMPLATE_HOME"
echo "Project folder : $ASM_PROJECTS"
echo "Saved to $CONF; PATH updated in $RC (open a new shell)."
