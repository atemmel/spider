#include "loader.hpp"

#include <filesystem>
#include <iostream>
#include <dlfcn.h>

Loader::Loader(const std::string& path)
{
	for(auto&file : std::filesystem::directory_iterator(path) )
	{
		if(file.path().extension() == ".so")
		{
			load(file.path() );
		}
	}

	for(auto &plug : _plugins)
	{
		std::cerr << "Plugin " << plug.first << " loaded\n";
	}
}

void Loader::load(const std::string& lib)	//TODO: Better error handling, e.g throwing an exception or similiar
{
	auto handle = dlopen(lib.c_str(), RTLD_LAZY);

	if(!handle) 
	{
		std::cerr << "Could not load lib: " << lib << '\n';
		std::cerr << "Error: " << dlerror() << '\n';
		return;
	}

	auto create = reinterpret_cast<Plugin*(*)()>(dlsym(handle, SPIDER_PLUGIN_CREATE_STR) );

	if(!create) 
	{
		std::cerr << "Lib " << lib << " does not provide a valid constructor: " << SPIDER_PLUGIN_CREATE_STR << '\n';
		std::cerr << "Error: " << dlerror() << '\n';
		return;
	}

	auto destroy = reinterpret_cast<void(*)(Plugin*)>(dlsym(handle, SPIDER_PLUGIN_DESTROY_STR) );

	if(!destroy) 
	{
		std::cerr << "Lib " << lib << " does not provide a valid destructor: " << SPIDER_PLUGIN_CREATE_STR << '\n';
		std::cerr << "Error: " << dlerror() << '\n';
		return;
	}

	/*
	auto deleter = [destroy](Plugin* ptr)
	{
		destroy(ptr);
	};
	*/

	//_plugins.insert(std::make_pair(lib, std::make_unique(create(), deleter) ) );
	
	_plugins.insert(std::make_pair(lib, PluginPtr(create(), destroy) ) );
}

Plugin* Loader::operator[](const std::string& name) const
{
	if(auto it = _plugins.find(name); it != _plugins.end() )
	{
		return it->second.get();
	}

	else return nullptr;
}
