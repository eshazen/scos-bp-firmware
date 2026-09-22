//
// display_test_sdl2:  display a 1600x480 RAW10 image
//
// usage:  display_test_sdl2 <data_file>
//   with no file, displays a test pattern.
//
// Mostly written by ChatGPT
//

#include <SDL2/SDL.h>
#include <cstring>
#include <iostream>
#include <chrono>
#include <cstdio>

const int WIDTH = 1600;
const int HEIGHT = 480;

int main( int argc, char *argv[]) {

  char *data_file = NULL;
  FILE *fpd;
  bool use_data = false;

  uint16_t* imageData10bit = new uint16_t[WIDTH * HEIGHT];

  if( argc > 1) {
    data_file = argv[1];
    if( (fpd = fopen( data_file, "rb")) == NULL) {
      printf("Error opening %s for output\n", data_file);
      exit(1);
    }

    if( fread( imageData10bit, sizeof(imageData10bit[0]), WIDTH*HEIGHT, fpd) !=
	WIDTH*HEIGHT) {
      printf("Error reading %d pixels from %s\n", WIDTH*HEIGHT, data_file);
      exit(1);
    }
    use_data = true;

  }

  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    std::cerr << "SDL initialization failed: " << SDL_GetError() << std::endl;
    return -1;
  }
    
  SDL_Window* window = SDL_CreateWindow(
					"10-bit Monochrome Image Viewer",
					SDL_WINDOWPOS_CENTERED,
					SDL_WINDOWPOS_CENTERED,
					WIDTH, HEIGHT,
					SDL_WINDOW_SHOWN
					);
    
  if (!window) {
    std::cerr << "Window creation failed: " << SDL_GetError() << std::endl;
    SDL_Quit();
    return -1;
  }
    
  SDL_Renderer* renderer = SDL_CreateRenderer(
					      window, -1, 
					      SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
					      );
    
  if (!renderer) {
    std::cerr << "Renderer creation failed: " << SDL_GetError() << std::endl;
    SDL_DestroyWindow(window);
    SDL_Quit();
    return -1;
  }
    
  // Create texture with 32-bit format (8-bit per channel)
  // We'll map 10-bit data to 8-bit for display
  SDL_Texture* texture = SDL_CreateTexture(
					   renderer,
					   SDL_PIXELFORMAT_RGB888,
					   SDL_TEXTUREACCESS_STREAMING,
					   WIDTH, HEIGHT
					   );
    
  if (!texture) {
    std::cerr << "Texture creation failed: " << SDL_GetError() << std::endl;
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return -1;
  }
    
  // Allocate buffers
  uint32_t* displayBuffer = new uint32_t[WIDTH * HEIGHT];
    
  std::cout << "SDL2 10-bit Monochrome Viewer initialized" << std::endl;
  std::cout << "Resolution: " << WIDTH << "x" << HEIGHT << std::endl;
    
  bool quit = false;
  int frameCount = 0;
  auto lastTime = std::chrono::high_resolution_clock::now();
    
  while (!quit) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
      if (event.type == SDL_QUIT) {
	quit = true;
      } else if (event.type == SDL_KEYDOWN) {
	if (event.key.keysym.sym == SDLK_ESCAPE) {
	  quit = true;
	}
      }
    }
        
    // ===== UPDATE IMAGE DATA =====
    // Example: Generate test pattern (gradient)
    if( !use_data)
      for (int y = 0; y < HEIGHT; ++y) {
	for (int x = 0; x < WIDTH; ++x) {
	  // Generate 10-bit data (0-1023)
	  uint16_t value10bit = (uint16_t)((x * 1023) / WIDTH);
	  imageData10bit[y * WIDTH + x] = value10bit;
	}
      }
        
    // Convert 10-bit to 8-bit for display (preserves data visually)
    for (int i = 0; i < WIDTH * HEIGHT; ++i) {
      // Convert 10-bit (0-1023) to 8-bit (0-255)
      uint8_t value8bit = (uint8_t)(imageData10bit[i] >> 2);  // Divide by 4
            
      // Create RGB888 pixel (grayscale)
      displayBuffer[i] = (value8bit << 16) | (value8bit << 8) | value8bit;
    }
        
    // Update texture
    void* pixels;
    int pitch;
    SDL_LockTexture(texture, nullptr, &pixels, &pitch);
    std::memcpy(pixels, displayBuffer, WIDTH * HEIGHT * sizeof(uint32_t));
    SDL_UnlockTexture(texture);
        
    // Render
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, nullptr, nullptr);
    SDL_RenderPresent(renderer);
        
    // Print FPS every 60 frames
    frameCount++;
    if (frameCount % 60 == 0) {
      auto now = std::chrono::high_resolution_clock::now();
      auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
									   now - lastTime).count();
      double fps = 60000.0 / elapsed;
      std::cout << "FPS: " << fps << std::endl;
      lastTime = now;
    }
  }
    
  // Cleanup
  delete[] imageData10bit;
  delete[] displayBuffer;
  SDL_DestroyTexture(texture);
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
    
  std::cout << "Goodbye!" << std::endl;
    
  return 0;
}
