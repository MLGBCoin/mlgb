#!/bin/sh

TOPDIR=${TOPDIR:-$(git rev-parse --show-toplevel)}
SRCDIR=${SRCDIR:-$TOPDIR/src}
MANDIR=${MANDIR:-$TOPDIR/doc/man}

ZCASHD=${ZCASHD:-$SRCDIR/mlgbd}
ZCASHCLI=${ZCASHCLI:-$SRCDIR/mlgb-cli}
ZCASHTX=${ZCASHTX:-$SRCDIR/mlgb-tx}

[ ! -x $ZCASHD ] && echo "$ZCASHD not found or not executable." && exit 1

# The autodetected version git tag can screw up manpage output a little bit
MGBVERSTR=$($ZCASHCLI --version | head -n1 | awk '{ print $NF }')
MGBVER=$(echo $MGBVERSTR | awk -F- '{ OFS="-"; NF--; print $0; }')
MGBCOMMIT=$(echo $MGBVERSTR | awk -F- '{ print $NF }')

# Create a footer file with copyright content.
# This gets autodetected fine for mlgbd if --version-string is not set,
# but has different outcomes for mlgb-cli.
echo "[COPYRIGHT]" > footer.h2m
$ZCASHD --version | sed -n '1!p' >> footer.h2m

for cmd in $ZCASHD $ZCASHCLI $ZCASHTX; do
  cmdname="${cmd##*/}"
  help2man -N --version-string=$MGBVER --include=footer.h2m -o ${MANDIR}/${cmdname}.1 ${cmd}
  sed -i "s/\\\-$MGBCOMMIT//g" ${MANDIR}/${cmdname}.1
done

rm -f footer.h2m
