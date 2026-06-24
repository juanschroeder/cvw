#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <fstream>
#include <limits>
#include <memory>
#include <string>
#include <thread>
#include <chrono>
#include <ctime>
#include <unistd.h>
#include <fcntl.h>
#include <pty.h>
#include <termios.h>

#include "verilated.h"
#if VM_TRACE
#include "verilated_fst_c.h"
#endif

#include "Vtestbench_cvwsoc.h"
#include "Vtestbench_cvwsoc__Dpi.h"
#include "Vtestbench_cvwsoc___024root.h"

#ifndef DUT_UART_RX
#define DUT_UART_RX testbench_cvwsoc__DOT__UARTSin
#endif

#ifndef DUT_UART_TX
#define DUT_UART_TX testbench_cvwsoc__DOT__UARTSout
#endif

#ifndef DUT_UART_CHAR_VALID
#define DUT_UART_CHAR_VALID testbench_cvwsoc__DOT__uart_char_valid
#endif

#ifndef DUT_UART_CHAR_DATA
#define DUT_UART_CHAR_DATA testbench_cvwsoc__DOT__uart_char_data
#endif

#ifndef DUT_UART_FCR
#define DUT_UART_FCR testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__FCR
#endif

#ifndef DUT_UART_RX_FIFO_HEAD
#define DUT_UART_RX_FIFO_HEAD testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__rxfifohead
#endif

#ifndef DUT_UART_RX_FIFO_ENTRIES
#define DUT_UART_RX_FIFO_ENTRIES testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__rxfifoentries
#endif

#ifndef DUT_UART_RX_DATA_READY
#define DUT_UART_RX_DATA_READY testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__rxdataready
#endif

#ifndef DUT_UART_RX_BUFFER
#define DUT_UART_RX_BUFFER testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__RXBR
#endif

#ifndef DUT_UART_LSR
#define DUT_UART_LSR testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__LSR
#endif

#ifndef DUT_UART_RX_STATE
#define DUT_UART_RX_STATE testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__rxstate
#endif

#ifndef DUT_UART_RX_SHIFTREG
#define DUT_UART_RX_SHIFTREG testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__rxshiftreg
#endif

#ifndef DUT_UART_SIN_SYNC
#define DUT_UART_SIN_SYNC testbench_cvwsoc__DOT__soc__DOT__uncoregen__DOT__uncore__DOT__uartgen__DOT__uart__DOT__uartPC__DOT__SINsync
#endif

extern "C" const char* getenvval(const char* pszName) {
    const char* pszValue = std::getenv(pszName);
    return (pszValue == nullptr) ? "" : pszValue;
}

extern "C" double wallclock_seconds() {
    const auto now = std::chrono::steady_clock::now().time_since_epoch();
    const auto now_ns =
        std::chrono::duration_cast<std::chrono::nanoseconds>(now).count();
    return static_cast<double>(now_ns) * 1.0e-9;
}

extern "C" const char* wallclock_datetime() {
    thread_local char buffer[32];
    const auto now = std::chrono::system_clock::now();
    const auto seconds =
        std::chrono::time_point_cast<std::chrono::seconds>(now);
    const auto micros = std::chrono::duration_cast<std::chrono::microseconds>(
                            now - seconds)
                            .count();
    const std::time_t now_time = std::chrono::system_clock::to_time_t(now);
    std::tm local_tm {};
    localtime_r(&now_time, &local_tm);
    std::snprintf(buffer, sizeof(buffer), "%04d-%02d-%02d %02d:%02d:%02d.%06lld",
                  local_tm.tm_year + 1900, local_tm.tm_mon + 1,
                  local_tm.tm_mday, local_tm.tm_hour, local_tm.tm_min,
                  local_tm.tm_sec, static_cast<long long>(micros));
    return buffer;
}

