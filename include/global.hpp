#pragma once

#include <magic.h>

#include <filesystem>
#include <memory>
#include <stack>
#include <string>

#include "config.hpp"
#include "debug.hpp"
#include "plugin.hpp"

namespace global {
	void init();
	void cleanup();
	void pushState(PluginPtr&& ptr);
	void popState();

constexpr static unsigned TICK = 1000;  // ms
extern Config config;
extern magic_t cookie;
extern std::filesystem::path currentPath;
extern std::stack<PluginPtr> state;
};  // namespace Global
