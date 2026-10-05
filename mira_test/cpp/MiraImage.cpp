
#include "MiraImage.h"

// Constructor
MiraImage::MiraImage() :   rxtx_buf(8196), cmd3(3) {
}

// Destructor
MiraImage::~MiraImage() {
  spi.close_spi();
}

bool MiraImage::initialize() {
  // Open SPI bus 0, Chip Select 0, Mode 0 at specified speed
  if (!spi.open_spi("/dev/spidev0.0", SPI_MODE_0, SPI_SPEED_HZ)) {
    printf("Error opening SPI\n");
    return false;
  }

  spi.writebytes2( 0, 0, 0); // flush cfg fsm
  spi.writebytes2( 0xfe, (1<<7)+1, 0); // select cfg reg as data source
  // reset tx buffer in fpga
  spi.writebytes2(0xfe, (1<<7)+0, (1<<7));
  spi.writebytes2(0xfe, (1<<7)+0, 0);
  usleep( USLEEP_DELAY);
  return true;
}


bool MiraImage::read_ver_depth( int *version, int *depth) {
  // get firmware version and bit depth
  spi.writebytes2(0xfe, (1<<7)+1, 0); // select cfg reg as data source
  spi.writebytes2(0xfe, 14, 0); // read cmd for bit depth
  spi.writebytes2(0xfe, 15, 0); // read cmd for fw version
  uint8_t* buf = spi.spi_read( buff_ver_depth, 4);
  if( buf[0] == 0xfd && buf[2] == 0xfd) {
    *depth = buf[1];
    *version = buf[3];
    return true;
  } else {
    fprintf( stderr, "read error\n");
    for( int i=0; i<6; i++)
      fprintf( stderr, "buf[%d] = 0x%x\n", i, buf[i]);
    return false;
  }
}

uint8_t* MiraImage::read_frame( int n_img_sum) {

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

  int total_read = 0;		// counter for bytes read

  // img_raw_data = bytearray()
  uint8_t* img_raw_data = buff_image;
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
    uint8_t* raw = spi.spi_read( buff_slice, slice_bytes); // read the data
#ifdef DEBUG
    printf("Read %d bytes\n", slice_bytes);
#endif
    total_read += slice_bytes;
    memmove( img_raw_data, raw, slice_bytes);
    img_raw_data += slice_bytes;
  }

  // FIXME:  implement averaging

  return buff_image;
}


