# mira_test/cpp

This directory contains C++ code converted from Bernhard's Python.
(currently only tested on the eval board)

`cfg_mira.cpp` - configure the MIRA chip from a CSV config file

    cfg_mira [-c <config_file>] [s]
             -c to power-up and configure
             -s to shut down

`LaserControl.cpp` - control VCSEL and RGB LED

    LaserControl [-d dac_setting]        # set DAC 3080 = 6ma
                 [-l r g b]              # set RGB LED

`ReadFrame.cpp` - read one frame (with optional averaging)

    usage: ReadFrame [<output_file>] [-s <frames_to_sum>]
      reads complete 1600x480 RAW10 frame(s) in 12 slices
      up to 63 frames can be summed (before int16 overflow)
      data may be optionally written in raw int16 binary to file

`GetBFI.cpp` - switch to BFI mode, read and calculate BFI

    usage: usage: GetBFI [-n loops] [-f frames] [-v] [-s] [-p] [-d]
	  loops is number of times to calculate and print BFI
	  frames is number of frames to average per BFI point
	  -h prints help
	  -s displays raw sum data for debugging
	  -v verbose output for debugging
	  -p runs a text plot of BFI
	  -d dump data for debug

`display_test_sdl2.cpp` - display on the screen an image

    usage:  display_test_sdl2 [input_file]
      opens a window using the SDL2 library and displays image
      if no input file is specified, generates a test pattern
	  
      if needed to build on Pi:
	  
      # Install dependencies
      sudo apt-get install -y libsdl2-dev build-essential

`SpiDevice.cpp` - low-level SPI bus library

`MiraDevice.cpp` - MIRA interface class for I2C configuration

`MiraImage.cpp`  - MIRA class for image and BFI readout
