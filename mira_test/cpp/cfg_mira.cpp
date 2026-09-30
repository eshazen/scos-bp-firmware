//
// Bernhard's cfg_mira.py converted to C++ by E. Hazen
//

#include "MiraDevice.h"

int main( int argc, char *argv[]) {

  MiraDevice mira;

  if( argc < 2) {
    printf("usage:  cfg_mira <config_file>\n");
    exit(1);
  }

  mira.initialize();
  mira.turn_on( argv[1]);
  mira.close();

}
