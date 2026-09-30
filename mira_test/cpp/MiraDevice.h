//
// Bernhard's python class mira.py converted by AI to C++
// 


#ifndef MIRA_DEVICE_H
#define MIRA_DEVICE_H

#include <cstdint>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include "SpiDevice.hh"

class MiraDevice {
private:
    SpiDevice spi;
    uint8_t mira_addr = 0x54;  // Mira220 I2C address
    uint8_t scl_f = 1;         // SCL force state (1 = high-impedance, 0 = driven low)
    uint8_t sda_f = 1;         // SDA force state (1 = high-impedance, 0 = driven low)

    // I2C bit-banging helper functions
    void update_force();
    void read_bit();
    uint8_t read_all_bits();
    void i2c_start();
    void i2c_rep_start();
    void i2c_stop();
    void send_byte(uint8_t data);
    uint8_t read_byte();

    // Low-level register operations
    void reg_write_internal(uint16_t reg_addr, uint8_t reg_data);
    uint8_t reg_read_internal(uint16_t reg_addr);

    // OTP operations
    void otp_power_on();
    void otp_power_off();
    uint8_t otp_read_byte(uint8_t otp_address, uint8_t offset);
    void trim_restore(uint16_t reg_address, uint8_t otp_address);

    // Utility functions
    void sleep_ms(uint32_t ms);
    void sleep_us(uint32_t us);

public:
    // Constructor/Destructor
    MiraDevice(uint8_t i2c_addr = 0x54);
    ~MiraDevice();

    // Initialization
    bool initialize();
    void close();

    // Public register access
    bool write_register(uint16_t reg_addr, uint8_t reg_data);
    bool read_register(uint16_t reg_addr, uint8_t& reg_data);

    // PLL and LDO control
    bool check_pll(bool verbose = false);
    bool set_ldo(bool enable);

    // OTP and trim operations
    bool restore_trims();
    bool read_internal_id(std::vector<uint8_t>& sensor_id);
    bool read_dark_mean(uint16_t& dark_mean);
    bool read_revision(uint8_t& revision);
    bool main_otp_ops();

    // Configuration
    bool upload_config(const std::string& cfg_filename = "", bool verbose = false);

    // Main initialization sequence (per datasheet section 7.2.1)
    bool turn_on(const std::string& cfg_filename = "");
    
    // Setters
    void set_mira_address(uint8_t addr) { mira_addr = addr; }
};

#endif // MIRA_DEVICE_H
