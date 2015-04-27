#!/bin/sh

set -e

cd /etc

[ -f .gitignore ] || cat > .gitignore <<EOF
/mtab
/lvm
/blkid
/adjtime
/*-
/*.cache
/*.db
*~
*.lock
*.bak
*.OLD
*.old
*.O
*rpmorig
*rpmnew
EOF

if [ -d .git ]; then
    echo /etc already has .git, skipped.
else
    git init --shared=0600
fi
