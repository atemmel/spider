#include <ncurses.h>
#include <signal.h>

#include <iostream>

#include "browser.hpp"
#include "global.hpp"

int main(int /*argc*/, char** /*argv*/) {
	Global::init();
	Global::state.push(std::make_unique<Browser>() );

	int c = 0;
	try {
		Global::state.top()->onActivate();
		while (c != 'q' && c != 4) {
			Global::state.top()->draw();
			c = getch();
			Global::state.top()->update(c);
		}
		Global::state.top()->onDeactivate();
	} catch (const std::filesystem::filesystem_error& err) {
		endwin();
		std::cerr << "Filesystem error: " << err.what() << '\n';
	} catch (...) {
		endwin();
		std::cerr << "Unexpected execption caught\n";
	}

	Global::cleanup();

	return EXIT_SUCCESS;
}
