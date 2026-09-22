


class SpiDevice {
private:
  int fd = -1;
  uint32_t speed_hz = 8000000; // Default 12 MHz
  uint8_t bits_per_word = 8;
  uint8_t mode = SPI_MODE_0;

public:
  SpiDevice() = default;
    
  ~SpiDevice() {
    close_spi();
  }

  // Opens the device (e.g., "/dev/spidev0.0") and configures defaults
  bool open_spi(const std::string& device, uint8_t spi_mode = SPI_MODE_0, uint32_t max_speed = 1000000) {
    fd = open(device.c_str(), O_RDWR);
    if (fd < 0) {
      std::perror("Error opening SPI device");
      return false;
    }

    mode = spi_mode;
    speed_hz = max_speed;

    // Apply settings via ioctl configuration macros
    if (ioctl(fd, SPI_IOC_WR_MODE, &mode) < 0) return false;
    if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits_per_word) < 0) return false;
    if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed_hz) < 0) return false;

    return true;
  }

  // Equivalent to spi.readbytes(n)
  // Sends dummy zeros to clock in data from the peripheral
  std::vector<uint8_t> read_bytes(size_t length) {
    std::vector<uint8_t> tx_buf(length, 0x00); 
    std::vector<uint8_t> rx_buf(length, 0x00);

    if( !transfer(tx_buf.data(), rx_buf.data(), length)) {
      printf("read_bytes( %d failed)\n", length);
    }
    return rx_buf;
  }

  // spi_read( nbytes) equivalent to Bernard's version
  // Expects the board to send back the byte count first
  std::vector<uint8_t> spi_read( int n_bytes_rqd = 2) {
    std::vector<uint8_t> out_buf( n_bytes_rqd, 0);
    int n_bytes_read = 0;
    int bytes_available = 0;
    int n_rdnow;
    while( n_bytes_read < n_bytes_rqd) {
      n_rdnow = std::min(bytes_available+2, 4096);
      std::vector<uint8_t> buf = read_bytes( n_rdnow);
#ifdef DEBUG
      printf("read_bytes(%d) returned %d\n", n_rdnow, buf.size());
      for( int i=0; i< (std::min(buf.size(),(size_t)10)) ; i++)
	printf("buf[%d] = 0x%x\n", i, buf[i]);
#endif
      if( buf.size() < n_rdnow) {
	printf("read error:  expected %d, received %d\n", n_rdnow, buf.size());
      }
      bytes_available = buf[0] + buf[1]*256 - (n_rdnow-2);
#ifdef DEBUG
      printf("bytes_available = %d (from %d, %d, %d)\n", bytes_available, buf[0], buf[1], n_rdnow-2);
#endif
      if( bytes_available < 0) {
	printf("Error!  bytes_available = %d\n", bytes_available);
	exit(1);
      }
      if( n_rdnow > 2) {
#ifdef DEBUG
	printf("add to out_buf\n");
#endif
	// out_buf[n_bytes_read:(n_bytes_read+n_rdnow)] = buf[2:]
	memcpy( &out_buf[n_bytes_read], &buf[2], n_rdnow);
	n_bytes_read += (n_rdnow-2);
#ifdef DEBUG
	printf("n_bytes_read = %d\n", n_bytes_read);
#endif
      } else {
	usleep( USLEEP_DELAY);
      }

    }
    return out_buf;
  }

  // spi.writebytes2() for 3-byte command only
  bool writebytes2( uint8_t cmd1, uint8_t cmd2, uint8_t cmd3) {
    std::vector<uint8_t> temp(3, 0);
    temp[0] = cmd1;
    temp[1] = cmd2;
    temp[2] = cmd3;
    return transfer( temp.data(), nullptr, temp.size());
  }    

  // Equivalent to spi.writebytes([...])
  bool write_bytes(const std::vector<uint8_t>& data) {
    // We pass nullptr to rx_buf if we only want to transmit
    return transfer(data.data(), nullptr, data.size());
  }

  // Equivalent to spi.xfer() / spi.xfer2()
  // Simultaneously writes and reads
  std::vector<uint8_t> xfer(const std::vector<uint8_t>& data) {
    std::vector<uint8_t> rx_buf(data.size(), 0x00);
    transfer(data.data(), rx_buf.data(), data.size());
    return rx_buf;
  }

  void close_spi() {
    if (fd >= 0) {
      close(fd);
      fd = -1;
    }
  }

private:
  // Core ioctl messaging wrapper
  bool transfer(const uint8_t* tx, uint8_t* rx, size_t length) {
    if (fd < 0) return false;

    struct spi_ioc_transfer tr;
    std::memset(&tr, 0, sizeof(tr));

    tr.tx_buf = reinterpret_cast<unsigned long>(tx);
    tr.rx_buf = reinterpret_cast<unsigned long>(rx);
    tr.len = static_cast<__u32>(length);
    tr.speed_hz = speed_hz;
    tr.bits_per_word = bits_per_word;
    tr.delay_usecs = 0;
    tr.cs_change = 0; // Keep CS asserted until transfer completes

    // SPI_IOC_MESSAGE(1) means we are passing an array containing 1 transfer struct
    int ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
    if (ret < 0) {
      std::perror("Error during SPI ioctl message transfer");
      return false;
    }
    return true;
  }
};
