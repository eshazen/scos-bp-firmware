//
// put the board in BFI mode
// dump everything which comes in
//

#include "MiraImage.h"

#include <cstring>
#include <cstdio>

void dump( uint8_t* raw, int rsiz);

int main( int argc, char *argv[]) {

  int ver, depth;
  int n_img_sum = 1;
  MiraImage mira;

  char *output_file = NULL;
  FILE *fp = nullptr;

  static uint8_t header[] = {0xfe, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00};

  int N_FRAMES_TO_DISP = 10;
  int FRAME_RATE = 240;
  //  int N_FRAMES_PER_XFER = 24;
    int N_FRAMES_PER_XFER = 1;
  int TILE_SIZE[] = {64, 60};
  int FRAME_SIZE[] = {1600, 480};

  int N_PIX = TILE_SIZE[0] * TILE_SIZE[1];
  int N_TILES = (FRAME_SIZE[0] * FRAME_SIZE[1] / N_PIX);
  int N_BYTES_PER_XFER = (4*N_FRAMES_PER_XFER*(2*N_TILES+2));

  double VAR_DIGI = 1./12;
  double GAIN = 0.0956 / 10; // need to re-measure this
  double VAR_READ = 1.;

  printf("bytes/xfer = %d\n", N_BYTES_PER_XFER);

  uint8_t big_buf[N_BYTES_PER_XFER+10];
  uint8_t* pbig;

  // process any command-line arguments
  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {	// options start with '-'
	switch( toupper( argv[i][1])) {
	case 'N':
	  if( i > argc-1) {
	    printf("Need frame count after -N\n");
	    exit(1);
	  }
	  N_FRAMES_TO_DISP = atoi( argv[i+1]);
	  printf("Running %d frames\n", n_img_sum);
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
    
  if( output_file)
    fp = fopen( output_file, "wb");

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

  uint8_t* raw;
  int nloop = 0;
  int n_avail;

  long start, end;

  while( ++nloop < N_FRAMES_TO_DISP) {

    pbig = big_buf;

    // wait for data
    do {
      usleep(1000);
      raw = mira.spi.read_bytes(2);
      n_avail = raw[0] + 256*raw[1];
      if( n_avail == 2)
	printf("%02x %02x\n", raw[0], raw[1]);
    } while(n_avail == 2 || n_avail == 0);

    // read 8 bytes at a time, wait for header
    do {
      raw = mira.spi.read_bytes( 10);
    } while( memcmp( raw+2, header, sizeof(header)));

    // write header
    if( fp)
      fwrite( raw+2, 1, 8, fp);

    if( output_file) start = ftell(fp);		// get start posn

    printf("HEADER:\n");

    // now read N_BYTES_PER_XFER
    int to_read = N_BYTES_PER_XFER;

    while( to_read > MAX_SPI_XFER) {
      raw = mira.spi.read_bytes( MAX_SPI_XFER+2);
      memmove( pbig, raw+2, MAX_SPI_XFER);
      if( fp)
	fwrite( raw+2, 1, MAX_SPI_XFER, fp);
      pbig += MAX_SPI_XFER;
      to_read -= MAX_SPI_XFER;
    }

    if( to_read) {
      raw = mira.spi.read_bytes( to_read+2);
      memmove( pbig, raw+2, to_read);
      if( fp)
	fwrite( raw+2, 1, to_read, fp);
      pbig += to_read;
    }

    if( output_file) end = ftell(fp);

    printf("Bytes this block: %ld (%lx to %lx)\n", end-start, start, end);
      
    dump( big_buf, N_BYTES_PER_XFER);
  }

  mira.spi.writebytes2(0xfe, (1<<7)+0, 0); // stop img processing
  mira.spi.close_spi();

  if( fp)
    fclose(fp);
}

void dump( uint8_t* raw, int rsiz) {
  for( int i=0; i<rsiz; i++) {
    if( i % 32 == 0)
      printf("\n%04x: ", i);
    printf("%02x ", raw[i]);
  }

  printf("\n");
}

  
