all: display_test_sdl2 get_frame_spi

MiraDevice.o: MiraDevice.cpp Miradevice.h SpiDevice.hh

clean:
	rm -f display_test_sdl2 get_frame_spi

display_test_sdl2: display_test_sdl2.cpp
	g++ -std=c++17 -O2 -o display_test_sdl2 display_test_sdl2.cpp -lSDL2

get_frame_spi: get_frame_spi.cpp
	g++ -o get_frame_spi get_frame_spi.cpp

