#include <linux/gpio.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#include <array>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>

class LaserDac {
public:
    explicit LaserDac(
        const std::string& chipPath = "/dev/gpiochip0",
        bool shutdownActiveLow = false)
        : shutdownActiveLow_(shutdownActiveLow)
    {
        // These are BCM GPIO numbers, NOT physical header pin numbers.
        constexpr std::array<unsigned int, LineCount> offsets = {
            19, // CS:       physical pin 35
            13, // SCK:      physical pin 33
             6, // SDI:      physical pin 31
            26, // Shutdown: physical pin 37
            18, // Red:      physical pin 12
            24, // Green:    physical pin 18
            25  // Blue:     physical pin 22
        };

        // Initial state: DAC deselected, clock/data low,
        // laser shutdown asserted, RGB LED off.
        levels_ = {
            1,
            0,
            0,
            static_cast<unsigned char>(shutdownActiveLow_ ? 0 : 1),
            1,
            1,
            1
        };

        const int chipFd = ::open(chipPath.c_str(), O_RDONLY | O_CLOEXEC);
        if (chipFd < 0) {
            throwSystemError("Opening " + chipPath);
        }

        gpiohandle_request request{};
        request.lines = LineCount;
        request.flags = GPIOHANDLE_REQUEST_OUTPUT;

        for (unsigned int i = 0; i < LineCount; ++i) {
            request.lineoffsets[i] = offsets[i];
            request.default_values[i] = levels_[i];
        }

        std::strncpy(
            request.consumer_label,
            "laser-dac",
            sizeof(request.consumer_label) - 1);

        const int result =
            ::ioctl(chipFd, GPIO_GET_LINEHANDLE_IOCTL, &request);
        const int savedErrno = errno;
        ::close(chipFd);

        if (result < 0) {
            errno = savedErrno;
            throwSystemError("Requesting GPIO lines");
        }

        lineFd_ = request.fd;

        // Establish a known DAC output while the laser is shut down.
        try {
            setDacCode(0);
        } catch (...) {
            ::close(lineFd_);
            lineFd_ = -1;
            throw;
        }
    }

    ~LaserDac() noexcept
    {
        if (lineFd_ < 0) {
            return;
        }

        // Best-effort safe shutdown. Destructors must not throw.
        // Separate attempts ensure one failure does not skip the others.
        try {
            setShutdown(true);
        } catch (...) {
        }

        try {
            setDacCode(0);
        } catch (...) {
        }

        try {
            setRgb(false, false, false);
        } catch (...) {
        }

        ::close(lineFd_);
    }

    LaserDac(const LaserDac&) = delete;
    LaserDac& operator=(const LaserDac&) = delete;
    LaserDac(LaserDac&&) = delete;
    LaserDac& operator=(LaserDac&&) = delete;

    // asserted=true means "shut down the laser", regardless of polarity.
    void setShutdown(bool asserted)
    {
        const bool high = shutdownActiveLow_ ? !asserted : asserted;
        setLine(Shutdown, high);
    }

    // Active-low LED: true means the channel is illuminated.
    void setRgb(bool red = false, bool green = false, bool blue = false)
    {
        auto next = levels_;
        next[Red]   = red   ? 0 : 1;
        next[Green] = green ? 0 : 1;
        next[Blue]  = blue  ? 0 : 1;
        writeLevels(next);
    }

    // MCP4821: 12-bit code, internal reference, gain of 1x or 2x.
    void setDacCode(int code, int gain = 1)
    {
        if (code < 0 || code > 4095) {
            throw std::invalid_argument("DAC code must be 0 through 4095");
        }

        if (gain != 1 && gain != 2) {
            throw std::invalid_argument("DAC gain must be 1 or 2");
        }

        // Bit 13: GA   = 1 for 1x, 0 for 2x.
        // Bit 12: SHDN = 1 to enable the DAC output.
        const unsigned int command = gain == 1 ? 0x3000u : 0x1000u;
        const unsigned int word =
            command | static_cast<unsigned int>(code);

        setLine(Sck, false);
        setLine(Cs, false);

        // Send MSB first. The MCP4821 samples on rising clock edges.
        for (int bit = 15; bit >= 0; --bit) {
            setLine(Sdi, ((word >> bit) & 1u) != 0);
            setLine(Sck, true);
            setLine(Sck, false);
        }

        setLine(Cs, true);
    }

private:
    enum Line : unsigned int {
        Cs,
        Sck,
        Sdi,
        Shutdown,
        Red,
        Green,
        Blue,
        LineCount
    };

