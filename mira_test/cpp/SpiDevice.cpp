
#include "SpiDevice.hh"

SpiDevice::SpiDevice() {
  memset( static_rx_buf, 0, sizeof(static_rx_buf));
  memset( static_tx_buf, 0, sizeof(static_tx_buf));
}
    
SpiDevice::~SpiDevice() {
    close_spi();
}

void SpiDevice::verbose( int v) {
  debug = v;
}

bool SpiDevice::open_spi(const std::string& device, uint8_t spi_mode, uint32_t max_speed) {
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

uint8_t* SpiDevice::read_bytes(size_t length) {
  if( !transfer(static_tx_buf, static_rx_buf, length)) {
    printf("read_bytes( %d failed)\n", length);
    exit(1);
  }
  return static_rx_buf;
}

//
// from BZ plot_bfi_rt_spi.p... read frame mean data
// for BFI plotting.  Similar to spi_read() below but
// for unknown reasons not interchangeable
//
//std::vector<uint8_t> SpiDevice::spi_read_frames( int n_bytes_rqd) {
uint8_t* SpiDevice::spi_read_frames( int n_bytes_rqd) {
  //  std::vector<uint8_t> out_buf;

  uint8_t* big_buf = (uint8_t *)calloc( n_bytes_rqd+128, 1);
  if( !big_buf) {
    printf("buffer alloc failed in spi_read_frames()\n");
    exit(1);
  }

  uint8_t* ptmp;
  int n_bytes_read = 0;
  int bytes_available = 0;
  while( n_bytes_read < n_bytes_rqd) {
    ptmp = read_bytes(2);
    bytes_available = ptmp[0] + ptmp[1]*256;
    // FIXME: check for overflow here
    if( bytes_available > 0) {
      // limit reads/writes to chunks of less than SPI bufsiz
      // (/sys/module/spidev/parameters/bufsiz ~= 4096 on this machine)
      int n_rdnow = std::min( std::min( bytes_available, n_bytes_rqd-n_bytes_read), 4096-2);
      ptmp = read_bytes( 2+n_rdnow);
      memmove( big_buf+n_bytes_read, ptmp+2, n_rdnow);
      n_bytes_read += n_rdnow;
    } else {
      usleep( 1000);
    }
  }

  return big_buf;
}


// spi_read( nbytes) equivalent to Bernard's version from
// get_frame_spi.py
// Expects the board to send back the byte count first
// NOTE:  this only works for reading "slices" of an image in the
//   raw frame mode.
std::vector<uint8_t> SpiDevice::spi_read( int n_bytes_rqd) {
  std::vector<uint8_t> out_buf( n_bytes_rqd+128);

  if( debug) printf("spi_read( %d)\n", n_bytes_rqd);

  int n_bytes_read = 0;
  int bytes_available = 0;
  int n_rdnow;
  while( n_bytes_read < n_bytes_rqd) {
    n_rdnow = std::min(bytes_available+2, 4096);
    uint8_t* buf = read_bytes( n_rdnow);
    if( debug) 
      for( int i=0; i<std::min(n_rdnow,10) ; i++)
	printf("buf[%d] = 0x%x\n", i, buf[i]);
    bytes_available = buf[0] + buf[1]*256 - (n_rdnow-2);
    if( debug)
      printf("bytes_available = %d (from buf(%d, %d), n_rdnow-2=%d)\n", bytes_available, buf[0], buf[1], n_rdnow-2);
    if( bytes_available < 0) {
      printf("Error!  bytes_available = %d\n", bytes_available);
      exit(1);
    }
    if( n_rdnow > 2) {
      if( debug) {
	printf("add to out_buf n_rdnow=%d bytes at %d\n", n_rdnow, n_bytes_read);
      // out_buf[n_bytes_read:(n_bytes_read+n_rdnow)] = buf[2:]
	printf("memmove( %x %x %d)\n", &out_buf[n_bytes_read], &buf[2], n_rdnow);
	printf("out_buf = %x  n_bytes_read = %d\n", &out_buf[0], n_bytes_read);
      }
      memmove( &out_buf[n_bytes_read], &buf[2], n_rdnow);
      n_bytes_read += (n_rdnow-2);
      if( debug)
	printf("n_bytes_read = %d\n", n_bytes_read);
    } else {
      usleep( usleep_delay);
    }

  }
  return out_buf;
}

  // spi.writebytes2() for 3-byte command only
bool SpiDevice::writebytes2( uint8_t cmd1, uint8_t cmd2, uint8_t cmd3) {
  uint8_t temp[3];
  temp[0] = cmd1;
  temp[1] = cmd2;
  temp[2] = cmd3;
  return transfer( temp, nullptr, 3);
}    

void SpiDevice::close_spi() {
  if (fd >= 0) {
    close(fd);
    fd = -1;
  }
}

  // Core ioctl messaging wrapper
bool SpiDevice::transfer(const uint8_t* tx, uint8_t* rx, size_t length) {
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

