#!/usr/bin/env python

import decimal
import json
import sys
from xml.etree.ElementTree import parse


exceptions_fname = '.coverage_exceptions.json'
coverage = parse(sys.argv[1])
fixes = []
errors = []
modules = {}


with open(exceptions_fname) as f:
    exceptions = json.loads(f.read())


for module in sorted(coverage.findall('.//class')):
    filename = module.attrib['filename']
    if filename.endswith('__init__.py'):
        continue

    modules[filename] = module
    current = decimal.Decimal(module.attrib.get('line-rate')) * 100
    expected = decimal.Decimal(exceptions.get(filename, 100))

    if current != 100 and filename not in exceptions:
        errors.append("2: %s has a coverage of %s%%, but expected 100%%, "
                      "add it to %s:" % (
                          filename, current * 100, exceptions_fname))
        fixes.append("    ('%s', '%.4f')," % (filename, current))
    elif current < expected:
        errors.append("1: %s has a coverage of %s%%, but expected %s%%, "
                      "add more tests or update %s" % (
                          filename, current, expected, exceptions_fname))
    elif current == 100 and expected < 100:
        errors.append("3: %s reached 100%%, remove it from %s" % (
            filename, exceptions_fname))


for filename in exceptions:
    if filename not in modules:
        errors.append("4: %s not found, remove it from %s" % (
            filename, exceptions_fname))


for error in sorted(errors):
    print 'ERROR:', error


if fixes:
    print "FIXES:"
    for fix in sorted(fixes):
        print fix


sys.exit(len(errors))