    using Levels = std::array<unsigned char, LineCount>;

    int lineFd_ = -1;
    bool shutdownActiveLow_;
    Levels levels_{};

    [[noreturn]] static void throwSystemError(const std::string& operation)
    {
        const int error = errno;
        throw std::runtime_error(
            operation + ": " + std::strerror(error));
    }

    void writeLevels(const Levels& next)
    {
        gpiohandle_data data{};

        for (unsigned int i = 0; i < LineCount; ++i) {
            data.values[i] = next[i];
        }

        if (::ioctl(lineFd_, GPIOHANDLE_SET_LINE_VALUES_IOCTL, &data) < 0) {
            throwSystemError("Writing GPIO lines");
        }

        levels_ = next;
    }

    void setLine(Line line, bool high)
    {
        auto next = levels_;
        next[line] = high ? 1 : 0;
        writeLevels(next);
    }
};

// The signal handler only requests termination.
// GPIO operations happen in normal program execution.
static volatile std::sig_atomic_t stopRequested = 0;

static void handleSignal(int)
{
    stopRequested = 1;
}

static void printUsage(const char* program)
{
    std::cout
        << "Usage: " << program
        << " [--shutdown-active-low] [--chip PATH] [CODE]\n\n"
        << "No CODE: repeatedly ramp from 0 through 4095.\n"
        << "CODE:    hold a fixed DAC code from 0 through 4095.\n"
        << "Press Ctrl+C to shut down and exit.\n\n"
        << "Defaults: gain=1, active-high shutdown, /dev/gpiochip0.\n";
}

int main(int argc, char* argv[])
{
    try {
        bool shutdownActiveLow = false;
        std::string chipPath = "/dev/gpiochip0";
        bool haveCode = false;
        int code = 0;

        for (int i = 1; i < argc; ++i) {
            const std::string argument = argv[i];

            if (argument == "--help" || argument == "-h") {
                printUsage(argv[0]);
                return 0;
            }

            if (argument == "--shutdown-active-low") {
                shutdownActiveLow = true;
                continue;
            }

            if (argument == "--chip") {
                if (++i >= argc) {
                    throw std::invalid_argument("--chip requires a path");
                }
                chipPath = argv[i];
                continue;
            }

            if (haveCode) {
                throw std::invalid_argument("Unexpected argument: " + argument);
            }

            std::size_t consumed = 0;
            code = std::stoi(argument, &consumed, 10);

            if (consumed != argument.size() || code < 0 || code > 4095) {
                throw std::invalid_argument("CODE must be 0 through 4095");
            }

            haveCode = true;
        }

        std::signal(SIGINT, handleSignal);
        std::signal(SIGTERM, handleSignal);

        LaserDac hardware(chipPath, shutdownActiveLow);

        // The constructor leaves the laser shut down.
        // Set the desired initial DAC value BEFORE enabling the driver.
        hardware.setDacCode(haveCode ? code : 0, 1);
        hardware.setRgb(false, false, false);

        if (!stopRequested) {
            hardware.setShutdown(false);
        }

        if (haveCode) {
            std::cout << "Holding DAC code " << code
                      << ". Press Ctrl+C to shut down.\n";

            while (!stopRequested) {
                std::this_thread::sleep_for(
                    std::chrono::milliseconds(100));
            }
        } else {
            std::cout << "Ramping DAC from 0 through 4095."
                      << " Press Ctrl+C to shut down.\n";

            while (!stopRequested) {
                for (int rampCode = 0;
                     rampCode <= 4095 && !stopRequested;
                     ++rampCode) {
                    hardware.setDacCode(rampCode, 1);
                }
            }
        }

        // Explicit shutdown; the destructor also provides a fallback.
        hardware.setShutdown(true);
        hardware.setDacCode(0);
        hardware.setRgb(false, false, false);

        std::cout << "Laser shut down; DAC set to zero.\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Error: " << error.what() << '\n';
        return 1;
    }
}
