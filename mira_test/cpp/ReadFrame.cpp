//
// read full image from Mira in slices
// usage:  ReadFrame [-s nsum] [output_file]
//
//    nsum is number of frames to average
//    output_file is a binary file to dump image to
//


#include "MiraImage.h"

int main( int argc, char *argv[]) {

  int ver, depth;
  int n_img_sum = 1;
  MiraImage mira;

  char *output_file = NULL;

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

  std::vector<uint8_t> img_raw_data = mira.read_frame( n_img_sum);

  printf("\nRead %d bytes\n", img_raw_data.size());
  if( img_raw_data.size() != WIDTH * HEIGHT * 2) {
    printf("Expected %d bytes but got %d\n", WIDTH*HEIGHT*2, img_raw_data.size());
    exit(1);
  }

  uint16_t* imageData10bit = new uint16_t[WIDTH * HEIGHT];

  // calculate average
  for( int i=0; i<WIDTH*HEIGHT; i++) {
    uint16_t pix = img_raw_data[2*i] + (img_raw_data[2*i+1]<<8);
    imageData10bit[i] = (double)pix / n_img_sum;
  }

  // print first 16 values for confidence
  for( int i=0; i<16; i++) {
    printf(" %d", imageData10bit[i]);
  }
  printf("\n");

  // write data to file if requested
  if( output_file) {
    printf("Attempting to dump raw binary data to %s\n", output_file);
    FILE *fp = fopen( output_file, "wb");
    fwrite( imageData10bit, sizeof(uint16_t), WIDTH*HEIGHT, fp);
    fclose( fp);
  }


}
