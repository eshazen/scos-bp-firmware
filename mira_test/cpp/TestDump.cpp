//
// put the board in BFI mode
// dump everything which comes in
//

#include "MiraImage.h"

int main( int argc, char *argv[]) {

  int ver, depth;
  int n_img_sum = 1;
  MiraImage mira;

  char *output_file = NULL;

  int N_FRAMES_TO_DISP = 1200;
  int FRAME_RATE = 240;
  int N_FRAMES_PER_XFER = 24;
  int TILE_SIZE[] = {64, 60};
  int FRAME_SIZE[] = {1600, 480};

  int N_PIX = TILE_SIZE[0] * TILE_SIZE[1];
  int N_TILES = (FRAME_SIZE[0] * FRAME_SIZE[1] / N_PIX);
  int N_BYTES_PER_XFER = (4*N_FRAMES_PER_XFER*(2*N_TILES+2));

  double VAR_DIGI = 1./12;
  double GAIN = 0.0956 / 10; // need to re-measure this
  double VAR_READ = 1.;

  printf("bytes/xfer = %d\n", N_BYTES_PER_XFER);


  // process any command-line arguments
  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {	// options start with '-'
	switch( toupper( argv[i][1])) {
	case 'S':
	  if( i > argc-1) {
	    printf("Need frame count after -S\n");
	    exit(1);
	  }
	  n_img_sum = atoi( argv[i+1]);
	  printf("Summing %d frames\n", n_img_sum);
	  if( n_img_sum > 63)
	    printf("WARNING:  sum may overflow for >63 frames\n");
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
    

  mira.initialize();		// initialize SPI bus etc
  mira.read_ver_depth( &ver, &depth); // get FW version and bit depth
  printf("Version = %d  bit depth = %d\n", ver, depth);
  if( depth != 10) {
    printf("This code only works for bit depth 10 (got %d)\n", depth);
    exit(1);
  }

//    # configure for real-time bfi
  mira.spi.writebytes2(0xfe, (1<<7)+1, 1); // select bfi pre-processing as datasource
  mira.spi.writebytes2(0xfe, (1<<7)+2, 0); // dark level subtraction = 0
//    # reset tx buffer in fpga
  mira.spi.writebytes2(0xfe, (1<<7)+0, (1<<7));
  mira.spi.writebytes2(0xfe, (1<<7)+0, 0);
//    # run img processing
  mira.spi.writebytes2(0xfe, (1<<7)+0, 1) ;

  for( int i=0; i<24; i++) {
    std::vector<uint8_t> raw = mira.spi.spi_read( N_BYTES_PER_XFER);
    int rsiz = raw.size();
    printf("Read %d bytes\n", rsiz);
  }

//  for( int i=0; i<rsiz; i++) {
//    if( i % 32 == 0)
//      printf("\n%04x: ", i);
//    printf("%02x ", raw[i]);
//  }

  printf("\n");

  mira.spi.writebytes2(0xfe, (1<<7)+0, 0); // stop img processing
  mira.spi.close_spi();
}
