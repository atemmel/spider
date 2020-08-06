#include <ncurses.h>
#include <signal.h>

#include <iostream>

#include "browser.hpp"
#include "global.hpp"

int main(int argc, char** argv) {
	(void)argc;
	(void)argv;

	global::init();
	global::state.push(std::make_unique<Browser>());

	int c = 0;
	try {
		global::state.top()->onActivate();
		while (!global::state.empty()) {
			global::state.top()->draw();
			c = getch();
			global::state.top()->update(c);
		}
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
