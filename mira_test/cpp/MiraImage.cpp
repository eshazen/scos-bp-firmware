
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

  return buff_image;
}


// calculate bytes in n frames
// N.B. there is a 2 x int32 header on each frame
//
int MiraImage::bytes_in_frames( int n_frames) {
  return (sizeof(int32_t)*n_frames*(2*N_TILES+2));
}



//
// process raw data, extract sums into two arrays
// return true if OK, false if error (usually missing header)
//
bool MiraImage::extract_sums( uint8_t* raw, int n_frames, uint32_t* sums, uint32_t* sum_sq) {
  uint32_t* raw32 = (uint32_t *)raw;
  for( int i=0; i<n_frames; i++) {
    if( raw32[0] != 0xfffeL || raw32[1] != 0xffffL) {
      printf("MiraImage::extract_sums error.  Expected header, saw %x, %x\n", raw32[0], raw32[1]);
      printf("At int32 offset %d\n", raw32 - (uint32_t *)raw);
      return false;
    }
    raw32 += 2;
    for( int k=0; k<MiraImage::N_TILES; k++) {
      sums[k] = raw32[0];
      sum_sq[k] = raw32[1];
      raw32 += 2;
    }
  }
  return true;
}


//
// calculate BFI from a set of sums
//
double MiraImage::calc_bfi( int n_frames, uint32_t* sums, uint32_t* sum_sq) {

  //  calloc( MiraImage::N_TILES*num_frames, sizeof(uint32_t));

//  # Calculate statistics
//  mean_I_array = pix_sum_array / N_PIX
  double mean_I_array[N_TILES];
  for( int i=0; i<N_TILES; i++) sums[i] / N_PIX;
//  var_I_array = pix_sq_sum_array / N_PIX - mean_I_array ** 2
  double var_I_array[N_TILES];
  for( int i=0; i<N_TILES; i++) var_I_array[i] = sum_sq[i] / N_PIX - mean_I_array[i]*mean_I_array[i];
//  var_shot_array = mean_I_array * GAIN
  double var_shot_array[N_TILES];
  for( int i=0; i<N_TILES; i++) var_shot_array[i] = mean_I_array[i] * GAIN;
//  K2_f_array = (var_I_array - VAR_DIGI - var_shot_array - VAR_READ) / (mean_I_array ** 2)
  double K2_f_array[N_TILES];
  for( int i=0; i<N_TILES; i++) 
    K2_f_array[i] = (var_I_array[i] - VAR_DIGI - var_shot_array[i] - VAR_READ) / (mean_I_array[i]*mean_I_array[i]);
//  result = 1/np.mean(K2_f_array)
  double sum = 0.;
  for( int i=0; i<N_TILES; i++)
    sum += K2_f_array[i];
  return 1.0 / (sum / N_TILES);
}
