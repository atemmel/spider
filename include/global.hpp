#pragma once

#include <magic.h>

#include <filesystem>
#include <memory>
#include <string>

#include "config.hpp"
#include "debug.hpp"

struct Global {
	friend std::unique_ptr<Global> makeGlobal();
	~Global();

	constexpr static unsigned TICK = 1000;  // ms
	Config config;
	magic_t cookie;
	int windowWidth;
	int windowHeight;
	std::filesystem::path current_path;

private:
	Global();
};

std::unique_ptr<Global> makeGlobal();
