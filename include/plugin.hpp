#pragma once

#include "global.hpp"

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