namespace {

constexpr std::uint8_t kUartIdle = 0;
constexpr std::uint8_t kUartDone = 2;

std::atomic<bool> g_trace_toggle_req{false};
std::atomic<bool> g_trace_status_req{false};

std::string get_plusarg_value(int argc, char** argv, const char* prefix,
                              const std::string& fallback = "") {
    const size_t prefix_len = std::strlen(prefix);
    for (int i = 1; i < argc; ++i) {
        if (std::strncmp(argv[i], prefix, prefix_len) == 0) {
            return std::string(argv[i] + prefix_len);
        }
    }
    return fallback;
}

unsigned get_plusarg_uint(int argc, char** argv, const char* prefix,
                          unsigned fallback) {
    const std::string value = get_plusarg_value(argc, argv, prefix, "");
    if (value.empty()) {
        return fallback;
    }

    char* endptr = nullptr;
    const unsigned long parsed = std::strtoul(value.c_str(), &endptr, 0);
    if ((endptr == nullptr) || (*endptr != '\0')) {
        return fallback;
    }
    return static_cast<unsigned>(parsed);
}

std::uint64_t get_plusarg_u64(int argc, char** argv, const char* prefix,
                              std::uint64_t fallback) {
    const std::string value = get_plusarg_value(argc, argv, prefix, "");
    if (value.empty()) {
        return fallback;
    }

    char* endptr = nullptr;
    const unsigned long long parsed = std::strtoull(value.c_str(), &endptr, 0);
    if ((endptr == nullptr) || (*endptr != '\0')) {
        return fallback;
    }
    return static_cast<std::uint64_t>(parsed);
}

extern "C" void on_sigusr1(int) {
    g_trace_toggle_req.store(true, std::memory_order_relaxed);
}

extern "C" void on_sigusr2(int) {
    g_trace_status_req.store(true, std::memory_order_relaxed);
}

std::atomic<bool> g_stop_req{false};

extern "C" void on_stop(int) {
    g_stop_req.store(true, std::memory_order_relaxed);
}

class UartPtyBridge {
  public:
    static constexpr std::uint64_t kNoTime = std::numeric_limits<std::uint64_t>::max();

    UartPtyBridge() = default;
    ~UartPtyBridge() {
        if (master_fd_ >= 0) {
            ::close(master_fd_);
        }
        if (slave_fd_ >= 0) {
            ::close(slave_fd_);
        }
    }

    bool init(unsigned baud, std::uint64_t bit_ps, unsigned idle_sleep_us,
              bool debug_rx, bool tx_to_pty) {
        baud_ = baud;
        bit_ps_ = bit_ps;
        idle_sleep_us_ = idle_sleep_us;
        debug_rx_ = debug_rx;
        tx_to_pty_ = tx_to_pty;
        rx_line_ = 1;
        tx_prev_valid_ = false;

        if (::openpty(&master_fd_, &slave_fd_, slave_name_, nullptr, nullptr) != 0) {
            std::perror("openpty");
            master_fd_ = -1;
            slave_fd_ = -1;
            return false;
        }

        const int master_flags = ::fcntl(master_fd_, F_GETFL, 0);
        if (master_flags >= 0) {
            (void)::fcntl(master_fd_, F_SETFL, master_flags | O_NONBLOCK);
        }

        struct termios tio {};
        if (::tcgetattr(slave_fd_, &tio) == 0) {
            ::cfmakeraw(&tio);
            ::tcsetattr(slave_fd_, TCSANOW, &tio);
        }

        enabled_ = true;
        std::printf("[uart] PTY ready: %s\n", slave_name_);
        std::printf("[uart] host terminal example: picocom -q -b %u %s\n", baud_, slave_name_);
        std::printf("[uart] PTY TX mirror: %s\n", tx_to_pty_ ? "on" : "off");
        std::fflush(stdout);
        return true;
    }

    bool enabled() const { return enabled_; }

    int rx_line() const { return rx_line_; }

    std::uint64_t next_event_time() const {
        return rx_active_ ? rx_next_time_ : kNoTime;
    }

    bool quiet() const {
        return rx_fifo_.empty() && !rx_active_;
    }

    void maybe_sleep() const {
        if (idle_sleep_us_ != 0U && quiet()) {
            std::this_thread::sleep_for(std::chrono::microseconds(idle_sleep_us_));
        }
    }

    template <typename Top>
    void drive_inputs(Top* top, std::uint64_t now_ps) {
        (void)now_ps;
        if (!enabled_) {
            return;
        }

        poll_host();
        top->rootp->DUT_UART_RX = 1;

        if (!rx_fifo_.empty() && can_accept_byte(top)) {
            inject_rx_byte(top, rx_fifo_.front());
            rx_fifo_.pop_front();
        }
    }

    template <typename Top>
    void sample_output(Top* top, std::uint64_t /*now_ps*/) {
        if (!enabled_) {
            return;
        }

        const int char_valid = top->rootp->DUT_UART_CHAR_VALID ? 1 : 0;
        if (tx_to_pty_ && char_valid && !tx_prev_valid_) {
            const unsigned char ch = static_cast<unsigned char>(top->rootp->DUT_UART_CHAR_DATA & 0xffU);
            const ssize_t rc = ::write(master_fd_, &ch, 1);
            (void)rc;
        }
        tx_prev_valid_ = char_valid;
    }

