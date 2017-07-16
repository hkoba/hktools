#!/bin/zsh

if (($+SUDO_USER)); then
    export GIT_AUTHOR_EMAIL=$SUDO_USER@localhost
    export GIT_AUTHOR_NAME=$SUDO_USER
    export GIT_COMMITTER_EMAIL=$SUDO_USER@localhost
    export GIT_COMMITTER_NAME=$SUDO_USER
fi

if [[ -n $USER && -z $GIT_AUTHOR_NAME ]]; then
    export GIT_AUTHOR_NAME=$USER GIT_COMMITTER_NAME=$USER
    export GIT_AUTHOR_EMAIL=$USER@localhost GIT_COMMITTER_EMAIL=$USER@localhost
fi
