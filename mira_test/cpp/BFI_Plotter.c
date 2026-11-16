#include <stdio.h>
#include <string.h>
#include <float.h>
#include <math.h>

#define TEST_MAIN

#define PLOT_WIDTH  100
#define PLOT_HEIGHT 50
#define RESCALE_INTERVAL 50

static float history[PLOT_HEIGHT];
static int count = 0;
static int head = 0;
static int samples_since_scale = 0;

static float plot_min = FLT_MAX;
static float plot_max = -FLT_MAX;

void plot(float x)
{
    char line[PLOT_WIDTH + 1];

    // Insert new sample into circular buffer
    history[head] = x;
    head = (head + 1) % PLOT_HEIGHT;

    if (count < PLOT_HEIGHT)
        count++;

    // Update current min/max
    if (x < plot_min) plot_min = x;
    if (x > plot_max) plot_max = x;

    samples_since_scale++;

    // Recalculate min/max every 50 samples
    if (samples_since_scale >= RESCALE_INTERVAL)
    {
        plot_min = FLT_MAX;
        plot_max = -FLT_MAX;

        for (int i = 0; i < count; i++)
        {
            int idx = (head - count + i + PLOT_HEIGHT)
                      % PLOT_HEIGHT;

            if (history[idx] < plot_min)
                plot_min = history[idx];

            if (history[idx] > plot_max)
                plot_max = history[idx];
        }

        samples_since_scale = 0;
    }

    // Initialize plot line
    memset(line, ' ', PLOT_WIDTH);
    line[PLOT_WIDTH] = '\0';

    float range = plot_max - plot_min;

    if (range > 0.0f)
    {
        for (int i = 0; i < count; i++)
        {
            int idx = (head - count + i + PLOT_HEIGHT)
                      % PLOT_HEIGHT;

            int pos = (int)((history[idx] - plot_min)
                            / range * (PLOT_WIDTH - 1));

            if (pos < 0) pos = 0;
            if (pos >= PLOT_WIDTH) pos = PLOT_WIDTH - 1;

            line[pos] = '*';
        }
    }
    else
    {
        line[PLOT_WIDTH / 2] = '*';
    }

    // Print one line; let terminal scroll
    printf("%s\n", line);
    fflush(stdout);
}

#ifdef TEST_MAIN

int main( int argc, char *argv[]) {
  
}

#endif
