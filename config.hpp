#pragma once
#include <string>

struct Config
{
	Config();

	std::string editor;
	std::string terminal;
	std::string opener;
	constexpr static bool forkEditor = false;
};
