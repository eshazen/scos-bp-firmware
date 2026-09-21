#include <iostream>
#include <vector>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include <unistd.h>
#include <cstdint>

class SpiDevice {
private:
  int fd = -1;
  uint32_t speed_hz = 12000000; // Default 12 MHz
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

    transfer(tx_buf.data(), rx_buf.data(), length);
    return rx_buf;
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

int main() {
  SpiDevice spi;
  // rxtx_buf = np.zeros(8196, dtype=np.uint8)
  std::vector<uint8_t> rxtx_buf(8196);
  std::vector<uint8_t> cmd3(3);

    // n_rows = 40
    // n_cols = 1600
    // n_slices = 12
    // n_img_sum = 1 # number of images to sum in fpga
    // 
    // n_bytes_per_row = int(n_cols * 2)

  int n_rows = 40;
  int n_cols = 1600;
  int n_slices = 12;
  int n_img_sum = 1;
  int n_bytes_per_row = n_cols * 2;

  // Open SPI bus 0, Chip Select 0, Mode 0 at 12 MHz
  if (!spi.open_spi("/dev/spidev0.0", SPI_MODE_0, 12000000)) {
    return 1;
  }

  // spi.writebytes2([0, 0, 0]) # flush cfg fsm
  spi.writebytes2( 0, 0, 0);

  // spi.writebytes2([0xfe, (1<<7)+1, 0]) # select cfg reg as data source
  spi.writebytes2( 0xfe, (1<<7)+1, 0); // select cfg reg as data source
  // # reset tx buffer in fpga
  // spi.writebytes2([0xfe, (1<<7)+0, (1<<7)])
  spi.writebytes2(0xfe, (1<<7)+0, (1<<7));
  spi.writebytes2(0xfe, (1<<7)+0, 0);
  // sleep(0.001)
  usleep( 1000);
  // # get firmware version and bit depth
  // spi.writebytes2([0xfe, (1<<7)+1, 0]) # select cfg reg as data source
  spi.writebytes2(0xfe, (1<<7)+1, 0); // select cfg reg as data source
  // spi.writebytes2([0xfe, 14, 0]) # read cmd for bit depth
  spi.writebytes2(0xfe, 14, 0); // read cmd for bit depth
  // spi.writebytes2([0xfe, 15, 0]) # read cmd for fw version
  spi.writebytes2(0xfe, 15, 0); // read cmd for fw version
  // buf = spi_read(4)
  std::vector<uint8_t> buf = spi.read_bytes(4);
  // if buf[0] == 0xfd and buf[2] == 0xfd:
  //     bit_depth = buf[1]
  //     fw_ver = buf[3]
  //     print(f"FPGA fw ver: {fw_ver}, bit depth: {bit_depth}")
  // else:
  //     print(f"read error, buf = {buf}")
  if( buf[0] == 0xfd && buf[2] == 0xfd) {
    int bit_depth = buf[1];
    int fw_ver = buf[3];
    printf("FPGA fw ver: %d, bit depth: %d\n", fw_ver, bit_depth);
  } else {
    printf("read error\n");
  }
	
//
//
//
//
//  // Example 1: Read 5 bytes
//  std::vector<uint8_t> incoming = spi.read_bytes(5);
//  std::cout << "Read bytes: ";
//  for (auto byte : incoming) std::printf("0x%02X ", byte);
//  std::cout << "\n";
//
//  // Example 2: Write command bytes
//  spi.write_bytes({0x41, 0x42, 0x43});
//
//  // Example 3: Transfer (Simultaneous Read/Write)
//  std::vector<uint8_t> response = spi.xfer({0x9F, 0x00, 0x00}); // e.g., Read Jedec ID command

  return 0;
}
