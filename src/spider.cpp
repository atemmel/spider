#include "browser.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <iostream>

//int main(int argc, char** argv)
int main()
{
	int c = 0;

	Global::init();
	Browser::init();

	try
	{
		while(c != 'q' && c != 4)
		{
			getmaxyx(stdscr, Global::windowHeight, Global::windowWidth);
			Browser::display();
			c = getch();
			Browser::processInput(c);
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
