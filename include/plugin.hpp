#pragma once

#include "global.hpp"

#ifndef SPIDER_PLUGIN_CREATE
#define SPIDER_PLUGIN_CREATE		spiderPluginCreate
#endif
#ifndef SPIDER_PLUGIN_DESTROY
#define SPIDER_PLUGIN_DESTROY		spiderPluginDestroy
#endif
#ifndef SPIDER_PLUGIN_CREATE_STR
#define SPIDER_PLUGIN_CREATE_STR	"SPIDER_PLUGIN_CREATE"
#endif
#ifndef SPIDER_PLUGIN_DESTROY_STR
#define SPIDER_PLUGIN_DESTROY_STR	"SPIDER_PLUGIN_DESTROY"
#endif

class Plugin
{
public:
	virtual ~Plugin() {};

	virtual void update(int keypress) {};

	virtual void draw() {};

	virtual void onActivate() {};

	virtual void onDeactivate() {};
};
