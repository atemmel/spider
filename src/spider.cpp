#include "loader.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <iostream>

int main(int argc, char** argv)
{
	constexpr std::string_view pluginFlag = "-l";
	std::string pluginDir = "spider.d";

	if(argc > 2)
	{
		if(pluginFlag == argv[1]) 
		{
			pluginDir = argv[2];
		}
	}

	Loader loader(pluginDir);
	auto browser = loader["browser.so"];

	if(!browser)
	{
		std::cerr << "Plugin: \"browser.so\" not loaded\n";
		return EXIT_FAILURE;
	}

	auto globals = makeGlobal();
	browser->globals = globals.get();

	int c = 0;
	try
	{
		while(c != 'q' && c != 4)
		{
			getmaxyx(stdscr, globals->windowHeight, globals->windowWidth);
			browser->draw();
			c = getch();
			browser->update(c);
		}
	}
	catch(...)
	{
		std::cerr << "Unexpected execption caught\n";
	}

	return EXIT_SUCCESS;
}
