#include <ncurses.h>
#include <signal.h>

#include <iostream>

#include "browser.hpp"
#include "global.hpp"

int main(int /*argc*/, char** /*argv*/) {
	global::init();
	global::state.push(std::make_unique<Browser>());

	int c = 0;
	try {
		global::state.top()->onActivate();
		while (c != 'q' && c != 4) {
			global::state.top()->draw();
			c = getch();
			global::state.top()->update(c);
		}
		global::state.top()->onDeactivate();
	} catch (const std::filesystem::filesystem_error& err) {
		endwin();
		std::cerr << "Filesystem error: " << err.what() << '\n';
	} catch (...) {
		endwin();
		std::cerr << "Unexpected execption caught\n";
	}

	global::cleanup();

	return EXIT_SUCCESS;
}
