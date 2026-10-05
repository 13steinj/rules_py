#include <sys/random.h>

// glibc 2.25: relabeling this as manylinux2014 must fail.
extern "C" int future() {
    char value;
    return getrandom(&value, 1, 0);
}
