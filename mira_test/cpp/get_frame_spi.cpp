//
// C++ version of get_frame_spi
// Basic SpiDevice class written by Gemini AI
//

// usage:
// get_frame_spi [-s <frames_to_sum>] [output_file]

// #define DEBUG

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

#define USLEEP_DELAY 1000
#define SPI_SPEED_HZ 10000000

#include "SpiDevice.hh"

int main( int argc, char *argv[]) {
  SpiDevice spi;
  std::vector<uint8_t> rxtx_buf(8196);
  std::vector<uint8_t> cmd3(3);

  int n_rows = 40;
  int n_cols = 1600;
  int n_slices = 12;
  int n_img_sum = 1;
  int n_bytes_per_row = n_cols * 2;

  char *output_file = NULL;

  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {
	switch( toupper( argv[i][1])) {
	case 'S':
	  if( i > argc-1) {
	    printf("Need frame count after -S\n");
	    exit(1);
	  }
	  n_img_sum = atoi( argv[i+1]);
	  printf("Summing %d frames\n", n_img_sum);
	  ++i;
	  break;
	default:
	  printf("unknown option '%c'\n", argv[i][1]);
	}
      } else {
	output_file = argv[i];
      }
    }
  }

  // Open SPI bus 0, Chip Select 0, Mode 0 at 12 MHz
  if (!spi.open_spi("/dev/spidev0.0", SPI_MODE_0, SPI_SPEED_HZ)) {
    printf("Error opening SPI\n");
    return 1;
  }

  spi.writebytes2( 0, 0, 0); // flush cfg fsm
  spi.writebytes2( 0xfe, (1<<7)+1, 0); // select cfg reg as data source
  // reset tx buffer in fpga
  spi.writebytes2(0xfe, (1<<7)+0, (1<<7));
  spi.writebytes2(0xfe, (1<<7)+0, 0);
  usleep( USLEEP_DELAY);
  // get firmware version and bit depth
  spi.writebytes2(0xfe, (1<<7)+1, 0); // select cfg reg as data source
  spi.writebytes2(0xfe, 14, 0); // read cmd for bit depth
  spi.writebytes2(0xfe, 15, 0); // read cmd for fw version
  std::vector<uint8_t> buf = spi.spi_read(4);
  if( buf[0] == 0xfd && buf[2] == 0xfd) {
    int bit_depth = buf[1];
    int fw_ver = buf[3];
    printf("FPGA fw ver: %d, bit depth: %d\n", fw_ver, bit_depth);
  } else {
    printf("read error\n");
    for( int i=0; i<6; i++)
      printf("buf[%d] = 0x%x\n", i, buf[i]);
    exit(1);
  }

  // # configure for frame buffer read
  // #ser.write([0xfe, ireg, ival])
  spi.writebytes2(0xfe, (1<<7)+1, 2); // select raw frame as data source
  spi.writebytes2(0xfe, (1<<7)+5, 0); // select slice 0
  spi.writebytes2(0xfe, (1<<7)+6, n_img_sum-1); // set to sum N images
  // 
  // # reset tx buffer in fpga
  spi.writebytes2(0xfe, (1<<7)+0, (1<<7));
  spi.writebytes2(0xfe, (1<<7)+0, 0);
  usleep( USLEEP_DELAY);

  int total_read = 0;

  // img_raw_data = bytearray()
  std::vector<uint8_t> img_raw_data;
  // print("Trigger slice   ", end='')
  printf("Trigger slice: ");
  // for islice in range(n_slices):
  for( int islice=0; islice<n_slices; islice++) {
    printf("%d ", islice);
    fflush(stdout);
  //     print(f"\b\b{islice:2d}", end='', flush=True)
       spi.writebytes2(0xfe, (1<<7)+5, islice); // set slice number
       spi.writebytes2(0xfe, (1<<7)+0, 1<<1); // trigger slice
       spi.writebytes2(0xfe, (1<<7)+0, 0);
       std::vector<uint8_t> raw = spi.spi_read(n_rows*n_bytes_per_row);
#ifdef DEBUG
       printf("Read %d bytes\n", raw.size());
#endif
       total_read += raw.size();
       img_raw_data.insert( img_raw_data.end(), raw.begin(), raw.end());
  //     img_raw_data.extend(spi_read(n_rows*n_bytes_per_row))
  // 
  // spi.close()
  }

  printf("\nRead %d bytes\n", total_read);

  for( int i=0; i<16; i+=2) {
    uint16_t pix = img_raw_data[i] + (img_raw_data[i+1]<<8);
    printf(" %d", pix);
  }
  printf("\n");

  if( output_file) {
    printf("Attempting to dump raw binary data to %s\n", output_file);
    FILE *fp = fopen( output_file, "wb");
    fwrite( img_raw_data.data(), 1, total_read, fp);
    fclose( fp);
  }

  return 0;
}
