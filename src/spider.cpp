#include <ncurses.h>
#include <signal.h>

#include <iostream>

#include "browser.hpp"
#include "global.hpp"

int main(int /*argc*/, char** /*argv*/) {
	makeGlobal();

	PluginPtr plugin = std::make_unique<Browser>();

	int c = 0;
	try {
		plugin->onActivate();
		while (c != 'q' && c != 4) {
			getmaxyx(stdscr, globals->windowHeight, globals->windowWidth);
			plugin->draw();
			c = getch();
			plugin->update(c);
		}
		plugin->onDeactivate();
	} catch (const std::filesystem::filesystem_error& err) {
		endwin();
		std::cerr << "Filesystem error: " << err.what() << '\n';
	} catch (...) {
		endwin();
		std::cerr << "Unexpected execption caught\n";
	}

	return EXIT_SUCCESS;
}
