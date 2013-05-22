#!/usr/bin/env pypy
# -*- coding: utf-8 -*-

import sys
import zipfile
import shutil

zfn = sys.argv[1]
pw = sys.argv[2]
print 'extracting from {}\n'.format(zfn)
zip = zipfile.ZipFile(zfn, 'r')


# これだと、ディレクトリ名の指定になる
# zip.extract(zi, zi.filename.decode('shift-jis').encode('utf-8'), pw)

for zi in zip.infolist():
    ofn = zi.filename.decode('shift-jis').encode('utf-8')
    print "extracting {}...".format(ofn)
    of = open(ofn, 'w')
    with zip.open(zi, 'r', pw) as zr:
        shutil.copyfileobj(zr, of, 4096*16)
    of.close()
    

