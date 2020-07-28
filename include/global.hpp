#pragma once

#include <magic.h>

#include <filesystem>
#include <memory>
#include <string>

#include "config.hpp"
#include "debug.hpp"

struct Global {
	friend void makeGlobal();
	~Global();

	constexpr static unsigned TICK = 1000;  // ms
	Config config;
	magic_t cookie;
	std::filesystem::path current_path;

private:
	Global();
};

extern std::unique_ptr<Global> globals;

void makeGlobal();
