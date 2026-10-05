#include <string>

extern "C" int answer() {
    return std::string("manylinux").size() + 33;
}