  private:
    template <typename Top>
    bool can_accept_byte(Top* top) const {
        const bool fifo_enabled = (top->rootp->DUT_UART_FCR & 0x01U) != 0;
        if (top->rootp->DUT_UART_RX_STATE != kUartIdle) {
            return false;
        }
        if (fifo_enabled) {
            return top->rootp->DUT_UART_RX_FIFO_ENTRIES < 15;
        }
        return top->rootp->DUT_UART_RX_DATA_READY == 0;
    }

    template <typename Top>
    void inject_rx_byte(Top* top, std::uint8_t byte) {
        auto* root = top->rootp;
        std::uint16_t shiftreg = 0x0001U;  // valid stop bit, no framing/parity error
        for (unsigned bit = 0; bit < 8; ++bit) {
            if ((byte >> bit) & 0x1U) {
                shiftreg |= static_cast<std::uint16_t>(1U << (8U - bit));
            }
        }
        root->DUT_UART_RX_SHIFTREG = shiftreg;
        root->DUT_UART_SIN_SYNC = 1;
        root->DUT_UART_RX_STATE = kUartDone;

        if (debug_rx_) {
            std::printf("[uart-rx] injected byte 0x%02x '%c' via rxstate=done shiftreg=0x%03x\n",
                        byte,
                        (byte >= 32 && byte <= 126) ? static_cast<int>(byte) : '.',
                        shiftreg & 0x7ffU);
            std::fflush(stdout);
        }
    }

    void poll_host() {
        if (!enabled_) {
            return;
        }

        unsigned char buf[256];
        while (true) {
            const ssize_t rc = ::read(master_fd_, buf, sizeof(buf));
            if (rc > 0) {
                for (ssize_t i = 0; i < rc; ++i) {
                    const std::uint8_t ch = static_cast<std::uint8_t>(buf[i]);
                    rx_fifo_.push_back(ch);
                    if (debug_rx_) {
                        std::printf("[uart-rx] host byte 0x%02x '%c'\n", ch,
                                    (ch >= 32 && ch <= 126) ? static_cast<int>(ch) : '.');
                        std::fflush(stdout);
                    }
                }
                continue;
            }
            if ((rc < 0) && ((errno == EAGAIN) || (errno == EWOULDBLOCK))) {
                break;
            }
            if (rc <= 0) {
                break;
            }
        }
    }

    bool enabled_ = false;
    unsigned baud_ = 115200;
    std::uint64_t bit_ps_ = 0;
    unsigned idle_sleep_us_ = 0;
    bool debug_rx_ = false;
    bool tx_to_pty_ = true;

    int master_fd_ = -1;
    int slave_fd_ = -1;
    char slave_name_[128] = {};

    std::deque<std::uint8_t> rx_fifo_;
    int rx_line_ = 1;
    bool rx_active_ = false;
    std::uint64_t rx_next_time_ = kNoTime;
    bool tx_prev_valid_ = false;
};

}  // namespace

