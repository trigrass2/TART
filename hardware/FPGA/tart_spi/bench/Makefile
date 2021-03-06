IVC=iverilog
INC=../include/
OPT=-D__icarus -Wall -I$(INC)

OUT=../build

# Source directories:
RTL =../verilog
FIFO=$(RTL)/fifo
BUS =$(RTL)/bus
SPI =$(RTL)/spi

# Some Wishbone-like cores:
WBL =$(BUS)/wb_reset.v $(BUS)/wb_sram.v $(BUS)/wb_sram_dual_port.v $(BUS)/wb_prefetch.v $(BUS)/wb_stream.v

# Common library cores:
LIB =$(FIFO)/afifo16.v $(FIFO)/fifo_dc_gray.v $(FIFO)/afifo_gray.v $(RTL)/tart_aquire.v $(RTL)/tart_control.v $(WBL) $(RTL)/xilinx/RAM32X6_SDP.v $(RTL)/xilinx/RAMB8X32_SDP.v $(RTL)/xilinx/RAMB8X36_SDP.v $(RTL)/xilinx/MUX8.v

# Simulation-only files:
XIL =xilinx
SIM =$(XIL)/DSP48A1.v $(XIL)/RAMB16_S9_S36.v

DEP =$(LIB) $(SPI)/spi_target.v $(SPI)/spi_layer.v $(SPI)/spi_slave.v $(SPI)/spi_master.v $(RTL)/dram_prefetch.v $(RTL)/tart_spi.v
COR =$(RTL)/tart_visibilities.v $(RTL)/tart_correlator.v $(RTL)/correlator_block_SDP.v $(RTL)/correlator_block_DSP.v $(RTL)/correlator.v $(RTL)/correlator_SDP.v $(RTL)/correlator_DSP.v $(RTL)/rmw_address_unit.v $(RTL)/correlate_cos_sin.v $(RTL)/correlate_cos_sin_DSP.v $(RTL)/fake_hilbert.v $(RTL)/ones_count.v

all: ${DEP} tart_soc_tb.v
	$(IVC) $(OPT) -o $(OUT)/tart.out $(DEP) $(SIM) tart_soc_tb.v

spi: ${DEP} tart_spi_tb.v
	$(IVC) $(OPT) -o $(OUT)/tart.out $(DEP) $(SIM) tart_spi_tb.v

cor: ${DEP} ${COR} tart_correlator_tb.v
	$(IVC) $(OPT) -o $(OUT)/tart.out $(DEP) $(COR) $(SIM) tart_correlator_tb.v

.PHONY: run
run: all
	@$(OUT)/tart.out

dir:
	@mkdir $(OUT)

.PHONY: clean
clean:
	rm -f *~ $(OUT)/tart.out
