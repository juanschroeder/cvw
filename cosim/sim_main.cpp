#include "Vhifive_cvw_cosim.h"
#include "verilated.h"

#if VM_TRACE
#if VM_TRACE_FST
#include "verilated_fst_c.h"
using TraceT = VerilatedFstC;
static constexpr const char *TraceExt = "fst";
#else
#include "verilated_vcd_c.h"
using TraceT = VerilatedVcdC;
static constexpr const char *TraceExt = "vcd";
#endif
#endif

#include <atomic>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <unistd.h>

static std::atomic<bool> g_start_trace{false};
static std::atomic<bool> g_stop_trace{false};
static std::atomic<bool> g_quit{false};

static void handle_signal(int sig)
{
    if(sig == SIGUSR1) {
        g_start_trace.store(true, std::memory_order_relaxed);
    } else if(sig == SIGUSR2) {
        g_stop_trace.store(true, std::memory_order_relaxed);
    } else if(sig == SIGINT || sig == SIGTERM) {
        g_quit.store(true, std::memory_order_relaxed);
    }
}

int main(int argc, char **argv)
{
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);

#if VM_TRACE
    contextp->traceEverOn(true);
#endif

    auto top = std::make_unique<Vhifive_cvw_cosim>(contextp.get());

    std::signal(SIGUSR1, handle_signal);
    std::signal(SIGUSR2, handle_signal);
    std::signal(SIGINT,  handle_signal);
    std::signal(SIGTERM, handle_signal);

#if VM_TRACE
    TraceT *tfp = nullptr;
    bool tracing = false;

    auto close_trace = [&]() {
        if(tfp != nullptr) {
            tfp->flush();
            tfp->close();
            delete tfp;
            tfp = nullptr;
            tracing = false;
            std::fprintf(stderr, "[Vhifive_cvw_cosim] trace stopped\n");
        }
    };

    auto open_trace = [&]() {
        close_trace();
        const char *dir = std::getenv("TRACE_DIR");
        if(dir == nullptr || dir[0] == '\0') {
            dir = "/tmp";
        }

        char path[1024];
        std::snprintf(path, sizeof(path), "%s/hifive_cvw_axi_cosim_%ld_%llu.%s",
                      dir,
                      static_cast<long>(getpid()),
                      static_cast<unsigned long long>(contextp->time()),
                      TraceExt);

        tfp = new TraceT;
        top->trace(tfp, 99);
        tfp->open(path);
        tracing = true;
        std::fprintf(stderr, "[Vhifive_cvw_cosim] trace started: %s\n", path);
    };
#else
    auto close_trace = []() {};
    auto open_trace = []() {
        std::fprintf(stderr, "[Vhifive_cvw_cosim] tracing was not compiled in. Rebuild with TRACE=1.\n");
    };
#endif

    while(!contextp->gotFinish() && !g_quit.load(std::memory_order_relaxed)) {
        if(g_start_trace.exchange(false, std::memory_order_relaxed)) {
            open_trace();
        }
        if(g_stop_trace.exchange(false, std::memory_order_relaxed)) {
            close_trace();
        }

        top->eval();

#if VM_TRACE
        if(tracing && tfp != nullptr) {
            tfp->dump(contextp->time());
        }
#endif

        if(top->eventsPending()) {
            const uint64_t now = contextp->time();
            const uint64_t next = top->nextTimeSlot();
            contextp->timeInc(next > now ? next - now : 1);
        } else {
            contextp->timeInc(1);
        }
    }

    close_trace();
    top->final();
    return 0;
}
