#pragma once
#include <string>

struct Config
{
	const std::string editor = "nvim";
	const std::string terminal = "urxvt";
	const std::string opener = "xdg-open";
	constexpr static bool forkEditor = false;
};
