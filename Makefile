#=======================================================================
# GENERAL SETUP
#=======================================================================

#-----------------------------------------------------------------------
# Force make to use sh, so that we can write shell commands uniformly
# on different systems
#-----------------------------------------------------------------------

SHELL     = /bin/sh

#-----------------------------------------------------------------------
# Test of specifying the architecture by hand
#-----------------------------------------------------------------------

# To determine the architecture from the system:
#
ARCH = 
#
# To specify i386 architecture
#
# ARCH = i386
#
# To specify Intel x86_64 architecture
#
# ARCH = x86_64

#-----------------------------------------------------------------------
# Get variables we can determine from the system
#-----------------------------------------------------------------------

TOOLSDIR := $(shell pwd)
OS       := $(shell uname -s)
SCRIPTDIR = $(TOOLSDIR)/scripts

LIBSUFFIX = so
ifeq ($(OS),Linux)
  PROC := $(shell uname -i)
else
  PROC    := $(shell uname -p)
  RELEASE := $(shell uname -r)
  LIBSUFFIX = dylib
endif

RELEASELIST = $(subst ., ,$(RELEASE))
MAJVERS     = $(firstword $(RELEASELIST))

#-----------------------------------------------------------------------                                    
# Check the processor type for bitness                                                                      
#-----------------------------------------------------------------------                                    

# Ordinary Linux systems report the architecture in uname                                                   

ifeq ($(strip $(PROC)),i386)
  COMPILE_FOR_64BIT = 0
else
  COMPILE_FOR_64BIT = 1
endif

# However, later versions of Darwin can have 32-bit processor, with                                         
# 64-bit architecture.  I don't know how to determine this generally                                        
# at this point, but Darwin 10+ systems I've played with require                                            
# 64-bit libraries even though uname reports the architecture as i386                                       

ifeq ($(OS),Darwin)
  ifneq ($(MAJVERS),8)
    COMPILE_FOR_64BIT = 1
  endif
endif

#-----------------------------------------------------------------------
# Now override depending on the ARCH variable
#-----------------------------------------------------------------------

ifeq (i386,$(strip $(ARCH)))
  COMPILE_FOR_64BIT = 0
else
  ifeq (x86_64,$(strip $(ARCH)))
    COMPILE_FOR_64BIT = 1
  endif
endif

#-----------------------------------------------------------------------
# Now based on the COMPILE_FOR_64BIT variable, set appropriate 
# compiler/linker flags
#-----------------------------------------------------------------------

BITFLAG = 
ifeq ($(COMPILE_FOR_64BIT),1)
  BITFLAG = -m64
else
  BITFLAG = -m32
endif

#-----------------------------------------------------------------------                                    
# Determine what we can about fortran compilers present on the system                                       
#-----------------------------------------------------------------------                                    

FCOMPG77  := $(shell which g77)
FCOMPGFOR := $(shell which gfortran)

FCOMP =
FFLAG =
ifneq (,$(strip $(FCOMPG77)))
  FCOMP = g77
  FFLAG = -fPIC -O -Wno-globals
endif

ifneq (,$(strip $(FCOMPGFOR)))
  FCOMP = gfortran
  FFLAG = -fPIC -O
endif

#=======================================================================
# TARGETS
#=======================================================================

#-----------------------------------------------------------------------
# All targets
#-----------------------------------------------------------------------

ALLTARGETS = dirs fftw3 gsl cfitsio miriad sfd

ifneq (,$(FCOMP)) 
ALLTARGETS += pgplot
endif

all: $(ALLTARGETS)

#-----------------------------------------------------------------------
# Dirs
#-----------------------------------------------------------------------

dirs:
	@if [ ! -d lib ] ; then mkdir lib ; fi ;
	@if [ ! -d include ] ; then mkdir include ; fi ;
	@if [ ! -d src ] ; then mkdir src ; fi ;

dirs_clean:
	@if [ -d lib ] ; then \rm -rf lib ; fi ;
	@if [ -d include ] ; then \rm -rf include ; fi ;
	@if [ -d share ] ; then \rm -rf share ; fi ;
	@if [ -d man ] ; then \rm -rf man ; fi ;
	@if [ -d bin ] ; then \rm -rf bin ; fi ;
	@if [ -d src ] ; then \rm -rf src ; fi ;

#-----------------------------------------------------------------------
# PGPLOT 
#-----------------------------------------------------------------------

PGPLOTVERS   = 5.2
PGPLOTPREFIX = archive/pgplot$(PGPLOTVERS)
PGPLOTDIR    = pgplot

