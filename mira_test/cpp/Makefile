all: display_test_sdl2 get_frame_spi MiraDevice.o cfg_mira

clean:
	rm -f display_test_sdl2 get_frame_spi MiraDevice.o cfg_mira *~ \#*

MiraDevice.o: MiraDevice.cpp MiraDevice.h SpiDevice.hh

cfg_mira.o: cfg_mira.cpp MiraDevice.h SpiDevice.hh

cfg_mira: cfg_mira.o MiraDevice.o
	g++ -o cfg_mira cfg_mira.o MiraDevice.o

display_test_sdl2: display_test_sdl2.cpp
	g++ -std=c++17 -O2 -o display_test_sdl2 display_test_sdl2.cpp -lSDL2

get_frame_spi: get_frame_spi.cpp
	g++ -o get_frame_spi get_frame_spi.cpp

