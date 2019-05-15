#pragma once

#include "config.hpp"

#include <magic.h>
#include <memory>

struct Global
{
	Global();
 	~Global();

	constexpr static unsigned tick = 1000; //ms
	Config config;
	magic_t cookie;
	int windowWidth;
	int windowHeight;
};

std::unique_ptr<Global> makeGlobal();
