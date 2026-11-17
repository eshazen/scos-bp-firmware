#include <stdio.h>
#include <float.h>

#define PLOT_WIDTH 100
#define PLOT_HEIGHT 100
#define RESCALE_INTERVAL 50

static float history[PLOT_HEIGHT];
static int head = 0;
static int count = 0;
static int samples_since_scale = 0;

static float plot_min = FLT_MAX;
static float plot_max = -FLT_MAX;

void plot(float x)
{
    // Store the new sample
    history[head] = x;
    head = (head + 1) % PLOT_HEIGHT;

    if (count < PLOT_HEIGHT)
        count++;

    // Update running minimum and maximum
    if (x < plot_min) plot_min = x;
    if (x > plot_max) plot_max = x;

    // Recalculate scale every 50 samples
    if (++samples_since_scale >= RESCALE_INTERVAL)
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

    // Determine horizontal position
    int pos = PLOT_WIDTH / 2;

    if (plot_max > plot_min)
    {
        pos = (int)((x - plot_min) /
                    (plot_max - plot_min) * (PLOT_WIDTH - 1));
    }

    if (pos < 0) pos = 0;
    if (pos >= PLOT_WIDTH) pos = PLOT_WIDTH - 1;

    // Print one line with a single asterisk
    for (int i = 0; i < PLOT_WIDTH; i++)
        putchar(i == pos ? '*' : ' ');

    putchar('\n');
    fflush(stdout);
}
