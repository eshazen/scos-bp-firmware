//
// header for SpiDevice.cpp
//

#ifndef SPI_DEVICE_H
#define SPI_DEVICE_H

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

const int MAX_SPI_XFER = 4096-2;

class SpiDevice {
private:
  int fd = -1;
  uint32_t usleep_delay = 1000;
  uint32_t speed_hz = 10000000; // Default 10 MHz
  uint8_t bits_per_word = 8;
  uint8_t mode = SPI_MODE_0;
  uint8_t static_tx_buf[MAX_SPI_XFER];
  uint8_t static_rx_buf[MAX_SPI_XFER];
  int debug = 0;

public:
  SpiDevice();
  ~SpiDevice();

  // Opens the device (e.g., "/dev/spidev0.0") and configures defaults
  bool open_spi(const std::string& device, uint8_t spi_mode = SPI_MODE_0, uint32_t max_speed = 10000000);
  uint8_t* read_bytes(size_t length);
  // std::vector<uint8_t> spi_read( int n_bytes_rqd = 2);
  uint8_t* spi_read( uint8_t* out_buf, int n_bytes_rqd);
  // std::vector<uint8_t> spi_read_frames( int n_bytes_rqd);
  uint8_t* spi_read_frames( uint8_t* big_buf, int n_bytes_rqd);
  bool writebytes2( uint8_t cmd1, uint8_t cmd2, uint8_t cmd3);
  void close_spi();
  void verbose( int v);

private:
  bool transfer(const uint8_t* tx, uint8_t* rx, size_t length);
  
};

#endif
