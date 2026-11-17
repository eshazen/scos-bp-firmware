// To ChatGPT:
//
// please write a short example program in c to initialize the serial
// port /dev/ttyS0 for 115200 baud, 8 bits, 1 stop bit no parity and
// include functions to send and receive bytes and C-strings from the
// port.  This is to run on a Pi Zero 2W running dietpi.  I already
// have the package build-essential installed.
//

// #define TEST_MAIN

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <sys/select.h>

static int serial_fd = -1;

// Initialize serial port
int serial_open(const char *device)
{
    struct termios tty;

    serial_fd = open(device, O_RDWR | O_NOCTTY | O_SYNC);
    if (serial_fd < 0) {
        perror("open serial port");
        return -1;
    }

    if (tcgetattr(serial_fd, &tty) != 0) {
        perror("tcgetattr");
        close(serial_fd);
        serial_fd = -1;
        return -1;
    }

    // Set baud rate
    cfsetospeed(&tty, B115200);
    cfsetispeed(&tty, B115200);

    // 8 data bits, no parity, 1 stop bit
    tty.c_cflag &= ~PARENB;
    tty.c_cflag &= ~CSTOPB;
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;

    // Enable receiver, ignore modem control lines
    tty.c_cflag |= (CLOCAL | CREAD);

    // Disable hardware flow control
    tty.c_cflag &= ~CRTSCTS;

    // Raw input/output
    tty.c_iflag &= ~(IXON | IXOFF | IXANY);
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK |
                     ISTRIP | INLCR | IGNCR | ICRNL);

    tty.c_oflag &= ~OPOST;

    tty.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);

    // Read timeout settings:
    // VMIN=0, VTIME=10 means 1 second timeout
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(serial_fd, TCSANOW, &tty) != 0) {
        perror("tcsetattr");
        close(serial_fd);
        serial_fd = -1;
        return -1;
    }

    return 0;
}

// Close serial port
void serial_close(void)
{
    if (serial_fd >= 0) {
        close(serial_fd);
        serial_fd = -1;
    }
}

// Send a single byte
int serial_send_byte(uint8_t data)
{
    return write(serial_fd, &data, 1) == 1 ? 0 : -1;
}

// Receive a single byte
// Returns: 0 = success, -1 = error, 1 = timeout
int serial_receive_byte(uint8_t *data)
{
    int n = read(serial_fd, data, 1);

    if (n == 1)
        return 0;

    if (n == 0)
        return 1;  // Timeout

    return -1;
}

// Send a null-terminated string
int serial_send_string(const char *str)
{
    size_t len = strlen(str);
    size_t sent = 0;

    while (sent < len) {
        ssize_t n = write(serial_fd, str + sent, len - sent);

        if (n < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }

        sent += n;
    }

    return 0;
}

// Receive a string until newline or buffer limit
// Returns number of characters received, or -1 on error
int serial_receive_string(char *buffer, size_t maxlen)
{
    size_t count = 0;
    uint8_t c;

    if (maxlen < 2)
        return -1;

    while (count < maxlen - 1) {
        int result = serial_receive_byte(&c);

        if (result == 1)
            break;              // Timeout

        if (result < 0)
            return -1;

        if (c == '\r' || c == '\n')
            break;

        buffer[count++] = (char)c;
    }

    buffer[count] = '\0';
    return (int)count;
}

#ifdef TEST_MAIN

// Example application
int main(void)
{
    char buffer[128];

    if (serial_open("/dev/ttyS0") != 0)
        return 1;

    printf("Serial port opened at 115200 baud.\n");

    // blink the LED
    for( int i=0; i<25; i++) {

      serial_send_string("$P@|");	/* turn on LED */
      usleep( 100000L);
      serial_send_string("$P@@");	/* all off */
      usleep( 100000L);
    }

    serial_close();
    return 0;
}

#endif
