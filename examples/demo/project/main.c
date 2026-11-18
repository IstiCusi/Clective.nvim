#include <platform.h>
#include <exec/libraries.h>
#include "shared.h"

/// # SDK selection demo
/// Switch between Demo SDK A and Demo SDK B, then use gd on platform_value.
/// The definition should come from the selected SDK directory.
int main(void) {
    struct Library library = { platform_value() };
    return library.version;
}