PGX11LDPATH    = /usr/X11R6/lib # 32-bit Linux, all Darwin compiles                                         
ifeq ($(OS),Linux)
  ifeq ($(COMPILE_FOR_64BIT),1)
    PGX11LDPATH    = /usr/X11R6/lib64 # 64-bit Linux compile                                                
  endif
endif

PGGCCCOMPATLIB =  # Linux compile                                                                           
ifeq ($(OS),Darwin)
  ifeq ($(COMPILE_FOR_64BIT),0)
    PGGCCCOMPATLIB = -L/usr/lib -lgcc # 32-bit Darwin compile                                               
  endif
endif

ifeq ($(OS),Darwin)
  PGSHAREDFLAGS  = $(BITFLAG) -dynamiclib -flat_namespace -undefined suppress # Darwin compile
else
  PGSHAREDFLAGS  = $(BITFLAG) -shared # linux compile                                                                    
endif

PGFFLAGC       = 'FFLAGC=-u -Wall -fPIC -O' # default linux                                                 
ifeq ($(OS),Linux)
  ifeq ($(COMPILE_FOR_64BIT),1)
    PGFFLAGC = 'FFLAGC=-fPIC -O'          # 64-bit darwin                                                   
  endif
endif

PGCCOMPL = gcc $(BITFLAG)
PGFCOMPL = $(FCOMP) $(BITFLAG)

pgplot_unpack:
	@if [ -f $(PGPLOTPREFIX).tar.gz ] ; then cp $(PGPLOTPREFIX).tar.gz $(PGPLOTPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(PGPLOTPREFIX)Copy.tar.gz ] ; then gunzip $(PGPLOTPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(PGPLOTPREFIX)Copy.tar ] ; then tar xvf $(PGPLOTPREFIX)Copy.tar ; rm $(PGPLOTPREFIX)Copy.tar ; mv $(PGPLOTDIR) src ; fi ;

pgplot_create_makefile:
	@if [ -d src/$(PGPLOTDIR) ] ; then \
	  mv src/$(PGPLOTDIR) src/pgplot_src ; \
	  mkdir src/$(PGPLOTDIR) ; cp src/pgplot_src/drivers.list src/$(PGPLOTDIR); \
	  $(SCRIPTDIR)/replace 'GRIMAX = 8' 'GRIMAX = 100' src/pgplot_src/src/grpckg1.inc ; \
	  $(SCRIPTDIR)/replace 'PGMAXD=8' 'PGMAXD=100' src/pgplot_src/src/pgplot.inc ; \
	  $(SCRIPTDIR)/replace '! XWDRIV' '  XWDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  $(SCRIPTDIR)/replace '! TKDRIV' '  TKDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  $(SCRIPTDIR)/replace '! PSDRIV' '  PSDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  cd src/$(PGPLOTDIR); ../pgplot_src/makemake ../pgplot_src linux g77_gcc ; \
	fi ;

pgplot_create_makefile_old:
	@if [ -d src/$(PGPLOTDIR) ] ; then \
	  mv src/$(PGPLOTDIR) src/pgplot_src ; \
	  mkdir src/$(PGPLOTDIR) ; cp src/pgplot_src/drivers.list src/$(PGPLOTDIR); \
	  $(SCRIPTDIR)/replace 'GRIMAX = 8' 'GRIMAX = 100' src/pgplot_src/src/grpckg1.inc ; \
	  $(SCRIPTDIR)/replace 'PGMAXD=8' 'PGMAXD=100' src/pgplot_src/src/pgplot.inc ; \
	  $(SCRIPTDIR)/replace '! XWDRIV' '  XWDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  $(SCRIPTDIR)/replace '! TKDRIV' '  TKDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  $(SCRIPTDIR)/replace '! PSDRIV' '  PSDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  $(SCRIPTDIR)/replace '! PNDRIV' '  PNDRIV' src/$(PGPLOTDIR)/drivers.list ; \
	  cd src/$(PGPLOTDIR); ../pgplot_src/makemake ../pgplot_src linux g77_gcc ; \
	fi ;

pgplot_create_cpgrule:
	@if [ -d src/$(PGPLOTDIR) ] ; then \
	  cd src/$(PGPLOTDIR); \
	  echo -e '\012libcpgplot.so: \044(PG_SOURCE) pgbind' >> cpgMakefile ; \
	  echo -e '\011./pgbind \044(PGBIND_FLAGS) -h -w \044(PG_SOURCE)' >> cpgMakefile ; \
	  echo -e '\011\044(CCOMPL) -c \044(CFLAGC) cpg*.c' >> cpgMakefile ; \
	  echo -e '\011rm -f cpg*.c' >> cpgMakefile ; \
	  echo -e '\011gcc -shared  -o libcpgplot.so cpg*.o' >> cpgMakefile ; \
	  echo -e '\011rm -f cpg*.o' >> cpgMakefile ; \
	fi ;

