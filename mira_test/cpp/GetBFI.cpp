//
// get BFI data using MiraImage class
// converted from plot_bfi_rt_spi.py by E. Hazen
//

#include "MiraImage.h"

int main( int argc, char *argv[]) {
  MiraImage mira;
  
  mira.initialize();		// initialize SPI bus etc
  mira.read_ver_depth( &ver, &depth); // get FW version and bit depth
  printf("Version = %d  bit depth = %d\n", ver, depth);

  vector<uint8_t> rxtx_buf( 8196, 0);

  mira.spi.writebytes2(0, 0, 0); // flush cfg fsm

  int N_FRAMES_TO_DISP = 1200;
  int FRAME_RATE = 240;
  int N_FRAMES_PER_XFER = 24;
  int TILE_SIZE[] = {64, 60};
  int FRAME_SIZE[] = {1600, 480};

  int N_PIX = TILE_SIZE[0] * TILE_SIZE[1];
  int N_TILES = int(FRAME_SIZE[0] * FRAME_SIZE[1] / N_PIX);
  int N_BYTES_PER_XFER = int(4*N_FRAMES_PER_XFER*(2*N_TILES+2));

  double VAR_DIGI = 1/12;
  double GAIN = 0.0956 / 10; // need to re-measure this
  double VAR_READ = 1;

  int ptr = 0;
  int frm_cnt = 0;
    
//timer = pg.QtCore.QTimer()
//timer.timeout.connect(update)
//timer.start(40)
//
//    # configure for real-time bfi
//    #ser.write([0xfe, ireg, ival])
  mira.spi.writebytes2(0xfe, (1<<7)+1, 1); // select bfi pre-processing as datasource
  mira.spi.writebytes2(0xfe, (1<<7)+2, 0); // dark level subtraction = 0
//    # reset tx buffer in fpga
  mira.spi.writebytes2(0xfe, (1<<7)+0, (1<<7));
  mira.spi.writebytes2(0xfe, (1<<7)+0, 0);
//    # run img processing
  mira.spi.writebytes2(0xfe, (1<<7)+0, 1) ;

    // run processing
  for( int i=0; i<10; i++)
    update();

  mira.spi.writebytes2(0xfe, (1<<7)+0, 0); // stop img processing
  mira.spi.close_spi();
}

void update() {
//    global bfi, ptr, frm_cnt
//    rawdat_bytes = spi_read(N_BYTES_PER_XFER)
  vector<uint8_t> rawdat_bytes = mira.spi.spi_read( N_BYTES_PER_XFER);
//    
//    # check first header, calculate offset
  int offset = 0;
  vector<uint8_t> header;
  vector<uint8_t> header_test = { 0xfe, 0xff, 0, 0, 0xff, 0xff, 0, 0 };
  header.assign(  rawdat_bytes.begin(), rawdat_bytes.begin() + 8);  // = rawdat_bytes[0:8]
//    while not (header == b'\xfe\xff\x00\x00\xff\xff\x00\x00') and offset+10 < N_BYTES_PER_XFER:
  while( !(header == header_test) && offset+10 < N_BYTES_PER_XFER) {
    offset += 1;
//        header = rawdat_bytes[offset:offset+8]
    header.assign( rawdat_bytes.begin()+offset, rawdat_bytes.begin()+8);
    if( offset == 0) {
//        rawdat = np.frombuffer(rawdat_bytes, dtype=np.uint32)
// now we want to re-interpret the rawdat_bytes as rawdat (uint32)
      uint32_t* rawdat = (uint32_t *)rawdat_bytes.data();

//        for iframe in range(N_FRAMES_PER_XFER):
      for( int ifram=0; ifram<N_FRAME_PER_XFER; ifram++) {
//            # Check header
	// NOTE now 'header' refers to uint32
//            header_start = int(iframe * (2 * N_TILES + 2))
//            header = rawdat[header_start:header_start + 2]
	int hs = iframe * (2 * N_TILES + 2);
	
//            if not (header == [65534, 65535]).all():
//                print(f' header error 0x{header[0]:08x} 0x{header[1]:08x}')
//                result = np.nan
	} else {
//            else:
//                # Extract pixel sum and sum of squares
//                indices_sum = np.arange(0, 2 * N_TILES, 2) + 2 + iframe * (2 * N_TILES + 2)
//                indices_sq_sum = np.arange(0, 2 * N_TILES, 2) + 3 + iframe * (2 * N_TILES + 2)
//                
//                pix_sum_array = rawdat[indices_sum]
//                pix_sq_sum_array = rawdat[indices_sq_sum]
//                
//                # Calculate statistics
//                mean_I_array = pix_sum_array / N_PIX
//                var_I_array = pix_sq_sum_array / N_PIX - mean_I_array ** 2
//                var_shot_array = mean_I_array * GAIN
//                K2_f_array = (var_I_array - VAR_DIGI - var_shot_array - VAR_READ) / (mean_I_array ** 2)
//                result = 1/np.mean(K2_f_array)
//                #result = pix_sum_array[1]
	}
//            # Store result
//            K2_f_index = (ptr + iframe) % N_FRAMES_TO_DISP
//            bfi[K2_f_index] = result
      }
    } else {
        printf( "incurred offset of %d bytes\n", offset);
	//        # flush to realign
	mira.spi.spi_read( offset);
    }
  }
//
//    ptr = (ptr+N_FRAMES_PER_XFER) % N_FRAMES_TO_DISP
//    frm_cnt += N_FRAMES_PER_XFER
//    bfi[ptr:ptr+N_FRAMES_PER_XFER] = np.nan # create gap in front of newest data
//    #print(f'Result {bfi[ptr-1]}')
//    curve.setData(x=tv, y=bfi)
}
