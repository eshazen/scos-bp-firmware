//
// put the board in BFI mode
// dump everything which comes in
//

#include "MiraImage.h"

#include <cstring>
#include <cstdio>

uint8_t* spi_read( MiraImage* mira, int rsiz);
void dump( uint8_t* raw, int rsiz, const char *s);


static  int N_FRAMES_TO_DISP = 10;
static  const int FRAME_RATE = 240;

static  const int N_FRAMES_PER_XFER = 1;
static  const int TILE_SIZE[] = {64, 60};
static  const int FRAME_SIZE[] = {1600, 480};

static  const int N_PIX = TILE_SIZE[0] * TILE_SIZE[1];
static  const int N_TILES = (FRAME_SIZE[0] * FRAME_SIZE[1] / N_PIX);
static  const int N_BYTES_PER_XFER = (4*N_FRAMES_PER_XFER*(2*N_TILES+2));

static  double VAR_DIGI = 1./12;
static  double GAIN = 0.0956 / 10; // need to re-measure this
static  double VAR_READ = 1.;

int main( int argc, char *argv[]) {

  int ver, depth;
  int n_img_sum = 1;

  MiraImage mira;

  char *output_file = NULL;
  FILE *fp = nullptr;

  static uint8_t header[] = {0xfe, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00};


  printf("bytes/xfer = %d\n", N_BYTES_PER_XFER);

  int debug;

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

  uint8_t* raw;
  int nloop = 0;
  int n_avail;

  long start, end;

  while( nloop++ < N_FRAMES_TO_DISP) {
    printf("Loop %d\n", nloop);

    // This is the "spi_read" in 
    //    std::vector<uint8_t> raw = mira.spi.spi_read( N_BYTES_PER_XFER);
    //    dump( raw.data(), N_BYTES_PER_XFER, "Vector");

    // std::vector<uint8_t> dat = mira.spi.spi_read_frames( N_BYTES_PER_XFER);
    raw = mira.spi.spi_read_frames( N_BYTES_PER_XFER);
    dump( raw, N_BYTES_PER_XFER, "Big Buf");
    free( raw);

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


// uint8_t* spi_read( MiraImage* mira, int n_bytes_rqd) {
//   uint8_t* ptmp;
//   int n_bytes_read = 0;
//   int bytes_available = 0;
//   while( n_bytes_read < n_bytes_rqd) {
//     ptmp = mira->spi.read_bytes(2);
//     bytes_available = ptmp[0] + ptmp[1]*256;
//     // FIXME: check for overflow here
//     if( bytes_available > 0) {
//       // limit reads/writes to chunks of less than SPI bufsiz
//       // (/sys/module/spidev/parameters/bufsiz ~= 4096 on this machine)
//       int n_rdnow = std::min( std::min( bytes_available, n_bytes_rqd-n_bytes_read), 4096-2);
//       ptmp = mira->spi.read_bytes( 2+n_rdnow);
//       memmove( big_buf+n_bytes_read, ptmp+2, n_rdnow);
//       n_bytes_read += n_rdnow;
//     } else {
//       usleep( 1000);
//     }
//   }
//   return big_buf;
// }
