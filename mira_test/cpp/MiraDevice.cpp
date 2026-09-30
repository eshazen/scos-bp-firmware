//
// Bernhard's python class mira.py converted by AI to C++
// 

#include "MiraDevice.h"
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>

// Constants
static constexpr uint32_t USLEEP_DELAY = 10;
static constexpr const char* CONFIG_DIR = "./mira_cfgs/";
static constexpr const char* DEFAULT_CONFIG = "Mira220_100Mbps_vertical_test_pattern.csv";

// Constructor
MiraDevice::MiraDevice(uint8_t i2c_addr) : mira_addr(i2c_addr), scl_f(1), sda_f(1) {
}

// Destructor
MiraDevice::~MiraDevice() {
    close();
}

// Initialization
bool MiraDevice::initialize() {
    // Initialize SPI bus
    const std::string spi_device = "/dev/spidev0.0";
    uint8_t spi_mode = SPI_MODE_0;
    uint32_t spi_max_speed_hz = 10000000;  // 10 MHz

    if (!spi.open_spi(spi_device, spi_mode, spi_max_speed_hz)) {
        std::cerr << "Failed to open SPI device" << std::endl;
        return false;
    }

    // Flush CFG FSM
    spi.writebytes2(0x00, 0x00, 0x00);

    // Select CFG register as data source
    spi.writebytes2(0xFE, (1 << 7) + 1, 0x00);

    // Reset TX buffer in FPGA
    spi.writebytes2(0xFE, (1 << 7) + 0, (1 << 7));
    spi.writebytes2(0xFE, (1 << 7) + 0, 0x00);

    sleep_ms(1);
    update_force();

    return true;
}

void MiraDevice::close() {
    spi.close_spi();
}

// ---- I2C Bit-Bang Functions ----

void MiraDevice::update_force() {
    // Force I2C pins to either 0 or high-impedance
    spi.writebytes2(0xFE, (1 << 7) + 8, (sda_f << 1) + scl_f);
}

void MiraDevice::read_bit() {
    // Trigger reading single bit of SDA
    spi.writebytes2(0xFE, 8, 0x00);
}

uint8_t MiraDevice::read_all_bits() {
    // Collect all bit reads triggered by read_bit()
  uint8_t* buf = spi.read_bytes(2 + 8 * 2);

    if (buf[0] != 8 * 2 || buf[1] != 0) {
        std::cerr << "Error: unexpected number of available bytes" << std::endl;
//	for( int i=0; i<buf.size(); i++)
//	  fprintf( stderr, " %d: 0x%x\n", i, buf[i]);
	exit( 1);
    }

    uint8_t res = 0;
    for (int ibit = 0; ibit < 8; ibit++) {
        if (buf[ibit * 2 + 2] != 0xFD) {
            std::cerr << "Header error in bit read" << std::endl;
        }
        res += ((buf[ibit * 2 + 3] >> 3) & 1) * (1 << (7 - ibit));
    }
    return res;
}

void MiraDevice::i2c_start() {
    // Generate I2C START condition
    scl_f = 1;
    sda_f = 1;
    update_force();

    scl_f = 1;
    sda_f = 0;
    update_force();

    scl_f = 0;
    sda_f = 0;
    update_force();
}

void MiraDevice::i2c_rep_start() {
    // Generate I2C repeated START condition
    scl_f = 0;
    sda_f = 1;
    update_force();

    scl_f = 1;
    sda_f = 1;
    update_force();

    scl_f = 1;
    sda_f = 0;
    update_force();

    scl_f = 0;
    sda_f = 0;
    update_force();
}

void MiraDevice::i2c_stop() {
    // Generate I2C STOP condition
    scl_f = 0;
    sda_f = 0;
    update_force();

    scl_f = 1;
    sda_f = 0;
    update_force();

    scl_f = 1;
    sda_f = 1;
    update_force();
}

void MiraDevice::send_byte(uint8_t data) {
    // Send a byte of data over I2C
    // Note: low-level function, needs to be used with i2c_start(), i2c_stop(), etc.
    for (int ii = 7; ii >= 0; ii--) {
        uint8_t bval = (data >> ii) & 1;
        scl_f = 0;
        sda_f = bval;
        update_force();

        scl_f = 1;
        sda_f = bval;
        update_force();
    }

    // ACK/NACK bit handling (wait for ACK)
    // Note: not reading ACK in this implementation, just releasing the line
    scl_f = 0;
    sda_f = 1;
    update_force();

    scl_f = 1;
    sda_f = 1;
    update_force();

    scl_f = 0;
    sda_f = 1;
    update_force();
}

uint8_t MiraDevice::read_byte() {
    // Read a byte from I2C
    // Note: low-level function, needs to be used with i2c_start(), i2c_stop(), etc.
    for (int ii = 0; ii < 8; ii++) {
        scl_f = 0;
        sda_f = 1;
        update_force();

        scl_f = 1;
        sda_f = 1;
        update_force();

        read_bit();
    }

    // Send NACK bit as we only do a single byte read
    scl_f = 0;
    sda_f = 1;
    update_force();

    scl_f = 1;
    sda_f = 1;
    update_force();

    scl_f = 0;
    sda_f = 1;
    update_force();

    return read_all_bits();
}

