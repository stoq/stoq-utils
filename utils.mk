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

# This needs to be updated when a new Ubuntu release is out or
# one of those reaches EOL
SUPPORTED_DISTROS=trusty xenial zesty artful bionic

check-source:
	@utils/source-tests.sh --modified

check-source-all:
	@utils/source-tests.sh

validatecoverage:
	@utils/validatecoverage.py coverage.xml

virtualenv-deps:
	pip install -r requirements.txt

dist:
	python3 setup.py sdist
	tar -zxvf dist/*.tar.gz -C dist

deb: dist
	cd dist/* && \
	debuild --preserve-env -us -uc;

debsource: dist
	cd dist/* && \
	for dist in ${SUPPORTED_DISTROS}; do \
		sed -i "1 s/-1[a-z0-9]\+)/)/g" debian/changelog; \
		sed -i "1 s/) .\+;/-1$${dist}$${EXTRA_VERSION}) $${dist};/g" debian/changelog; \
		debuild --preserve-env -S; \
	done
	@echo "To upload the sources to the ppa you can run:"
	@echo
	@echo "    dput <ppa_name> dist/*.changes"
	@echo

wheel:
	python3 setup.py sdist bdist_wheel

wheel-upload:
	python3 setup.py sdist bdist_wheel upload

plugin-egg:
	# Set current git commit to plugin config file
	$(eval GIT_COMMIT=$(shell git rev-parse --short HEAD))
	sed -i "s/GitCommit=.*/GitCommit=${GIT_COMMIT}/g" $(PACKAGE)/*.plugin
	# Compile main.py if exists
	if [ -f __main__.py ]; then python -m py_compile __main__.py; fi
	# build egg
	python3 setup.py bdist_egg --exclude-source-files --dist-dir=dist
	# clean up
	rm -fr build
	rm -fr $(PACKAGE).egg-info
	rm -f __main__.pyc
	rm -f __pycache__/__main__.cpython-35.pyc
	# Fix egg pyc files
	python3 utils/fix_py3_egg.py dist/*py3.5.egg

.PHONY: check-source check-source-all validatecoverage virtualenv-deps debsource wheel pypi-upload
