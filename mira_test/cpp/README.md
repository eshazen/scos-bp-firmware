# mira_test/cpp

This directory contains two sample programs to readout and display
RAW10 images from the Mira220+FPGA evaluation board or Pi Hat.

(currently only tested on the eval board)

`get_frame_spi.cpp` 

    usage:  get_frame_spi [-s frames_to_sum] [output_file]
      reads one complete 1600x480 RAW10 frame in 12 slices
      up to 63 frames can be summed (before int16 overflow)
      data may be optionally written in raw int16 binary to file

`display_test_sdl2.cpp`

    usage:  display_test_sdl2 [input_file]
      opens a window using the SDL2 library and displays image
      if no input file is specified, generates a test pattern

