#include "browser.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <signal.h>
#include <iostream>


int main(int  /*argc*/, char**  /*argv*/)
{
	std::unique_ptr<Global> globals;
	globals = makeGlobal();

	auto browser = std::make_unique<Browser>();
	browser->globals = globals.get();

	int c = 0;
	try
	{
		browser->onActivate();
		while(c != 'q' && c != 4)
		{
			refresh();
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
