#include "debug.hpp"

using namespace Debug;

bool Stream::open(const std::string &str) {
	of.open(str.c_str() );
	return of.is_open();
}

void Stream::flush() {
	of.flush();
}
