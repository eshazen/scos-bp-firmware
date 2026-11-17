//
// Bernhard's cfg_mira.py converted to C++ by E. Hazen
//

#include "MiraDevice.h"

int main( int argc, char *argv[]) {

  MiraDevice mira;
  bool power_down = false;
  char *cfg_file = NULL;

  if( argc < 2) {
    printf("usage:  cfg_mira [-c <config_file>] [s]\n");
    printf("                 -c to power-up and configure\n");
    printf("                 -s to shut down\n");
    exit(1);
  }

  // process any command-line arguments
  if( argc > 1) {
    for( int i=1; i<argc; i++) {
      if( *argv[i] == '-') {	// options start with '-'
	switch( toupper( argv[i][1])) {
	case 'S':
	  power_down = true;
	  break;
	case 'C':
	  if( i > argc-1) {
	    printf("Need config file name after -C\n");
	    exit(1);
	  }
	  cfg_file = argv[i+1];
	  ++i;
	  break;
	default:
	  printf("usage:  cfg_mira [-c <config_file>] [s]\n");
	  break;
	}
      }
    }
  } else
    exit(0);

  mira.initialize();

  if( power_down) {
    printf("Powering down MIRA\n");
    mira.mira_power_down();
    exit(0);
  }

  if( cfg_file) {
    mira.turn_on( cfg_file);
  }

  mira.close();
}
