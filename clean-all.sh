#!/bin/sh
# vim: set syn=sh ft=sh et sw=2 sts=2 ts=2 tw=0:
# Maintainer: JRD <jrd@salixos.org>
# Contributors: Shador <shador@salixos.org>, Akuna <akuna@salixos.org>
# Licence: GPL v3+
#
# Clean all files.

cd $(dirname "$0")
for a in 32 64 arm; do
  if [ -d $a ]; then
    [ -x $a/clean-all.sh ] && $a/clean-all.sh
    for f in common/*; do
      rm -f $a/$(basename "$f")
    done
    for f in salt-scripts/*; do
      rm -f $a/$(basename "$f")
    done
  fi
done
rm -rf salt-scripts