// ---- Register Access Functions ----

void MiraDevice::reg_write_internal(uint16_t reg_addr, uint8_t reg_data) {
    // Write a single register of MIRA
    i2c_start();
    send_byte(mira_addr << 1);           // Address byte (write)
    send_byte(reg_addr >> 8);            // Register address high byte
    send_byte(reg_addr & 0xFF);          // Register address low byte
    send_byte(reg_data);                 // Data byte
    i2c_stop();
}

uint8_t MiraDevice::reg_read_internal(uint16_t reg_addr) {
    // Read a single register of MIRA
    i2c_start();
    send_byte(mira_addr << 1);           // Address byte (write)
    send_byte(reg_addr >> 8);            // Register address high byte
    send_byte(reg_addr & 0xFF);          // Register address low byte
    i2c_rep_start();
    send_byte((mira_addr << 1) + 1);     // Address byte (read)
    uint8_t res = read_byte();
    i2c_stop();
    return res;
}

bool MiraDevice::write_register(uint16_t reg_addr, uint8_t reg_data) {
    try {
        reg_write_internal(reg_addr, reg_data);
        return true;
    } catch (...) {
        return false;
    }
}

bool MiraDevice::read_register(uint16_t reg_addr, uint8_t& reg_data) {
    try {
        reg_data = reg_read_internal(reg_addr);
        return true;
    } catch (...) {
        return false;
    }
}

// ---- OTP Functions ----

void MiraDevice::otp_power_on() {
    reg_write_internal(0x0080, 0x04);
}

void MiraDevice::otp_power_off() {
    reg_write_internal(0x0080, 0x08);
}

uint8_t MiraDevice::otp_read_byte(uint8_t otp_address, uint8_t offset) {
    reg_write_internal(0x0086, otp_address);
    reg_write_internal(0x0080, 0x02);
    return reg_read_internal(0x0082 + offset);
}

void MiraDevice::trim_restore(uint16_t reg_address, uint8_t otp_address) {
    uint8_t data = otp_read_byte(otp_address, 0);
    reg_write_internal(reg_address, data);
}

bool MiraDevice::restore_trims() {
    try {
        // Addresses of the registers where the values from OTP need to be restored
        const uint16_t reg_addresses[] = {
            0x4015, 0x4016, 0x4017, 0x4018, 0x403B, 0x4040,
            0x4041, 0x4042, 0x402A, 0x4029, 0x4009, 0x403E
        };
        const uint8_t num_trims = 12;

        for (uint8_t ii = 0; ii < 11; ii++) {
            trim_restore(reg_addresses[ii], ii);
        }
        // New for rev2: restore OTP data at address 13
        trim_restore(reg_addresses[11], 13);

        return true;
    } catch (...) {
        return false;
    }
}

bool MiraDevice::read_internal_id(std::vector<uint8_t>& sensor_id) {
    try {
        sensor_id.resize(8);
        sensor_id[0] = otp_read_byte(0x25, 0);  // byte 0 otp address 0x25
        sensor_id[1] = otp_read_byte(0x1E, 0);  // byte 0 otp address 0x1E
        sensor_id[2] = otp_read_byte(0x1E, 1);  // byte 1 otp address 0x1E
        sensor_id[3] = otp_read_byte(0x1E, 2);  // byte 2 otp address 0x1E
        sensor_id[4] = otp_read_byte(0x1D, 0);  // byte 0 otp address 0x1D
        sensor_id[5] = otp_read_byte(0x1D, 1);  // byte 1 otp address 0x1D
        sensor_id[6] = otp_read_byte(0x1D, 2);  // byte 2 otp address 0x1D
        sensor_id[7] = otp_read_byte(0x1D, 3);  // byte 3 otp address 0x1D

        printf("Sensor ID: 0x");
        for (int ii = 0; ii < 7; ii++) {
            printf("%02x:", sensor_id[ii]);
        }
        printf("%02x\n", sensor_id[7]);

        return true;
    } catch (...) {
        return false;
    }
}

bool MiraDevice::read_dark_mean(uint16_t& dark_mean) {
    try {
        uint8_t b0 = otp_read_byte(0x0E, 0);  // byte 0 otp address 0x0E
        uint8_t b1 = otp_read_byte(0x0E, 1);  // byte 1 otp address 0x0E
        dark_mean = (b1 << 8) + b0;
        printf("OTP dark mean: 0x%04x\n", dark_mean);
        return true;
    } catch (...) {
        return false;
    }
}

bool MiraDevice::read_revision(uint8_t& revision) {
    try {
        revision = otp_read_byte(0x3A, 0);
        printf("Revision: 0x%02x\n", revision);
        return true;
    } catch (...) {
        return false;
    }
}

