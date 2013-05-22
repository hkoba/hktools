#!/usr/bin/env pypy
# -*- coding: utf-8 -*-

import sys
import zipfile

zfn = sys.argv[1]
pw = sys.argv[2]
print 'extracting from %s\n'.format(zfn)
zip = zipfile.ZipFile(zfn, 'r')


# これだと、ディレクトリ名の指定になる
# zip.extract(zi, zi.filename.decode('shift-jis').encode('utf-8'), pw)

for zi in zip.infolist():
    ofn = zi.filename.decode('shift-jis').encode('utf-8')
    print "extracting {}...\n".format(ofn)
    of = open(ofn, 'w')
    with zip.open(zi, 'r', pw) as zr:
        # XXX: 一括展開なので、メモリーが勿体ない
        of.write(zr.read())
    of.close()
    

