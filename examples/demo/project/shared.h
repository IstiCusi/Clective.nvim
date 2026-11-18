#ifndef CLECTIVE_DEMO_SHARED_H
#define CLECTIVE_DEMO_SHARED_H

/* The suffix .h does not decide between C and C++. */
#ifdef __cplusplus
namespace demo {
class Example {
public:
    int value() const { return 42; }
};
}
#else
struct Example { int value; };
#endif

#endif
