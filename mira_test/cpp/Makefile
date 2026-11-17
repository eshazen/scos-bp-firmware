
EXECS = display_test_sdl2 cfg_mira ReadFrame GetBFI LaserControl

all: ${EXECS}

# all: objects ${EXECS}

# objects: ReadFrame.o MiraDevice.o SpiDevice.o MiraImage.o GetBFI.o Serial_AI.o DAC_control_AI.o

# Define this for the red pi hat board (enable UART comms)
CPPDEFINES = -DPI_HAT_UART

CPPFLAGS = -g -O0 -fno-inline -fno-omit-frame-pointer -fno-builtin ${CPPDEFINES}

LDFLAGS = -g

clean:
	rm -f ${EXECS} *~ \#* *.o

LaserControl.o: DAC_control_AI.cpp LaserControl.cpp

GetBFI.o: GetBFI.cpp MiraImage.h SpiDevice.hh MiraDevice.h ASCII_Plot_AI.c

#TestDump.o: TestDump.cpp MiraImage.h SpiDevice.hh MiraDevice.h

MiraDevice.o: MiraDevice.cpp MiraDevice.h SpiDevice.hh Serial_AI.hh

SpiDevice.o: SpiDevice.cpp SpiDevice.hh

MiraImage.o: MiraImage.cpp MiraImage.h MiraDevice.h

cfg_mira.o: cfg_mira.cpp MiraDevice.h SpiDevice.hh Serial_AI.hh

ReadFrame.o: ReadFrame.cpp MiraImage.h SpiDevice.hh

ReadFrame: ReadFrame.o SpiDevice.o MiraImage.o
	g++ -o $@ $^ ${LDFLAGS}

cfg_mira: SpiDevice.o MiraDevice.o cfg_mira.o Serial_AI.o
	g++ -o $@ $^ ${LDFLAGS}

display_test_sdl2: display_test_sdl2.cpp
	g++ -std=c++17 -O2 -o display_test_sdl2 display_test_sdl2.cpp -lSDL2

#TestDump: TestDump.o SpiDevice.o MiraImage.o
#	g++ -o $@ $^ ${LDFLAGS}

GetBFI: GetBFI.o SpiDevice.o MiraImage.o
	g++ -o $@ $^ ${LDFLAGS}

LaserControl: LaserControl.o DAC_control_AI.o
	g++ -o $@ $^ ${LDFLAGS}
