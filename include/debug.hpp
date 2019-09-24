#pragma once
#include <fstream>
#include <errno.h>

namespace Debug {

class DummyStream {
public:
	template<typename T>
	DummyStream &operator<<(T rhs) {
		return *this;
	}

	constexpr bool open(const std::string &str) const {
		return true;
	}

	void flush() const {};
};

class Stream {
	public:
		bool open(const std::string &str);
		void flush();

		template<typename T>
		Stream &operator<<(const T& rhs) {
			of << rhs;
			return *this;
		}
	private:
		std::ofstream of;
};

}
