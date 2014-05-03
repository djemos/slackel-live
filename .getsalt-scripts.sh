#!/bin/sh
# vim: set syn=sh ft=sh et sw=2 sts=2 ts=2 tw=0:
#
# Used to download the correct version of SaLT Scripts and SaLT.

cd $(dirname "$0")
SALT_SCRIPTS_VER="$1"
if [ -z "$SALT_SCRIPTS_VER" ]; then
  echo "You need to specify a branch or tag for SaLT-scripts" >&2
  exit 1
fi
SALT_SCRIPTS_URL='git://github.com/djemos/SaLT-scripts-slackware.git'

if [ -d salt-scripts ]; then
  rm -rf salt-scripts || echo "salt-scripts directory cannot be removed, check permissions" >&2
fi
git clone -n "$SALT_SCRIPTS_URL" salt-scripts-slackware
# install symlinks
for a in 32 64 arm; do
  if [ -d $a ]; then
    for f in salt-scripts/*; do
      ln -s ../$f $a/
    done
  fi
done
