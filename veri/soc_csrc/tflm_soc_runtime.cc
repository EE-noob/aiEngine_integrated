#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>

extern "C" {

extern char _end;
extern char _stack_top;

void* __dso_handle __attribute__((visibility("hidden"))) = 0;

void _init(void) {}
void _fini(void) {}

void* _sbrk(ptrdiff_t incr) {
  static char* heap_end = &_end;
  char* prev_heap_end = heap_end;
  char* next_heap_end = heap_end + incr;
  char* heap_limit = &_stack_top - 4096;

  if (next_heap_end < &_end || next_heap_end > heap_limit) {
    errno = ENOMEM;
    return reinterpret_cast<void*>(-1);
  }

  heap_end = next_heap_end;
  return prev_heap_end;
}

int _write(int file, const char* ptr, int len) {
  (void)file;
  (void)ptr;
  return len;
}

int _read(int file, char* ptr, int len) {
  (void)file;
  (void)ptr;
  (void)len;
  return 0;
}

int _close(int file) {
  (void)file;
  return -1;
}

int _fstat(int file, struct stat* st) {
  (void)file;
  st->st_mode = S_IFCHR;
  return 0;
}

int _isatty(int file) {
  (void)file;
  return 1;
}

int _lseek(int file, int ptr, int dir) {
  (void)file;
  (void)ptr;
  (void)dir;
  return 0;
}

int _getpid(void) { return 1; }

int _kill(int pid, int sig) {
  (void)pid;
  (void)sig;
  errno = EINVAL;
  return -1;
}

void _exit(int status) {
  volatile uint32_t* soc_status = reinterpret_cast<volatile uint32_t*>(0x20000000u);
  *soc_status = static_cast<uint32_t>(status);
  while (1) {
  }
}

clock_t _times(struct tms* buf) {
  (void)buf;
  return 0;
}

int _gettimeofday(struct timeval* tv, void* tzvp) {
  (void)tzvp;
  if (tv) {
    tv->tv_sec = 0;
    tv->tv_usec = 0;
  }
  return 0;
}

int _open(const char* path, int flags, ...) {
  (void)path;
  (void)flags;
  errno = ENOENT;
  return -1;
}

int _unlink(const char* name) {
  (void)name;
  errno = ENOENT;
  return -1;
}

int _stat(const char* file, struct stat* st) {
  (void)file;
  st->st_mode = S_IFCHR;
  return 0;
}

int _fork(void) {
  errno = EAGAIN;
  return -1;
}

int _execve(char* name, char** argv, char** env) {
  (void)name;
  (void)argv;
  (void)env;
  errno = ENOMEM;
  return -1;
}

int _wait(int* status) {
  (void)status;
  errno = ECHILD;
  return -1;
}

uint32_t soc_get_cycle(void) {
  uint32_t value;
  __asm__ volatile("rdcycle %0" : "=r"(value));
  return value;
}

}  // extern "C"
