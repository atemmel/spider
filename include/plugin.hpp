#pragma once

#include <memory>

class Plugin {
public:
	virtual ~Plugin(){};

	virtual void update(int keypress) = 0;

	virtual void draw() = 0;

	virtual void onActivate() = 0;

	virtual void onDeactivate() = 0;
};

using PluginPtr = std::unique_ptr<Plugin>;
