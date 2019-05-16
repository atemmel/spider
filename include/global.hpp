#pragma once

#include "config.hpp"

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
	std::string pluginDir;

private:
	Global();
};

std::unique_ptr<Global> makeGlobal();
