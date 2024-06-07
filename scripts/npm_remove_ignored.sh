#!/bin/bash
# File: scripts/npm_remove_ignored.sh
# Run:
#   sh scripts/npm_remove_ignored.sh .npmignore
#   sh scripts/npm_remove_ignored.sh .gitignore
# 2024-04-21 | CR
#

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
cd "${REPO_BASEDIR}"
TMP_SCRIPT="/tmp/gs_remove_ignored.sh"

echo "Removing ignored files from: $1"

if [ "$1" = "" ]; then
    echo "Usage: $0 <file>"
    exit 1
fi
if [ ! -f "$1" ]; then
    echo "ERROR: File $1 not found"
    exit 1
fi


cat > "${TMP_SCRIPT}" <<END \

#!/bin/bash
ask_yes_or_no() {
    read choice
    while [[ ! \$choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
}    
END

while IFS= read -r line || [ -n "$line" ]; do
  if [ ! -z "$line" ]; then
    if ls "$line" 2>/dev/null; then
        echo "echo \"\"" >> ${TMP_SCRIPT}
        echo "echo \"Removing $line\"" >> ${TMP_SCRIPT}
        echo "echo \"Are you sure? (Y/N)\"" >> ${TMP_SCRIPT}
        echo "ask_yes_or_no" >> ${TMP_SCRIPT}
        echo "if [[ \$choice =~ ^[Yy]$ ]]; then" >> ${TMP_SCRIPT}
        echo "    rm -rf "$line" 2>/dev/null" >> ${TMP_SCRIPT}
        echo "fi" >> ${TMP_SCRIPT}
    else
        echo "Ignoring $line"
    fi
  fi
done < "$1"

bash ${TMP_SCRIPT}
