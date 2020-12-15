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
SUPPORTED_DISTROS=xenial bionic eoan focal groovy

check-source:
	@utils/source-tests.sh --modified

check-source-all:
	@utils/source-tests.sh

validatecoverage:
	@utils/validatecoverage.py coverage.xml

virtualenv-deps:
	pip install -r requirements.txt

requirements.txt: pyproject.toml
	poetry export -f requirements.txt --without-hashes -o requirements.txt
	echo '--extra-index-url https://__token__:'"${GITLAB_PYPI_TOKEN}"'@gitlab.com/api/v4/projects/13882298/packages/pypi/simple/\n' >> requirements.txt

dist:
	pybabel compile -d $(PACKAGE)/locale -D $(PACKAGE) || true
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
	@rm -rf dist/*
	python3 setup.py sdist bdist_wheel

wheel-upload: wheel
	twine upload dist/*

plugin-egg:
	# Set current git commit to plugin config file
	$(eval GIT_COMMIT=$(shell git rev-parse --short HEAD))
	sed -i "s/GitCommit=.*/GitCommit=${GIT_COMMIT}/g" $(PACKAGE)/*.plugin
	# Compile main.py if exists
	if [ -f __main__.py ]; then python -m py_compile __main__.py; fi
	# build egg
	#python3 setup.py bdist_egg --exclude-source-files --dist-dir=dist
	python3 setup.py bdist_egg --dist-dir=dist
	# clean up
	rm -fr build
	rm -fr $(PACKAGE).egg-info
	rm -f __main__.pyc
	rm -f __pycache__/__main__.cpython-35.pyc
	# Fix egg pyc files
	#python3 utils/fix_py3_egg.py dist/*py3.5.egg

clean: clean-eggs clean-build clean-docs
	@find . -iname '*.pyc' -delete
	@find . -iname '*.pyo' -delete
	@find . -iname '*~' -delete
	@find . -iname '*.swp' -delete
	@find . -iname '__pycache__' -delete

clean-eggs:
	@find . -type f -name '*.egg' -delete
	@rm -rf .eggs/

clean-build:
	@rm -fr build/
	@rm -fr dist/
	@rm -fr *.egg-info

clean-docs:
	@rm -fr docs/build/

ci-check-bump:
	git show --no-patch ${CI_MERGE_REQUEST_TARGET_BRANCH_NAME} $(PACKAGE)/__init__.py && \
		echo "Version bumped!" || \
		echo "You have to bump the version of this project. Check https://gitlab.com/stoqtech/private/bdil/-/wikis/Atualizar-versao-dos-projetos"

.PHONY: check-source check-source-all validatecoverage virtualenv-deps debsource wheel pypi-upload clean
