#include "modules/browser.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <iostream>

int main()
{
	int c = 0;

	Global::init();
	Browser browser;

	try
	{
		while(c != 'q' && c != 4)
		{
			getmaxyx(stdscr, Global::windowHeight, Global::windowWidth);
			browser.display();
			c = getch();
			browser.update(c);
		}
		Global::destroy();
	}
	catch(...)
	{
		Global::destroy();
		std::cerr << "Unexpected execption caught\n";
	}

	return 0;
}
