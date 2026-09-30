all: display_test_sdl2 get_frame_spi MiraDevice.o cfg_mira ReadFrame

clean:
	rm -f display_test_sdl2 get_frame_spi MiraDevice.o cfg_mira ReadFrame *~ \#* *.o

MiraDevice.o: MiraDevice.cpp MiraDevice.h SpiDevice.hh

SpiDevice.o: SpiDevice.cpp SpiDevice.hh

MiraImage.o: MiraImage.cpp MiraImage.h MiraDevice.h

cfg_mira.o: cfg_mira.cpp MiraDevice.h SpiDevice.hh

ReadFrame.o: ReadFrame.cpp MiraImage.h SpiDevice.hh

ReadFrame: ReadFrame.o SpiDevice.o MiraImage.o
	g++ -o $@ $^

cfg_mira: SpiDevice.o MiraDevice.o cfg_mira.o
	g++ -o $@ $^

display_test_sdl2: display_test_sdl2.cpp
	g++ -std=c++17 -O2 -o display_test_sdl2 display_test_sdl2.cpp -lSDL2

get_frame_spi: SpiDevice.o get_frame_spi.o
	g++ -o $@ $^
