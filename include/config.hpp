#pragma once
#include <string>
#include <map>

#include "bind.hpp"

struct Config
{
	Config();

	std::string editor;
	std::string terminal;
	std::string opener;
	std::string home;

	std::map<int, Bind> bindings;
};
