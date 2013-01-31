# If fastjet-config is not in your path, edit this line so that a full path
# to it is given
FASTJETCONFIG=fastjet-config
PREFIX=`$(FASTJETCONFIG) --prefix`

#------------------------------------------------------------------------
# things that are specific to this contrib
NAME=Template
SRCS=Template.cc
EXAMPLES=example
INSTALLED_HEADERS=Template.hh
#------------------------------------------------------------------------

CXX=g++
CXXFLAGS=-O3 -Wall -g $(shell $(FASTJETCONFIG) --cxxflags)
LDFLAGS=-lm $(shell $(FASTJETCONFIG) --libs)

OBJS  = $(SRCS:.cc=.o)
EXAMPLES_SRCS  = $(EXAMPLES:=.cc)
EXAMPLES_OBJS  = $(EXAMPLES:=.o)

install = $(SHELL) ../scripts/internal/install-sh
install_HEADER  = $(install) -c -m 644
install_LIB     = $(install) -c -m 644
install_DIR     = $(install) -d
install_DATA    = $(install) -c -m 644
install_PROGRAM = $(install) -c -s
install_SCRIPT  = $(install) -c

.PHONY: clean distclean examples check install

# compilation of the code (default target)
all: lib$(NAME).a

lib$(NAME).a: $(OBJS) 
	ar cru lib$(NAME).a $(OBJS)
	ranlib lib$(NAME).a

# building the examples
examples: $(EXAMPLES)

# the following construct alloews to build each of the examples listed
# in $EXAMPLES automatically
$(EXAMPLES): % : %.o all
	$(CXX) -o $@ $< -L. -l$(NAME) $(LDFLAGS)

# check that everything went fine
check: examples
	@for prog in $(EXAMPLES); do\
	  ../scripts/internal/check.sh $${prog} ../data/single-event.dat || exit 1; \
	done
	@echo "All tests successful"

# cleaning the directory
clean:
	rm -f *~ *.o

distclean: clean
	rm -f lib$(NAME).a $(EXAMPLES)

# install things in PREFIX/...
install: all
	$(install_DIR) $(PREFIX)/include/fastjet/contrib
	for header in $(INSTALLED_HEADERS); do\
	  $(install_HEADER) $$header $(PREFIX)/include/fastjet/contrib/\
	done
	$(install_DIR) $(PREFIX)/lib
	$(install_LIB) lib$(NAME).a $(PREFIX)/lib

depend:
	makedepend -Y --   -- $(SRCS) $(EXAMPLES_SRCS)
