#include <string>

extern "C" int answer() {
    return std::string("manylinux").size() + 33;
}

#ifdef EXPECT_CONTAINER_SHIM
static_assert(CONTAINER_SHIM_VALUE == 42, "The compiler shim must supply its fixed arguments");
#endif
