#include "browser.hpp"
#include "global.hpp"

#include <ncurses.h>
#include <signal.h>
#include <iostream>

std::unique_ptr<Global> globals;

void resizeHandler(int sig) {
	getmaxyx(stdscr, globals->windowHeight, globals->windowWidth);
}

int main(int argc, char** argv)
{
	globals = makeGlobal();
	getmaxyx(stdscr, globals->windowHeight, globals->windowWidth);

	signal(SIGWINCH,  resizeHandler);

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
