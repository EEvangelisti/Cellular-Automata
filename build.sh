#! /bin/bash

# General OCaml build script.
# Version 2.0 - December 2015
################ EDIT BELOW ################
LOG="make.log"
BINDIR="build"
SRCDIR="Sources"
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
     "OPTFLAGS=$OPTFLAGS" --silent $MAKE_ENTRY                              && \
# Building documentation
$OCAMLDOC $DIRS -latex $DOCOPT $TEXOPT -o "../../$DOCDIR/$OUTPUT.tex" $MLI  && \
$OCAMLDOC $DIRS -dot   $DOCOPT $DOTOPT -o "../../$DOCDIR/$OUTPUT.dot" $MLI  && \
# Edit documentation
cd "../../$DOCDIR"                                                          && \
cp "$OUTPUT.tex" "$OUTPUT.backup.tex"                                       && \
# Some LaTeX command substitutions from ocamldoc output.
sed -i -e 's/\\it \([^}]*\)/\\itshape \1\\\//g'                                \
 -e 's/\\bf \([^}]*\)/\\bfseries \1\\\//g'                                     \
 -e "s/{\\\\textquotesingle}/'/g"                                              \
 -e 's/{\\textasciigrave}/`/g'                                                 \
 -e 's/\\_/_/g'                                                                \
 -e 's/\[ `/\n  \[ `/g'                                                        \
 -e 's/\([^ ]\) | /\1\n  | /g'                                                 \
 -e 's/\\begin{ocamldocsigend}/\\begin{leftbar}\\begin{adjustwidth}{24pt}{0pt}\\scriptsize/g'           \
 -e 's/\\begin{ocamldocobjectend}/\\begin{leftbar}\\begin{adjustwidth}{24pt}{0pt}\\scriptsize/g'           \
 -e 's/\\end{ocamldocsigend}/\\end{adjustwidth}\\end{leftbar}/g'            \
 -e 's/\\end{ocamldocobjectend}/\\end{adjustwidth}\\end{leftbar}/g'            \
 -e "s/^\(.*class.*\)\\\\end{ocamldoccode}$/printf "%s" '\1' \| detex \| xargs -0 printf "%sobject..end\\\\\\\\\\\\\\\\end{ocamldoccode}\\\\Contents:"/ge"\
 -e "s/^\(.*module.*\)\\\\end{ocamldoccode}$/printf "%s" '\1' \| detex \| xargs -0 printf "%ssig..end\\\\\\\\\\\\\\\\end{ocamldoccode}\\\\Contents:"/ge"\
 -e 's/ocamldoccode/lstlisting/g'                                              \
 -e 's/\\section/\\pagebreak\n\\section/g'                                     \
 "$OUTPUT.tex"                                                              && \
# Multi-language documents.
sed -i -e "s/input{[^-}]*}/input{$OUTPUT}/"                                    \
 -e "0,/selectlanguage{[^}]*/s//selectlanguage{$DOCLNG/"                       \
 -e "0,/usepackage\[[^]]*\]{babel}/s//usepackage\[$DOCLNG,english\]{babel}/"   \
 myocamlheader.tex                                                          && \
# Handling ##Color<name>(<hex>)
sed -i 's/{\\char35}{\\char35}Color\([^(]*\)(\([A-Z0-9]*\))/'\
'\\definecolor{\1}{HTML}{\2}{\\\\*\\'\
"textbf{$DEFAULT_COLOR:} "\
'{\\fcolorbox{Black}{\1}{\\rule{1ex}{0pt}\\rule{0pt}{1ex}}}'\
' (\\lstinline$\"#\2\"$)}/g' "$OUTPUT.tex"                                  && \
# Handling ##Anytext : data and some other substitutions.
sed -i -e 's/{\\char35}{\\char35}\([^:]*\):/\\\\*\\textbf{\1:}/g'              \
 -e 's/{\\char35}/#/g'                                                         \
 -e 's/{\\char126}/~/g'                                                        \
 -e 's/{\\char123}/{/g'                                                        \
 -e 's/{\\char125}/}/g'                                                        \
 -e 's/\\end{document}//'                                                      \
 -e 's/{\\tt{\([^}]*\)}}/\\lstinline$\1$/g'                                    \
 "$OUTPUT.tex"                                                              && \
# Preparing documentation - LaTeX compilation.
rm myocamlheader.pdf &> /dev/null                                           && \
echo -n "(pdflatex) Building $OUTPUT.pdf... "                               && \
pdflatex -interaction=batchmode \
myocamlheader.tex &> /dev/null
if [ ! -f myocamlheader.pdf ]; then 
  echo -e "$FAIL"
  exit 1
else 
cp myocamlheader.pdf "../$OUTPUT.pdf" && echo -e "$DONE"
fi
