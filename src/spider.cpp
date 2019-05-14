#include "modules/browser.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <iostream>

int main()
{
	int c = 0;

	Browser browser;

	try
	{
		while(c != 'q' && c != 4)
		{
			getmaxyx(stdscr, global.windowHeight, global.windowWidth);
			browser.display();
			c = getch();
			browser.update(c);
		}
	}
	catch(...)
	{
		std::cerr << "Unexpected execption caught\n";
	}

	return 0;
}
