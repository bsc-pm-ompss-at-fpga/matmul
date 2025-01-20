.PHONY: clean all help
all: help

PROGRAM_ = matmul

help:
	@echo 'Supported targets:           $(PROGRAM_)-p, $(PROGRAM_)-i, $(PROGRAM_)-d, $(PROGRAM_)-seq, design-p, design-i, design-d, bitstream-p, bitstream-i, bitstream-d, clean, help'
	@echo 'FPGA env. variables:         BOARD, FPGA_CLOCK, FPGA_MEMORY_PORT_WIDTH, MEMORY_INTERLEAVING_STRIDE, SIMPLIFY_INTERCONNECTION, INTERCONNECT_OPT, INTERCONNECT_REGSLICE, FLOORPLANNING_CONSTR, SLR_SLICES, PLACEMENT_FILE'
	@echo 'Benchmark env. variables:    MATMUL_BLOCK_SIZE, MATMUL_BLOCK_II, MATMUL_NUM_ACCS'
	@echo 'Compiler env. variables:     CFLAGS, CROSS_COMPILE, LDFLAGS'

# FPGA bitstream parameters
FPGA_CLOCK             ?= 200
FPGA_MEMORY_PORT_WIDTH ?= 128
INTERCONNECT_OPT       ?= performance

CLANG_TARGET =
ifdef CROSS_COMPILE
	CLANG_TARGET += -target $(CROSS_COMPILE)
endif

COMPILER_         = clang++
COMPILER_FLAGS_   = $(CFLAGS) $(CLANG_TARGET) -fompss-2 -fompss-fpga-wrapper-code
COMPILER_FLAGS_I_ = -fompss-fpga-instrumentation
COMPILER_FLAGS_D_ = -g -fompss-fpga-hls-tasks-dir $(PWD)
LINKER_FLAGS_     = $(LDFLAGS)

AIT_FLAGS__        = --name=$(PROGRAM_) --board=$(BOARD) -c=$(FPGA_CLOCK)
AIT_FLAGS_DESIGN__ = --to_step=design
AIT_FLAGS_D__      = --debug_intfs=both -k -i -v

# Optional optimization FPGA variables
ifdef FPGA_MEMORY_PORT_WIDTH
	COMPILER_FLAGS_ += -fompss-fpga-memory-port-width $(FPGA_MEMORY_PORT_WIDTH)
endif
ifdef MEMORY_INTERLEAVING_STRIDE
	AIT_FLAGS__ += --memory_interleaving_stride=$(MEMORY_INTERLEAVING_STRIDE)
endif
ifdef SIMPLIFY_INTERCONNECTION
	AIT_FLAGS__ += --simplify_interconnection
endif
ifdef INTERCONNECT_PRIORITIES
	AIT_FLAGS__ += --interconnect_priorities
endif
ifdef INTERCONNECT_OPT
	AIT_FLAGS__ += --interconnect_opt=$(INTERCONNECT_OPT)
endif
ifdef INTERCONNECT_REGSLICE
	AIT_FLAGS__ += --interconnect_regslice=$(INTERCONNECT_REGSLICE)
endif
ifdef FLOORPLANNING_CONSTR
	AIT_FLAGS__ += --floorplanning_constr=$(FLOORPLANNING_CONSTR)
endif
ifdef SLR_SLICES
	AIT_FLAGS__ += --slr_slices=$(SLR_SLICES)
endif
ifdef PLACEMENT_FILE
	AIT_FLAGS__ += --placement_file=$(PLACEMENT_FILE)
endif
ifdef DISABLE_UTILIZATION_CHECK
	AIT_FLAGS__ += --disable_utilization_check
endif
ifdef DISABLE_CREATOR_PORTS
	AIT_FLAGS__ += --disable_creator_ports
endif

AIT_FLAGS_        = -fompss-fpga-ait-flags "$(AIT_FLAGS__)"
AIT_FLAGS_DESIGN_ = -fompss-fpga-ait-flags "$(AIT_FLAGS_DESIGN__)"
AIT_FLAGS_D_      = -fompss-fpga-ait-flags "$(AIT_FLAGS_D__)"

# Matmul parameters
MATMUL_BLOCK_SIZE ?= 64
MATMUL_BLOCK_II   ?= 2
MATMUL_NUM_ACCS   ?= 1
NANOS6_HOME       ?= $(INSTALL_DIR)/nanos6

# Preprocessor flags
COMPILER_FLAGS_ += -DBOARD=\"$(BOARD)\" -DFPGA_MEMORY_PORT_WIDTH=$(FPGA_MEMORY_PORT_WIDTH) -DFPGA_CLOCK=$(FPGA_CLOCK)
COMPILER_FLAGS_ += -DMATMUL_BLOCK_SIZE=$(MATMUL_BLOCK_SIZE) -DMATMUL_BLOCK_II=$(MATMUL_BLOCK_II) -DMATMUL_NUM_ACCS=$(MATMUL_NUM_ACCS)

ifdef USE_URAM
	COMPILER_FLAGS_ += -DUSE_URAM
endif

ifdef USE_DOUBLE
	COMPILER_FLAGS_ += -DUSE_DOUBLE
else ifdef USE_HALF
	COMPILER_FLAGS_ += -DUSE_HALF -I$(VIVADO_DIR)/include -DHLS_NO_XIL_FPO_LIB
	#gmp and mpfr are expected to be installed, otherwise compile using vivado libraries
	# by uncommenting the following line
	# LINKER_FLAGS_ += -L$(VIVADO_DIR)lib/lnx64.o/Ubuntu
	VIVADO_DIR=/tools/Xilinx/Vivado/2020.1
	LINKER_FLAGS_  += -L$(VIVADO_DIR)//lnx64/tools/fpo_v7_0/ -lIp_floating_point_v7_0_bitacc_cmodel -lmpfr -lgmp
	LINKER_FLAGS_ += -Wl,-rpath=$(VIVADO_DIR)/lnx64/tools/fpo_v7_0/
endif

PROGRAM_SRC = \
	src/matmul.cpp

$(PROGRAM_)-p: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-i: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-d: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) $^ -o $@ $(LINKER_FLAGS_)

$(PROGRAM_)-seq: $(PROGRAM_SRC)
	$(COMPILER_) $(COMPILER_FLAGS_) $^ -o $@ $(LINKER_FLAGS_)

design-p: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

design-i: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

design-d: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_DESIGN_) $(AIT_FLAGS_D_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-p: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) \
		$(AIT_FLAGS_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-i: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_I_) \
		$(AIT_FLAGS_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

bitstream-d: $(PROGRAM_SRC)
	$(eval TMPFILE := $(shell mktemp))
	$(COMPILER_) $(COMPILER_FLAGS_) $(COMPILER_FLAGS_D_) \
		$(AIT_FLAGS_) $(AIT_FLAGS_D_) \
		$^ -o $(TMPFILE) $(LINKER_FLAGS_)
	rm $(TMPFILE)

clean:
	rm -fv *.o $(PROGRAM_)-? $(PROGRAM_)_hls_automatic_clang.cpp ait_extracted.json
	rm -frv $(PROGRAM_)_ait

