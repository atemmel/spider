#pragma once
#include <map>
#include <string>

#include "bind.hpp"

struct Config {
	void load();

	std::string shell;
	std::string editor;
	std::string terminal;
	std::string opener;
	std::string home;

	std::map<int, Bind> bindings;
};
