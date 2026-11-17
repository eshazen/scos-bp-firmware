#ifndef SERIAL_AH_H_INCLUDED
#define SERIAL_AH_H_INCLUDED

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <sys/select.h>

int serial_open(const char *device);
void serial_close(void);
int serial_send_byte(uint8_t data);
int serial_receive_byte(uint8_t *data);
int serial_send_string(const char *str);
int serial_receive_string(char *buffer, size_t maxlen);

#endif
