#!/bin/sh
# vim: set syn=sh ft=sh et sw=2 sts=2 ts=2 tw=0:
# Maintainer: JRD <jrd@salixos.org>
# Contributors: Shador <shador@salixos.org>, Akuna <akuna@salixos.org>
# Licence: GPL v3+
#
# Prepare the source by getting any external scripts need to build an ISO.

cd $(dirname "$0")
sh ./.getsalt-scripts.sh "$@" || exit 1
for a in 32 64 arm; do
  if [ -d $a ]; then
    for f in common/*; do
      ln -s ../$f $a/
    done
  fi
done
