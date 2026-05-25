#! /bin/bash

# General OCaml build script.
# Version 2.0 - December 2015
################ EDIT BELOW ################
LOG="make.log"
BINDIR="build"
SRCDIR="src"
DOCDIR="Documentation"
DIRS="-I +lablgtk3 -I +cairo2 -I +str -I +dynlink -I +unix"
LIBS="cairo.cma lablgtk3.cma unix.cma str.cma dynlink.cma"
FLAGS="-g -w s"
OPTFLAGS=""
OUTPUT="automates"
DOCOPT="-hide-warnings"
TEXOPT="-sort -stars -noheader"
DOCLNG="english"
DEFAULT_COLOR="Default color"
DOTOPT=""
WRAP=""
DLLIB=""
CCOPT=""
CCLIB=""
MAKE_ENTRY="all"
################ EDIT ABOVE ################
DONE="\033[1;32mDone\033[0;39m"
FAIL="\033[1;31mFail\033[0;39m"


[[ ! `command -v ocamlc.opt >/dev/null 2>&1` ]] && \
  OCAMLC=ocamlc.opt || OCAMLC=ocamlc
[[ ! `command -v ocamlopt.opt >/dev/null 2>&1` ]] && \
  OCAMLOPT=ocamlopt.opt || OCAMLOPT=ocamlopt
[[ ! `command -v ocamldoc.opt >/dev/null 2>&1` ]] && \
  OCAMLDOC=ocamldoc.opt || OCAMLDOC=ocamldoc
echo "(build) OCAMLC=$OCAMLC"
echo "(build) OCAMLOPT=$OCAMLOPT"
echo "(build) OCAMLDOC=$OCAMLDOC"

[ -d "$SRCDIR" ] && [ -d "$DOCDIR" ]
cd "$SRCDIR"
if [ "$MAKE_ENTRY" != "lib" ] || [ "$MAKE_ENTRY" != "lib.opt" ]; then
  SOURCE="$(ocamldsort *ml | sed 's/[^ ]*$//')"
else
  SOURCE="$(ocamldsort *ml)"
fi
echo $SOURCE
MLI="${SOURCE//ml/mli}"
echo "### Build script for $OUTPUT"
# Creates the folder $BINDIR if it does not exist.
[ -d "$BINDIR" ] || mkdir "$BINDIR"
# Copy sources to $BINDIR.
cp *ml *mli makefile "$BINDIR"                                              && \
cd "$BINDIR"                                                                && \
# Compilation, some variables defined.
make "SRC=$SOURCE"        \
     "LOG=$LOG"           \
     "DIRS=$DIRS"         \
     "LIBS=$LIBS"         \
     "EXE=$OUTPUT"        \
     "FLAGS=$FLAGS"       \
     "DONE=$DONE"         \
     "FAIL=$FAIL"         \
     "OCAMLC=$OCAMLC"     \
     "CCOPT=$CCOPT"       \
     "CCLIB=$CCLIB"       \
     "OCAMLOPT=$OCAMLOPT" \
     "OPTFLAGS=$OPTFLAGS" --silent $MAKE_ENTRY
