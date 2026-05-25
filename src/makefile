# OCaml generic makefile 

CMI=$(SRC:.ml=.cmi)
CMO=$(SRC:.ml=.cmo)
CMX=$(SRC:.ml=.cmx)
CMXA=$(LIBS:.cma=.cmxa)
WRAP=$(wildcard *.c)

%.o: %.c
	echo -n "(make) Building $@... "
	$(OCAMLOPT) $(FLAGS) $(OPTFLAGS) $(DIRS) -c $< 2>> "$(LOG)" \
	|| ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	echo "$(DONE)"

%.so: $(WRAP:.c=.o)
	echo -n "(make) Building $@... "
	ocamlmklib $(CCOPT) $(CCLIB) $^ -o "$(EXE)"
	echo "$(DONE)"

%.cmi: %.mli
	echo -n "(make) Building $@... "
	$(OCAMLC) -c $(FLAGS) $(DIRS) $< 2>> "$(LOG)" \
	|| ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	echo "$(DONE)"

%.cmo: %.ml
	echo -n "(make) Building $@... "
	$(OCAMLC) -c $(FLAGS) $(DIRS) $< 2>> "$(LOG)" \
	|| ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	echo "$(DONE)"

%.cmx: %.ml
	echo -n "(make) Building $@... "
	$(OCAMLOPT) -c $(FLAGS) $(OPTFLAGS) $(DIRS) $< 2>> "$(LOG)" \
	|| ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	echo "$(DONE)"

native: $(CMI) $(CMX)
	echo -n "(make) Building $(EXE).opt... "
	$(OCAMLOPT) $(FLAGS) $(OPTFLAGS) $(DIRS) $(CMXA) $(CMX) "$(EXE).ml" \
	-o "$(EXE).opt" 2>> "$(LOG)" || ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	mv "$(EXE).opt" ../..
	echo "$(DONE)"

bytecode: $(CMI) $(CMO)
	echo -n "(make) Building $(EXE)... "
	$(OCAMLC) $(FLAGS) $(DIRS) $(LIBS) $(CMO) "$(EXE).ml" \
	-o "$(EXE)" 2>> "$(LOG)" || ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	mv "$(EXE)" ../..
	echo "$(DONE)"

bytelib: $(CMI) $(CMO) dll$(EXE).so
	echo -n "(make) Building $(EXE).cma... "
	$(OCAMLC) $(FLAGS) $(DIRS) $(CMO) -a -o "$(EXE).cma" \
	  -dllib "$(DLLIB)" $(CCOPT:-L/-ccopt -L) $(CCLIB:-l/-cclib -l) 2>> "$(LOG)" \
	  || ( echo "$(FAIL) (see $(LOG))"; exit 1 )
		cp "$(EXE).cma" ../..
	echo "$(DONE)"

natlib: $(CMI) $(CMX) dll$(EXE).so
	echo -n "(make) Building $(EXE).cmxa... "
	$(OCAMLOPT) $(FLAGS) $(DIRS) $(CMX) -a -o "$(EXE).cmxa" \
	  -cclib "$(DLLIB)" $(CCOPT:-L/-ccopt -L) $(CCLIB:-l/-cclib -l) 2>> "$(LOG)" \
	  || ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	cp "$(EXE).cmxa" ../..
	echo "$(DONE)"

clean:
	echo -n "(make) Cleaning up... "
	rm -f *.cm[iox] *.[ao] *.cma *.cmxa 2>> "$(LOG)" \
	|| ( echo "$(FAIL) (see $(LOG))"; exit 1 )
	echo "$(DONE)"

obj: $(CMI) $(CMO)
obj.opt: $(CMI) $(CMX)

lib: bytelib
lib.opt: natlib

world: bytecode
world.opt: native

all: clean world world.opt
liball: clean lib lib.opt
