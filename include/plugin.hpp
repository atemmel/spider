#pragma once

#include "global.hpp"

class Plugin;

#define SPIDER_PLUGIN_CREATE		spiderPluginCreate
#define SPIDER_PLUGIN_DESTROY		spiderPluginDestroy
#define SPIDER_PLUGIN_CREATE_STR	"spiderPluginCreate"
#define SPIDER_PLUGIN_DESTROY_STR	"spiderPluginDestroy"

#define SPIDER_PLUGIN_EXPORT(T) \
		extern "C" T* SPIDER_PLUGIN_CREATE() \
		{ \
			static_assert(std::is_base_of<Plugin, T>::value, "Exported class must inherit from Plugin interface"); \
			static_assert(std::is_default_constructible<T>::value, "Exported class must be default constructible"); \
			return new T(); \
		} \
		\
		extern "C" void SPIDER_PLUGIN_DESTROY(T* ptr) \
		{ \
			delete ptr; \
		}


class Plugin
{
public:
	virtual ~Plugin() {};

	virtual void update(int keypress) {};

	virtual void draw() {};

	virtual void onActivate() {};

	virtual void onDeactivate() {};

	Global* globals;
};

