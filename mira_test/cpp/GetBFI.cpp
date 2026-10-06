//
// put the board in BFI mode
// get sums etc and calculate BFI
//

#include "MiraImage.h"

#include <cstring>
#include <cstdio>

uint8_t* spi_read( MiraImage* mira, int rsiz);
void dump( uint8_t* raw, int rsiz, const char *s);

int main( int argc, char *argv[]) {

  int ver, depth;

  MiraImage mira;

  char *output_file = NULL;
  FILE *fp = nullptr;
  int num_loops = 10;
  int num_frames = 24;

  static uint8_t header[] = {0xfe, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00};

  int debug;
  bool dump_data = false;
  bool print_sums = false;
  bool calc_avgs = false;
  bool calc_bfi = false;

  char help[] = "usage: GetBFI [-n loops] [-f frames] [-v] [-d] [-s] [-a]";

  // process any command-line arguments
  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {	// options start with '-'
	switch( toupper( argv[i][1])) {
	case 'H':
	  puts(help);
	  exit(1);
	  break;
	case 'B':
	  calc_bfi = true;
	  break;
	case 'V':
	  ++debug;
	  mira.spi.verbose( debug);
	  break;
	case 'S':
	  print_sums = true;
	  break;
	case 'A':
	  calc_avgs = true;
	  break;
	case 'N':
	  if( i > argc-1) {
	    printf("Need loop count after -N\n");
	    exit(1);
	  }
	  num_loops = atoi( argv[i+1]);
	  printf("Running %d loops\n", num_loops);
	  ++i;
	  break;
	case 'F':
	  if( i > argc-1) {
	    printf("Need frame count after -F\n");
	    exit(1);
	  }
	  num_frames = atoi( argv[i+1]);
	  printf("Running %d frames\n", num_frames);
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
  
  uint8_t* big_buf = (uint8_t *)calloc( mira.bytes_in_frames( num_frames), 1);
  uint32_t* sums = (uint32_t *)calloc( MiraImage::N_TILES*num_frames, sizeof(uint32_t));
  uint32_t* sum_sq = (uint32_t *)calloc( MiraImage::N_TILES*num_frames, sizeof(uint32_t));
  

  mira.read_ver_depth( &ver, &depth); // get FW version and bit depth
  printf("Version = %d  bit depth = %d\n", ver, depth);
  if( depth != 10) {
    printf("This code only works for bit depth 10 (got %d)\n", depth);
    exit(1);
  }

  printf("Running for %d loops, %d frames/loop\n", num_loops, num_frames);

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

  while( nloop++ < num_loops) {
    printf("Loop %d\n", nloop);

    mira.spi.spi_read_frames( big_buf, mira.bytes_in_frames( num_frames));
    if( !mira.extract_sums( big_buf, num_frames, sums, sum_sq)) {
      printf("error in extract_sums\n");
      exit(1);
    }
    if( print_sums) {
      uint32_t* ss = sums;
      uint32_t* sq = sum_sq;
      for( int f=0; f<num_frames; f++) {
	printf("Frame: %d\n", f);
	for( int t=0; t<MiraImage::N_TILES; t++) {
	  printf("%3d: %12d (0x%08x) %12d (0x%08x)\n", t, *ss, *ss, *sq, *sq);
	  ++ss;
	  ++sq;
	}
      }
    }

    if( calc_bfi) {
      double bfi = mira.calc_bfi( num_frames, sums, sum_sq);
      printf("BFI = %lf\n", bfi);
    }

    if( dump_data) {
      dump( big_buf, mira.bytes_in_frames( num_frames), "Big Buf");
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
