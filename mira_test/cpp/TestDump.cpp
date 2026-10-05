//
// put the board in BFI mode
// dump everything which comes in
//

#include "MiraImage.h"

#include <cstring>
#include <cstdio>

uint8_t* spi_read( MiraImage* mira, int rsiz);
void dump( uint8_t* raw, int rsiz, const char *s);

static uint8_t big_buf[MiraImage::N_BYTES_PER_XFER];

int main( int argc, char *argv[]) {

  int ver, depth;
  int n_img_sum = 1;

  MiraImage mira;

  char *output_file = NULL;
  FILE *fp = nullptr;
  int N_FRAMES_TO_DISP = 10;

  static uint8_t header[] = {0xfe, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00};

  printf("bytes/xfer = %d\n", MiraImage::N_BYTES_PER_XFER);

  int debug;
  bool dump_data = false;

  // process any command-line arguments
  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {	// options start with '-'
	switch( toupper( argv[i][1])) {
	case 'V':
	  ++debug;
	  mira.spi.verbose( debug);
	  break;
	case 'N':
	  if( i > argc-1) {
	    printf("Need frame count after -N\n");
	    exit(1);
	  }
	  N_FRAMES_TO_DISP = atoi( argv[i+1]);
	  printf("Running %d frames\n", n_img_sum);
	  ++i;
	  break;
	case 'D':
	  dump_data = true;
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

  if( !mira.initialize()) {
    printf("mira init failed\n");
    exit(1);
  }
  
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

  int nloop = 0;
  int n_avail;

  long start, end;

  while( nloop++ < N_FRAMES_TO_DISP) {
    printf("Loop %d\n", nloop);

    mira.spi.spi_read_frames( big_buf, MiraImage::N_BYTES_PER_XFER);
    if( memcmp( big_buf, header, sizeof(header))) {
      printf("Error!  Missing header\n");
      exit(1);
    }
    if( dump_data) {
      dump( big_buf, MiraImage::N_BYTES_PER_XFER, "Big Buf");
    }
  }

  mira.spi.writebytes2(0xfe, (1<<7)+0, 0); // stop img processing
  mira.spi.close_spi();

  if( fp)
    fclose(fp);
}

void dump( uint8_t* raw, int rsiz, const char *s) {
  if( s)
    printf("%s", s);
  for( int i=0; i<rsiz; i++) {
    if( i % 32 == 0)
      printf("\n%04x: ", i);
    printf("%02x ", raw[i]);
  }

  printf("\n");
}

