// syscalls.c — bare-metal newlib syscall overrides for ZSBL
//
// The riscv64-unknown-elf toolchain's newlib provides default implementations
// of these functions that use ecall (Linux ABI syscalls), which crash on bare
// metal because there is no OS trap handler.  Defining them here causes the
// linker to use these versions instead of the ecall-based ones in libc.a.
//
// _write   → sends bytes to UART so printf/puts output appears on the console
// _fstat   → marks stdout as a character device (prevents stdio buffering)
// _isatty  → returns 1 (tty) so stdio is unbuffered
// _sbrk    → bump-pointer heap allocator (required by malloc inside newlib)
// _exit    → infinite loop (no OS to return to)
// _getpid, _kill → stubs required by abort() / assert()
// _close, _lseek, _read → required to satisfy the linker

#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <stdint.h>

extern void write_serial(char a);   // uart.c

// ---------------------------------------------------------------------------
// stdout → UART
// ---------------------------------------------------------------------------
int _write(int fd, const char *buf, int count) {
    for (int i = 0; i < count; i++)
        write_serial(buf[i]);
    return count;
}

// ---------------------------------------------------------------------------
// File-descriptor stubs
// ---------------------------------------------------------------------------
int _fstat(int fd, struct stat *st) {
    st->st_mode = S_IFCHR;  // character device — tells stdio not to buffer
    return 0;
}

int _isatty(int fd) {
    return 1;
}

int _close(int fd) {
    errno = EBADF;
    return -1;
}

off_t _lseek(int fd, off_t offset, int whence) {
    errno = ESPIPE;
    return (off_t)-1;
}

int _read(int fd, char *buf, int count) {
    return 0;   // no stdin
}

// ---------------------------------------------------------------------------
// Heap (required by newlib's malloc / printf internal buffers)
// ---------------------------------------------------------------------------
extern char _end;           // defined by linker script — end of .bss

void *_sbrk(ptrdiff_t incr) {
    static char *heap_end = NULL;
    if (heap_end == NULL)
        heap_end = &_end;
    char *prev = heap_end;
    heap_end += incr;
    return (void *)prev;
}

// ---------------------------------------------------------------------------
// Process / signal stubs (required by abort() called from assert())
// ---------------------------------------------------------------------------
int _getpid(void) {
    return 1;
}

int _kill(int pid, int sig) {
    errno = EINVAL;
    return -1;
}

void _exit(int status) {
    while (1) {}
}
