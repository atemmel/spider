#pragma once
#include <iostream>

namespace Debug {

class DummyStream {
public:
	template<typename T>
	constexpr DummyStream &operator<<(T rhs) {
		return *this;
	}
};

#define CURRENT_LOCATION "File:" << __FILE__ << " Line:" << __LINE__ << ' '

#ifdef DEBUG
	#define LOG std::cerr << CURRENT_LOCATION
#else
	#define LOG Debug::DummyStream()
#endif


}
