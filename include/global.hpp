#pragma once

#include "config.hpp"
#include "debug.hpp"

#include <filesystem>
#include <magic.h>
#include <string>
#include <memory>

struct Global
{
	friend std::unique_ptr<Global> makeGlobal();
 	~Global();

	constexpr static unsigned tick = 1000; //ms
	Config config;
	magic_t cookie;
	int windowWidth;
	int windowHeight;
	std::filesystem::path current_path;


private:
	Global();
};

std::unique_ptr<Global> makeGlobal();
