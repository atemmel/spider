#include "browser.hpp"
#include "loader.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <iostream>

int main(int argc, char** argv)
{
	constexpr std::string_view pluginFlag = "-l";
	auto globals = makeGlobal();
	getmaxyx(stdscr, globals->windowHeight, globals->windowWidth);

	if(argc > 2)
	{
		if(pluginFlag == argv[1]) 
		{
			globals->pluginDir = argv[2];
		}
	}

	auto browser = std::make_unique<Browser>();
	browser->globals = globals.get();

	int c = 0;
	try
	{
		browser->onActivate();
		while(c != 'q' && c != 4)
		{
			getmaxyx(stdscr, globals->windowHeight, globals->windowWidth);
			browser->draw();
			c = getch();
			browser->update(c);
		}
		browser->onDeactivate();
	}
	catch(const std::filesystem::filesystem_error &err)
	{
		endwin();
		std::cerr << "Filesystem error: " << err.what() << '\n';
	}
	catch(...)
	{
		endwin();
		std::cerr << "Unexpected execption caught\n";
	}

	return EXIT_SUCCESS;
}
