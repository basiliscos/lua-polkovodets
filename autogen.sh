#!/bin/sh

libtoolize --copy --automake --force &&\
aclocal	-I . &&\
autoheader &&\
autoconf &&\
automake --include-deps --add-missing --copy --foreign --no-force || exit 1
./configure "$@"
