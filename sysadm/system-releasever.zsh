#!/bin/zsh

# Stolen from dnf.rpm.detect_releasever()
DISTROVERPKG=('system-release(releasever)' 'redhat-release')

for p in $DISTROVERPKG; do
  res=$(rpm -q --whatprovides --qf '%{version}\n' $p 2>/dev/null) || continue
  print $res
  exit 0
done

exit 1