bool MiraDevice::main_otp_ops() {
    try {
        otp_power_on();
        restore_trims();
        
        std::vector<uint8_t> sensor_id;
        read_internal_id(sensor_id);
        
        uint16_t dark_mean;
        read_dark_mean(dark_mean);
        
        uint8_t revision;
        read_revision(revision);
        
        otp_power_off();
        return true;
    } catch (...) {
        return false;
    }
}

// ---- PLL and LDO Control ----

bool MiraDevice::check_pll(bool verbose) {
    uint8_t data = reg_read_internal(0x50DC);
    bool pll_locked = (data & 0x01) > 0;
    bool ref_clk_missing = (data & 0x02) > 0;

    if (verbose) {
        printf("PLL locked: %s, Ref clock missing: %s\n",
               pll_locked ? "true" : "false",
               ref_clk_missing ? "true" : "false");
    }
    return pll_locked;
}

bool MiraDevice::set_ldo(bool enable) {
    try {
        // These registers are not properly documented in the Mira220 datasheet
        // Taking the 'off' values from section 7.2.1 and the 'on' values as read at power-up
        if (enable) {
            reg_write_internal(0x4038, 0xFB);
            reg_write_internal(0x401E, 0x03);
        } else {
            reg_write_internal(0x401E, 0x02);
            reg_write_internal(0x4038, 0x3B);
        }
        return true;
    } catch (...) {
        return false;
    }
}

// ---- Configuration Upload ----

bool MiraDevice::upload_config(const std::string& cfg_filename, bool verbose) {
    std::string full_path;

    if (cfg_filename.empty()) {
        full_path = std::string(CONFIG_DIR) + DEFAULT_CONFIG;
    } else {
        full_path = cfg_filename;
    }

    std::ifstream file(full_path);
    if (!file.is_open()) {
        std::cerr << "Failed to open config file: " << full_path << std::endl;
        return false;
    }

    std::string line;
    try {
        while (std::getline(file, line)) {
            // Skip empty lines and comments
            if (line.empty() || line[0] == '#') {
                continue;
            }

            // Parse CSV format: "0x1234, 0x56, description"
            std::stringstream ss(line);
            std::string token;
            std::vector<std::string> tokens;

            while (std::getline(ss, token, ',')) {
                // Trim whitespace
                token.erase(0, token.find_first_not_of(" \t\r\n"));
                token.erase(token.find_last_not_of(" \t\r\n") + 1);
                tokens.push_back(token);
            }

            if (tokens.size() >= 2) {
                try {
                    uint16_t reg_addr = std::stoul(tokens[0], nullptr, 16);
                    uint8_t reg_data = std::stoul(tokens[1], nullptr, 16);

                    reg_write_internal(reg_addr, reg_data);

                    if (verbose && tokens.size() >= 3) {
                        printf("%s\n", tokens[2].c_str());
                    }
                } catch (const std::exception& e) {
                    std::cerr << "Error parsing config line: " << line << std::endl;
                    std::cerr << "Exception: " << e.what() << std::endl;
                    continue;
                }
            }
        }
        file.close();
        return true;
    } catch (...) {
        file.close();
        return false;
    }
}

// ---- Main Initialization Sequence (per datasheet section 7.2.1) ----

bool MiraDevice::turn_on(const std::string& cfg_filename) {
    std::string config_file = cfg_filename.empty() ? DEFAULT_CONFIG : cfg_filename;
    printf("Initializing Mira with config file: %s\n", config_file.c_str());

    // Step 1-5: Handled by sequencer chip on demo board

    // Step 6: Wait for PLL to lock
    printf("Waiting for PLL to lock...\n");
    int timeout_count = 0;
    const int max_timeout = 1000;  // 10 seconds with 10ms sleep

    while (!check_pll() && timeout_count < max_timeout) {
        sleep_ms(10);
        timeout_count++;
    }

    if (timeout_count >= max_timeout) {
        std::cerr << "Error: PLL failed to lock (timeout)" << std::endl;
        return false;
    }
    printf("PLL locked!\n");

    // Step 7: Disable internal LDOs
    printf("Disabling internal LDOs...\n");
    if (!set_ldo(false)) {
        std::cerr << "Error: Failed to disable LDOs" << std::endl;
        return false;
    }
    sleep_ms(10);

    // Step 8: Restore LDO and gain calibration values from OTP
    printf("Restoring OTP calibration values...\n");
    if (!main_otp_ops()) {
        std::cerr << "Error: Failed to restore OTP values" << std::endl;
        return false;
    }

    // Note: Skipping re-enable as per Python implementation comment
    sleep_ms(10);

    // Step 9: Upload configuration
    printf("Uploading configuration...\n");
    if (!upload_config(config_file)) {
        std::cerr << "Error: Failed to upload configuration" << std::endl;
        return false;
    }
    sleep_ms(50);

    // Soft reset
    printf("Performing soft reset...\n");
    reg_write_internal(0x0040, 0x01);

    printf("Mira initialization complete!\n");
    return true;
}

// ---- Utility Functions ----

void MiraDevice::sleep_ms(uint32_t ms) {
    std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

void MiraDevice::sleep_us(uint32_t us) {
    std::this_thread::sleep_for(std::chrono::microseconds(us));
}
