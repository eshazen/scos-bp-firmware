//
// Class created from bits of get_frame_spi and plot_rt_bfi_spi
// to support image transfer in various modes from the Mira220
//

#ifndef MIRA_IMAGE_H
#define MIRA_IMAGE_H

#include <iostream>
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include <unistd.h>
#include <cstdint>
#include "MiraDevice.h"

// must match sensor config
#define WIDTH 1600
#define HEIGHT 480

#define SPI_SPEED_HZ 10000000
#define USLEEP_DELAY 1000

class MiraImage {
private:
  std::vector<uint8_t> rxtx_buf; // SPI data buffer
  std::vector<uint8_t> cmd3;	       // SPI command buffer

  int n_slices = 12;		// number of "slices" to read
  int n_rows = HEIGHT/n_slices;	// rows per slice
  int n_cols = WIDTH;		// columns per slice
  int n_bytes_per_row = n_cols * 2; // number of bytes to read per row (16 bits/pixel for RAW10)
  char *output_file = NULL;	// output file name if any

public:
  SpiDevice spi;

  MiraImage();
  ~MiraImage();

  bool initialize();
  void close();
  bool read_ver_depth( int *version, int *depth);
  std::vector<uint8_t> read_frame( int n_img_sum = 1);

};

#endif

