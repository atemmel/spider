#pragma once
#include "plugin.hpp"

#include <functional>
#include <memory>
#include <string>
#include <map>

class Loader
{
public:
	Loader(const std::string& path);

	Plugin* operator[](const std::string& name) const;

private:
	using PluginPtr = std::unique_ptr<Plugin, std::function<void(Plugin*)> >;

	void load(const std::string& lib);

	std::string _libpath;
	std::map<std::string, PluginPtr> _plugins;
};