pgplot_edit_cpgrule:
	-$(SCRIPTDIR)/replace '-e ' '' src/$(PGPLOTDIR)/cpgMakefile

pgplot_make:
	@if [ -d src/$(PGPLOTDIR) ] ; then \
	  cd src/$(PGPLOTDIR); \
	  cat cpgMakefile >> makefile ; \
	  \rm cpgMakefile ; \
	  $(SCRIPTDIR)/replace 'libcpgplot.a cpgplot.h cpgdemo' 'libcpgplot.a libcpgplot.so cpgplot.h cpgdemo' makefile ; \
	  $(SCRIPTDIR)/replace 'TK_INCL=-I/usr/include' 'TK_INCL=-I$(TOOLSDIR)/include' makefile ; \
	  $(SCRIPTDIR)/replace 'TK_LIBS=-L/usr/lib -ltk -ltcl -L/usr/X11R6/lib -lX11 -ldl' 'TK_LIBS=-L$(TOOLSDIR)/lib -ltk -ltcl -L$(PGX11LDPATH) -lX11 $(PGGCCCOMPATLIB) -ldl' makefile ; \
	  $(SCRIPTDIR)/replace 'gcc -shared' 'gcc $(PGSHAREDFLAGS)' makefile ; \
	  $(SCRIPTDIR)/replace 'FFLAGC=-u -Wall -fPIC -O' 'FFLAGC=-fPIC -O' makefile ; \
	  $(SCRIPTDIR)/replace 'CCOMPL=gcc' 'CCOMPL=$(PGCCOMPL)' makefile ; \
	  $(SCRIPTDIR)/replace 'FCOMPL=g77' 'FCOMPL=$(PGFCOMPL)' makefile ; \
	  $(SCRIPTDIR)/replace 'libpgplot.so' 'libpgplot.$(LIBSUFFIX)' makefile ; \
	  $(SCRIPTDIR)/replace 'libcpgplot.so' 'libcpgplot.$(LIBSUFFIX)' makefile ; \
	  $(SCRIPTDIR)/replace '-lpng' '-L/usr/local/lib -lpng' makefile ; \
	  make ; make cpg ; cp lib* ../../lib ; cp *.h ../../include ; cp grfont.dat ../../lib ; cp pgxwin_server ../../bin ; cd ../../ \
; \
	fi ;

pgplot: dirs pgplot_unpack pgplot_create_makefile pgplot_create_cpgrule pgplot_edit_cpgrule pgplot_make

pgplot_clean:
	@if [ -d src/pgplot ] ; then \rm -rf src/pgplot ; fi ;
	@if [ -d src/pgplot_src ] ; then \rm -rf src/pgplot_src ; fi ;

#-----------------------------------------------------------------------
# FFTW3
#-----------------------------------------------------------------------

FFTWVERS    = 3.2.1
FFTWPREFIX  = archive/fftw-$(FFTWVERS)
FFTWDIR     = fftw-$(FFTWVERS)

fftw3: dirs fftw3_configure
	@if [ -d src/$(FFTWDIR) ] ; then \
	  cd src/$(FFTWDIR) ; \
	  make ; make install ; cd ../../ ; \
	fi ;

fftw3_configure:
	@if [ -f $(FFTWPREFIX).tar.gz ] ; then cp $(FFTWPREFIX).tar.gz $(FFTWPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(FFTWPREFIX)Copy.tar.gz ] ; then gunzip $(FFTWPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(FFTWPREFIX)Copy.tar ] ; then tar xvf $(FFTWPREFIX)Copy.tar ; rm $(FFTWPREFIX)Copy.tar ; mv $(FFTWDIR) src ; fi ;
	@if [ -d src/$(FFTWDIR) ] ; then \
	  cd src/$(FFTWDIR) ; ./configure --prefix=$(TOOLSDIR) --exec_prefix=$(TOOLSDIR) --enable-shared ; \
	  $(SCRIPTDIR)/replace 'CFLAGS = ' 'CFLAGS = $(BITFLAG) ' Makefile ; \
	  $(SCRIPTDIR)/replace 'CPPFLAGS = ' 'CPPFLAGS = $(BITFLAG) ' Makefile ; \
	  $(SCRIPTDIR)/replace 'FFLAGS = ' 'FFLAGS = $(BITFLAG) ' Makefile ; \
	  $(SCRIPTDIR)/replace 'gcc -std=gnu99' 'gcc $(BITFLAG) -std=gnu99' Makefile ; \
	  echo 'AM_CFLAGS = $(BITFLAG)' >> Makefile ; \
	  echo 'export AM_CFLAGS' >> Makefile ; \
	fi ;

