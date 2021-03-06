#pragma once
#include <iostream>

#ifndef DEBUG
#ifndef NDEBUG
#define DEBUG
#endif
#endif

namespace debug {

class DummyStream {
public:
	template <typename T>
	constexpr DummyStream &operator<<(T /*rhs*/) {
		return *this;
	}
};

#define CURRENT_LOCATION "File:" << __FILE__ << " Line:" << __LINE__ << ' '

#ifdef DEBUG
#define LOG std::cerr << CURRENT_LOCATION
#else
#define LOG debug::DummyStream()
#endif

}  // namespace debug
