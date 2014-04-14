#
# Copyright (C) 2014 Async Open Source <http://www.async.com.br>
# All rights reserved
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., or visit: http://www.gnu.org/.
#
# Author(s): Stoq Team <stoq-devel@async.com.br>
#

#
# This script is inspired by virtualenv's activate. It should be sourced like:
#
#     . stoq/utils/env.sh
#
# It can also be used together with virtualenv. For that, modify it's activate
# script and add the line above at the end of it.
#

_stoq_deactivate () {
    if [ -n "$_OLD_PATH" ]; then
        PATH="$_OLD_PATH"
        export PATH
        unset _OLD_PATH
    fi
    if [ -n "$_OLD_PYTHONPATH" ]; then
        PYTHONPATH="$_OLD_PYTHONPATH"
        export PYTHONPATH
        unset _OLD_PYTHONPATH
    fi

    # This should detect bash and zsh, which have a hash command that must
    # be called to get it to forget past commands.  Without forgetting
    # past commands the $PATH changes we made may not be respected
    if [ -n "$BASH" -o -n "$ZSH_VERSION" ]; then
        hash -r
    fi

    if [ -n "$_OLD_PS1" ]; then
        PS1="$_OLD_PS1"
        export PS1
        unset _OLD_PS1
    fi

    unset STOQLIB_TEST_QUICK
    unset STOQ_DISABLE_CRASHREPORT
    if [ ! "$1" = "nondestructive" ]; then
        # Self destruct!
        unset -f _stoq_deactivate
    fi
}

if [ -n "$VIRTUAL_ENV" ]; then
    # Based on http://mivok.net/2009/09/20/bashfunctionoverrist.html
    _save_function () {
        local ORIG_FUNC=$(declare -f $1)
        local NEWNAME_FUNC="$2${ORIG_FUNC#$1}"
        eval "$NEWNAME_FUNC"
    }
    _save_function deactivate _virtualenv_deactivate

    deactivate () {
        _stoq_deactivate $@
        _virtualenv_deactivate $@
        if [ ! "$1" = "nondestructive" ]; then
            # virtualenv will unset deactivate and _stoq_deactivate will unset
            # itself, so we need to unset _virtualenv_deactivate here
            unset -f _virtualenv_deactivate
            unset -f _save_function
        fi
    }
else
    deactivate () {
        _stoq_deactivate $@
        if [ ! "$1" = "nondestructive" ]; then
            # Self destruct!
            unset -f deactivae
        fi
    }
fi

_DIRNAME=`dirname $0`
if [ -f "$_DIRNAME/.gitmodules" ]; then
    # The script is in a submodule
    _DIRNAME=$_DIRNAME/..
fi

cd $_DIRNAME
_CHECKOUT=`pwd`
cd - > /dev/null

_OLD_PATH="$PATH"
_OLD_PYTHONPATH="$PYTHONPATH"

for _PROJECT in `ls $_CHECKOUT | sort`; do
    _PROJECT_PATH="$_CHECKOUT/$_PROJECT"
    # Make sure we add new hooks every time the shell inits
    if [ -d "$_PROJECT_PATH/utils/git-hooks/" ]; then
        cp -au $_PROJECT_PATH/utils/git-hooks/* \
               $_PROJECT_PATH/.git/hooks/
    fi

    # Put all projects inside checkout on PYTHONPATH and the ones having a
    # bin directory on PATH
    PYTHONPATH="$_PROJECT_PATH:$PYTHONPATH"
    if [ -d "$_PROJECT_PATH/bin" ]; then
        PATH="$_PROJECT_PATH/bin:$PATH"
    fi
done

export PATH
export PYTHONPATH

# Don't modify PS1 if inside a virtualenv. This allows for someone to
# source this file at the end of virtualenv's activate script
if [ -z "$VIRTUAL_ENV" ]; then
    _OLD_PS1="$PS1"

    if [ -d "$_CHECKOUT/.repo/" ]; then
        # When using repo, put 'stoq' as the name of the environment
        PS1="(stoq)$PS1"
    else
        PS1="(`basename $_CHECKOUT`)$PS1"
    fi

    export PS1
fi

export STOQLIB_TEST_QUICK=1
export STOQ_DISABLE_CRASHREPORT=1

unset _DIRNAME
unset _CHECKOUT
unset _PROJECT
unset _PROJECT_PATH

# This should detect bash and zsh, which have a hash command that must
# be called to get it to forget past commands.  Without forgetting
# past commands the $PATH changes we made may not be respected
if [ -n "$BASH" -o -n "$ZSH_VERSION" ]; then
    hash -r
fi