fftw3_clean:
	@if [ -d src/$(FFTWDIR) ] ; then \rm -rf src/$(FFTWDIR) ; fi ;

#-----------------------------------------------------------------------
# GSL
#-----------------------------------------------------------------------

GSLVERS    = 1.14
GSLPREFIX  = archive/gsl-$(GSLVERS)
GSLDIR     = gsl-$(GSLVERS)

gsl: dirs gsl_configure
	@if [ -d src/$(GSLDIR) ] ; then \
	  cd src/$(GSLDIR) ; \
	  make ; make install ; cd ../../ ; \
	fi ;

gsl_configure:
	@if [ -f $(GSLPREFIX).tar.gz ] ; then cp $(GSLPREFIX).tar.gz $(GSLPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(GSLPREFIX)Copy.tar.gz ] ; then gunzip $(GSLPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(GSLPREFIX)Copy.tar ] ; then tar xvf $(GSLPREFIX)Copy.tar ; rm $(GSLPREFIX)Copy.tar ; mv $(GSLDIR) src ; fi ;
	@if [ -d src/$(GSLDIR) ] ; then \
	  cd src/$(GSLDIR) ; ./configure --prefix=$(TOOLSDIR) --exec_prefix=$(TOOLSDIR) --enable-shared ; \
	  $(SCRIPTDIR)/replace 'CFLAGS = ' 'CFLAGS = $(BITFLAG) ' Makefile ; \
	  $(SCRIPTDIR)/replace 'CPPFLAGS = ' 'CPPFLAGS = $(BITFLAG) ' Makefile ; \
	  $(SCRIPTDIR)/replace 'FFLAGS = ' 'FFLAGS = $(BITFLAG) ' Makefile ; \
	  $(SCRIPTDIR)/replace 'gcc -std=gnu99' 'gcc $(BITFLAG) -std=gnu99' Makefile ; \
	  echo 'AM_CFLAGS = $(BITFLAG)' >> Makefile ; \
	  echo 'export AM_CFLAGS' >> Makefile ; \
	fi ;

gsl_clean:
	@if [ -d src/$(GSLDIR) ] ; then \rm -rf src/$(GSLDIR) ; fi ;

#-----------------------------------------------------------------------
# CFITSIO
#-----------------------------------------------------------------------

CFITSIOVERS    = 3250
CFITSIOPREFIX  = archive/cfitsio$(CFITSIOVERS)
CFITSIODIR     = cfitsio

cfitsio: dirs
	@if [ -f $(CFITSIOPREFIX).tar.gz ] ; then cp $(CFITSIOPREFIX).tar.gz $(CFITSIOPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(CFITSIOPREFIX)Copy.tar.gz ] ; then gunzip $(CFITSIOPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(CFITSIOPREFIX)Copy.tar ] ; then tar xvf $(CFITSIOPREFIX)Copy.tar ; rm $(CFITSIOPREFIX)Copy.tar ; mv $(CFITSIODIR) src ; fi ;
	@if [ -d src/$(CFITSIODIR) ] ; then \
	  cd src/$(CFITSIODIR) ; ./configure --prefix=$(TOOLSDIR) --exec_prefix=$(TOOLSDIR) ; \
	  $(SCRIPTDIR)/replace '-g -O2' '$(BITFLAG) -g -O2' Makefile; \
	  make ; make shared ; make install ; cd ../../ ; \
	fi ;

cfitsio_clean:
	@if [ -d src/$(CFITSIODIR) ] ; then \rm -rf src/$(CFITSIODIR) ; fi ;

#-----------------------------------------------------------------------
# MIRIAD
#-----------------------------------------------------------------------

MIRIADPREFIX  = archive/miriad
MIRIADDIR     = miriad


