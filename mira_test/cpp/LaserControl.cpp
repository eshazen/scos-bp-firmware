//
// stand-alone program to control laser and RGB LED
//

#include "DAC_control_AI.cpp"

int main( int argc, char *argv[]) {

  LaserDac hw;

  int dac;
  int r, g, b;

  bool set_laser = false;
  bool set_led = false;

  // process any command-line arguments
  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {	// options start with '-'
	switch( toupper( argv[i][1])) {
	case 'D':
	  if( i > argc-1) {
	    printf("Need laser setting after -D\n");
	    exit(1);
	  }
	  dac = atoi( argv[i+1]);
	  set_laser = true;
	  ++i;
	  break;
	case 'L':
	  if( i+3 > argc-1) {
	    printf("Need R G B after -L\n");
	    exit(1);
	  }
	  r = atoi( argv[i+1]);
	  g = atoi( argv[i+2]);
	  b = atoi( argv[i+3]);
	  i += 3;
	  set_led = true;
	  break;
	}
      }
    }
  } else {
    printf("LaserControl [-d DAC] [-l r g b]\n");
    printf("  DAC = 0 to shut off laser\n");
  }

  if( set_laser) {
    printf("Set laser to %d\n", dac);
    hw.setDacCode( dac);
//    if( dac == 0)
//      hw.setShutdown( true);
//    else
      hw.setShutdown( false);
  }

  if( set_led) {
    hw.setRgb( r, g, b);
  }

}
