#! /bin/bash

OPT="ocamlopt.opt"
BIN="../../Sources/build"

find *.ml -execdir bash -c 'echo "(Ocelot) Plugin $(basename "{}")" && \
  '"$OPT"' -g -shared -I '"$BIN"' "{}" -o "$(basename "{}" .ml).cmxs"' \;
