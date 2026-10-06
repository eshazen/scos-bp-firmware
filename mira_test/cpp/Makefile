
EXECS = display_test_sdl2 cfg_mira ReadFrame TestDump GetBFI

all: objects ${EXECS}

objects: ReadFrame.o MiraDevice.o SpiDevice.o MiraImage.o GetBFI.o

# asan is broken on R-pi :(
# CPPFLAGS = -g -O1 -fsanitize=address -fno-omit-frame-pointer -fsanitize=undefined
# LDFLAGS = -g -fsanitize=address,undefined

CPPFLAGS = -g -O0 -fno-inline -fno-omit-frame-pointer -fno-builtin

LDFLAGS = -g

clean:
	rm -f ${EXECS} *~ \#* *.o


GetBFI.o: GetBFI.cpp MiraImage.h SpiDevice.hh MiraDevice.h

TestDump.o: TestDump.cpp MiraImage.h SpiDevice.hh MiraDevice.h

MiraDevice.o: MiraDevice.cpp MiraDevice.h SpiDevice.hh

SpiDevice.o: SpiDevice.cpp SpiDevice.hh

MiraImage.o: MiraImage.cpp MiraImage.h MiraDevice.h

cfg_mira.o: cfg_mira.cpp MiraDevice.h SpiDevice.hh

ReadFrame.o: ReadFrame.cpp MiraImage.h SpiDevice.hh

ReadFrame: ReadFrame.o SpiDevice.o MiraImage.o
	g++ -o $@ $^ ${LDFLAGS}

cfg_mira: SpiDevice.o MiraDevice.o cfg_mira.o
	g++ -o $@ $^ ${LDFLAGS}

display_test_sdl2: display_test_sdl2.cpp
	g++ -std=c++17 -O2 -o display_test_sdl2 display_test_sdl2.cpp -lSDL2

TestDump: TestDump.o SpiDevice.o MiraImage.o
	g++ -o $@ $^ ${LDFLAGS}

GetBFI: GetBFI.o SpiDevice.o MiraImage.o
	g++ -o $@ $^ ${LDFLAGS}
