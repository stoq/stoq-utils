#!/bin/bash
#
# Copyright (C) 2013-2014 Async Open Source <http://www.async.com.br>
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

set -e

# Exclude this whole repository
GREP_EXCLUDE="`dirname $0`/"

# Pyflakes
PYFLAKES_BIN="pyflakes"

# PEP8
PEP8_BIN="`dirname $0`/pep8.py"
# TODO:
# E125 - continuation line does not distinguish itself from next logical line
PEP8_ARGS="--count --repeat \
           --ignore=E125 --max-line-length=100"

# Pylint
PYLINT_DISABLED=(
    # Convention
    C0103  # Invalid name "xxx" for type variable
           # (should match [a-z_][a-z0-9_]{2,30}$)
    C0111  # Missing docstring
    C0301  # Line too long
    C0302  # Too many lines in module
    C0322  # Operator not preceded by a space
           # bug in pylint: Only happens for keyword lambda arguments

    # Errors
    E1101  # Instance of XXX has no yyy member
    E1102  # TODO: class is not callable
    E1103  # Instance of XXX has no yyy member (some not inferred)

    # Fatal
    F0401  # Unable to import gudev

    # Refactor
    R0201  # Method could be a function
    R0901  # Too many ancestors
    R0902  # Too many instance attributes
    R0903  # Too few public methods
    R0904  # Too many public methods
    R0911  # Too many return statements
    R0912  # Too many branches
    R0913  # Too many arguments
    R0915  # Too many statements
    R0914  # Too many local variables
    R0921  # Abstract class not referenced
           # Bug in Pylint: http://www.logilab.org/ticket/111138
    R0922  # Abstract class is only referenced 1 times

    # Warnings
    W0141  # TODO: Used builtin function map
    W0142  # Used * or ** magic
    W0201  # Attribute loaded_uis defined outside __init__
    W0212  # Access to protected member
    W0222  # Signature differs from overriden method
    W0221  # Arguments number differs from overriden method
    W0223  # Method add is abstract in class xxx but is not overriden
    W0231  # __init__ method from base class is not called
    W0232  # Class has no __init__ method
    W0233  # __init__ method from a non direct base class is called
    W0603  # Using the global statement
    W0612  # Unused variable
    W0613  # Unused argument
    W0622  # Redefined built-in variable
    W0623  # Redefining name xxx from outer scope in exception handler
    W0702  # No exception type(s) specified
    W0703  # Catching too general exception Exception
    W0704  # Except doesnt do anything
)

_run_pylint() {
    PYLINT_VERSION=`pylint --version 2> /dev/null|head -1|cut -d\  -f2|cut -d, -f1`
    if [ "$PYLINT_VERSION" = "0.26.0" ]; then
        PYLINT_DISABLED+=('R0924',)  # TODO: Badly implemented Container
    fi

    SAVE_IFS=$IFS
    IFS=","
    PYLINT_DISABLEDJOIN="${PYLINT_DISABLED[*]}"
    IFS=$SAVE_IFS

    PYLINT_BIN="pylint"
    PYLINT_ARGS="--disable=$PYLINT_DISABLEDJOIN \
                 --dummy-variables=unused,_ \
                 --include-ids=y \
                 --load-plugins tools/pylint_stoq.py \
                 --rcfile=tools/pylint.rcfile \
                 --reports=n"

    $PYLINT_BIN $PYLINT_ARGS $1
}

_run() {
  # grep will fail if there are no modifed pyfiles, so disable
  # during this command
  set +e
  FILES=`echo "$1" | egrep ".py$" | grep -Ev "$GREP_EXCLUDE"`
  set -e

  if [ -z "$FILES" ]; then
    # This is ok. We don't have modified files on tree
    exit 0
  fi

  echo "* PyFlakes"
  $PYFLAKES_BIN $FILES

  echo "* PEP8"
  $PEP8_BIN $PEP8_ARGS $FILES

  # This variable can be exported on the Makefile
  if [ "$PYLINT_ENABLED" = "1" ]; then
    echo "* Pylint"
    _run_pylint "$FILES"
  fi

  exit 0
}

run_all () {
  _run "`git ls-files '*.py'`"
}

run_staged() {
  _run "`git diff --name-only --diff-filter=ACM --cached`"
}

run_modified () {
  _run "`git diff --name-only --diff-filter=ACM HEAD`"
}


case "$1" in
  -s | --staged )
    run_staged;;
  -m | --modified )
    run_modified;;
  * )
    run_all;;
esac
