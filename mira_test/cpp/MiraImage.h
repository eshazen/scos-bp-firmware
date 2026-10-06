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

// #define SPI_SPEED_HZ 10000000
#define SPI_SPEED_HZ 8000000
#define USLEEP_DELAY 1000


class MiraImage {
private:
  std::vector<uint8_t> rxtx_buf;		// SPI data buffer
  std::vector<uint8_t> cmd3;			// SPI command buffer

  static constexpr int n_slices = 12;		// number of "slices" to read
  static constexpr int n_rows = HEIGHT/n_slices; // rows per slice
  static constexpr int n_cols = WIDTH;		// columns per slice
  static constexpr int n_bytes_per_row = n_cols * 2; // number of bytes to read per row (16 bits/pixel for RAW10)
  char *output_file = NULL;	                // output file name if any
  static constexpr  int slice_bytes = n_rows * n_bytes_per_row;

  static  constexpr int FRAME_RATE = 240;

  static  constexpr int N_FRAMES_PER_XFER = 24;
  static  constexpr int TILE_SIZE[] = {64, 60};
  static  constexpr int FRAME_SIZE[] = {1600, 480};

  
  static  constexpr double VAR_DIGI = 1./12;
  static  constexpr double GAIN = 0.0956 / 10; // need to re-measure this
  static  constexpr double VAR_READ = 1.;
  static  constexpr int N_PIX = TILE_SIZE[0] * TILE_SIZE[1];

  // fixed buffers to save complexity
  uint8_t buff_ver_depth[4];		  // buffer for version, depth
  uint8_t buff_slice[slice_bytes];
  uint8_t buff_image[slice_bytes * n_slices];

public:
  SpiDevice spi;
  static constexpr int image_bytes = slice_bytes * n_slices;
  static constexpr int N_TILES = (FRAME_SIZE[0] * FRAME_SIZE[1] / N_PIX);

  MiraImage();
  ~MiraImage();

  bool initialize();
  void close();
  bool read_ver_depth( int *version, int *depth);
  uint8_t* read_frame( int n_img_sum = 1);
  int bytes_in_frames( int n_frames); 
  bool extract_sums( uint8_t* raw, int n_frames, uint32_t* sums, uint32_t* sum_sq);
  double calc_bfi( int n_frames, uint32_t* sums, uint32_t* sum_sq);
};

#endif