ifneq ($(OS),Darwin)
miriad: dirs
	@if [ -f $(MIRIADPREFIX).tar.gz ] ; then cp $(MIRIADPREFIX).tar.gz $(MIRIADPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(MIRIADPREFIX)Copy.tar.gz ] ; then gunzip $(MIRIADPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(MIRIADPREFIX)Copy.tar ] ; then tar xvf $(MIRIADPREFIX)Copy.tar ; rm $(MIRIADPREFIX)Copy.tar ; mv $(MIRIADDIR) src ; fi ;
	@if [ -d src/$(MIRIADDIR) ] ; then \
	  $(SCRIPTDIR)/replace 'LIBSO_DIR ='  'LIBSO_DIR = $(TOOLSDIR)/lib' src/$(MIRIADDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'LIBSO_SUFFIX ='  'LIBSO_SUFFIX = .so' src/$(MIRIADDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'LIBSO_FLAGS ='  'LIBSO_FLAGS = $(BITFLAG) -shared' src/$(MIRIADDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'CC = cc' 'CC = gcc $(BITFLAG)' src/$(MIRIADDIR)/Makefile ; \
	  cd src/$(MIRIADDIR) ; make libs; cp miriad.h $(TOOLSDIR)/include; cp sysdep.h $(TOOLSDIR)/include; cd ../../ ; \
	fi ;
else
miriad: dirs
	@if [ -f $(MIRIADPREFIX).tar.gz ] ; then cp $(MIRIADPREFIX).tar.gz $(MIRIADPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(MIRIADPREFIX)Copy.tar.gz ] ; then gunzip $(MIRIADPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(MIRIADPREFIX)Copy.tar ] ; then tar xvf $(MIRIADPREFIX)Copy.tar ; rm $(MIRIADPREFIX)Copy.tar ; mv $(MIRIADDIR) src ; fi ;
	@if [ -d src/$(MIRIADDIR) ] ; then \
	  $(SCRIPTDIR)/replace 'LIBSO_DIR ='  'LIBSO_DIR = $(TOOLSDIR)/lib' src/$(MIRIADDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'LIBSO_SUFFIX ='  'LIBSO_SUFFIX = .dylib' src/$(MIRIADDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'LIBSO_FLAGS ='  'LIBSO_FLAGS = $(BITFLAG) -dynamiclib -undefined dynamic_lookup' src/$(MIRIADDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'CC = cc' 'CC = gcc $(BITFLAG)' src/$(MIRIADDIR)/Makefile ; \
	  cd src/$(MIRIADDIR) ; make libs; cp miriad.h $(TOOLSDIR)/include; cp sysdep.h $(TOOLSDIR)/include; cd ../../ ; \
	fi ;
endif

miriad_clean:
	@if [ -d src/$(MIRIADDIR) ] ; then \rm -rf src/$(MIRIADDIR) ; fi ;


#-----------------------------------------------------------------------
# SFD
#-----------------------------------------------------------------------

SFDPREFIX  = archive/sfd
SFDDIR     = sfd

sfd:
	@if [ -f $(SFDPREFIX).tar.gz ] ; then cp $(SFDPREFIX).tar.gz $(SFDPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(SFDPREFIX)Copy.tar.gz ] ; then gunzip $(SFDPREFIX)Copy.tar.gz ; fi ;
	@if [ -f $(SFDPREFIX)Copy.tar ] ; then tar xvf $(SFDPREFIX)Copy.tar ; rm $(SFDPREFIX)Copy.tar ; mv $(SFDDIR) src ; fi ;
	@if [ -d src/$(SFDDIR) ] ; then \
	  $(SCRIPTDIR)/replace 'CCFLAGS = -fPIC' 'CCFLAGS = $(BITFLAG) -fPIC' src/$(SFDDIR)/Makefile ; \
	  $(SCRIPTDIR)/replace 'LIBSO_FLAGS  = ' 'LIBSO_FLAGS  = $(BITFLAG) ' src/$(SFDDIR)/Makefile ; \
	  cd src/$(SFDDIR) ; make libso; mv libSfd.$(LIBSUFFIX) $(TOOLSDIR)/lib/libSfd.$(LIBSUFFIX); cp subs_predict.h $(TOOLSDIR)/include; cp interface.h $(TOOLSDIR)/include; cd ../../ ; \
	fi ;

sfd_clean:
	@if [ -d src/$(SFDDIR) ] ; then \rm -rf src/$(SFDDIR) ; fi ;
	@if [ -f include/subs_predict.h ] ; then \rm -rf include/subs_predict.h ; fi ;
	@if [ -f include/interface.h ] ; then \rm -rf include/interface.h ; fi ;
	@if [ -f lib/libSfd.$(LIBSUFFIX) ] ; then \rm -rf lib/libSfd.$(LIBSUFFIX) ; fi ;

#-----------------------------------------------------------------------
# Clean directive
#-----------------------------------------------------------------------

clean: dirs_clean pgplot_clean fftw3_clean gsl_clean cfitsio_clean miriad_clean sfd_clean