int main(int argc, char** argv, char**) {
    Verilated::debug(0);
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    const unsigned sim_threads =
        get_plusarg_uint(argc, argv, "+VERILATOR_THREADS=", 1);
    contextp->threads(sim_threads);
    contextp->commandArgs(argc, argv);
#if VM_TRACE
    contextp->traceEverOn(true);
#endif

    const std::unique_ptr<Vtestbench_cvwsoc> topp{new Vtestbench_cvwsoc{contextp.get(), ""}};

    std::FILE* pid_file = std::fopen("sim/verilator/logs/testbench_cvwsoc.pid", "w");
    if (pid_file != nullptr) {
        std::fprintf(pid_file, "%ld\n", static_cast<long>(::getpid()));
        std::fclose(pid_file);
    }

    const unsigned uart_enable = get_plusarg_uint(argc, argv, "+UART_ENABLE=", 1);
    const unsigned uart_baud = get_plusarg_uint(argc, argv, "+UART_BAUD=", 115200);
    const std::uint64_t uart_bit_ps =
        get_plusarg_u64(argc, argv, "+UART_BIT_PS=",
                        uart_baud ? (1000000000000ULL / uart_baud) : 8680556ULL);
    const unsigned uart_idle_sleep_us =
        get_plusarg_uint(argc, argv, "+UART_IDLE_SLEEP_US=", 0);
    const unsigned uart_rx_debug =
        get_plusarg_uint(argc, argv, "+UART_RX_DEBUG=", 0);
    const unsigned uart_pty_tx =
        get_plusarg_uint(argc, argv, "+UART_PTY_TX=", 1);

    UartPtyBridge uart;
    if (uart_enable != 0U) {
        if (!uart.init(uart_baud, uart_bit_ps, uart_idle_sleep_us,
                       uart_rx_debug != 0U, uart_pty_tx != 0U)) {
            return 1;
        }
    }

    topp->rootp->DUT_UART_RX = 1;

    std::signal(SIGINT, on_stop);
    std::signal(SIGTERM, on_stop);

#if VM_TRACE
    const std::string trace_prefix =
        get_plusarg_value(argc, argv, "+TRACE_FILE_PREFIX=", "dump");
    const bool runtime_trace_control =
        (get_plusarg_value(argc, argv, "+TRACE_RUNTIME_CONTROL=", "1") != "0");

    std::signal(SIGUSR1, on_sigusr1);
    std::signal(SIGUSR2, on_sigusr2);

    bool trace_enabled = false;
    std::uint64_t capture_index = 0;
    std::string current_trace_file;
    std::unique_ptr<VerilatedFstC> tfp;

    if (runtime_trace_control) {
        std::printf("[trace] runtime control enabled pid=%ld prefix=%s threads=%u\n",
                    static_cast<long>(::getpid()), trace_prefix.c_str(),
                    sim_threads);
        std::printf("[trace] use: kill -USR1 %ld to toggle capture, kill -USR2 %ld for status\n",
                    static_cast<long>(::getpid()), static_cast<long>(::getpid()));
        std::fflush(stdout);
    }
#endif

    while (VL_LIKELY(!contextp->gotFinish()
                    && !g_stop_req.load(std::memory_order_relaxed))) {
#if VM_TRACE
        if (runtime_trace_control &&
            g_trace_toggle_req.exchange(false, std::memory_order_relaxed)) {
            if (trace_enabled) {
                tfp->flush();
                tfp->close();
                tfp.reset();
                trace_enabled = false;
                std::printf("[trace] stopped file=%s time=%llu\n",
                            current_trace_file.c_str(),
                            static_cast<unsigned long long>(contextp->time()));
                current_trace_file.clear();
            } else {
                capture_index++;
                current_trace_file = trace_prefix + "_capture_" +
                                     std::to_string(capture_index) + "_time_" +
                                     std::to_string(contextp->time()) + ".fst";
                tfp = std::make_unique<VerilatedFstC>();
                topp->trace(tfp.get(), 99);
                tfp->open(current_trace_file.c_str());
                trace_enabled = true;
                std::printf("[trace] started file=%s time=%llu\n",
                            current_trace_file.c_str(),
                            static_cast<unsigned long long>(contextp->time()));
            }
            std::fflush(stdout);
        }

        if (runtime_trace_control &&
            g_trace_status_req.exchange(false, std::memory_order_relaxed)) {
            std::printf("[trace] status enabled=%d file=%s time=%llu\n",
                        trace_enabled ? 1 : 0,
                        current_trace_file.empty() ? "<none>" : current_trace_file.c_str(),
                        static_cast<unsigned long long>(contextp->time()));
            std::fflush(stdout);
        }
#endif

        if (uart.enabled()) {
            uart.drive_inputs(topp.get(), contextp->time());
        }

        topp->eval();

        if (uart.enabled()) {
            uart.sample_output(topp.get(), contextp->time());
        }

#if VM_TRACE
        if (trace_enabled && tfp) {
            tfp->dump(contextp->time());
        }
#endif

        std::uint64_t next_time = UartPtyBridge::kNoTime;
        if (topp->eventsPending()) {
            next_time = topp->nextTimeSlot();
        }

        if (next_time == UartPtyBridge::kNoTime) {
            break;
        }

        if (uart.enabled()) {
            uart.maybe_sleep();
        }
        contextp->time(next_time);
    }

    const bool interrupted = g_stop_req.load(std::memory_order_relaxed);

    if (interrupted) {
        std::printf("[sim] caught SIGINT/SIGTERM, closing simulation cleanly at time=%llu\n",
                    static_cast<unsigned long long>(contextp->time()));
        std::fflush(stdout);
    }

    topp->final();

#if VM_TRACE
    if (trace_enabled && tfp) {
        tfp->flush();
        tfp->close();
        tfp.reset();
        std::printf("[trace] final close file=%s time=%llu\n",
                    current_trace_file.c_str(),
                    static_cast<unsigned long long>(contextp->time()));
        std::fflush(stdout);
    }
#endif

    contextp->statsPrintSummary();
    return interrupted ? 130 : 0;
}
