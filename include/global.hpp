#pragma once

#include <magic.h>

#include <filesystem>
#include <memory>
#include <string>

#include "config.hpp"
#include "debug.hpp"

namespace Global {
	void init();
	void cleanup();

	constexpr static unsigned TICK = 1000;  // ms
	extern Config config;
	extern magic_t cookie;
	extern std::filesystem::path current_path;
};
