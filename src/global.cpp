#include "global.hpp"

#include <git2.h>
#include <ncurses.h>

#include <cassert>
#include <clocale>

std::unique_ptr<Global> globals;

Global::Global() {
	LOG << "Global created\n";
	std::setlocale(LC_ALL, "");
	initscr();
	noecho();
	keypad(stdscr, TRUE);
	timeout(TICK);
	curs_set(0);
	start_color();                            // TODO: Check for return
	init_pair(1, COLOR_YELLOW, COLOR_BLACK);  // TODO: Move into config
	cookie = magic_open(MAGIC_MIME);          // TODO: Check for return
	magic_load(Global::cookie, nullptr);      // TODO: Check for return
	git_libgit2_init();                       // TODO: Check for return
}

Global::~Global() {
	endwin();
	magic_close(cookie);
	git_libgit2_shutdown();
	LOG << "Global destroyed\n";
}

void makeGlobal() {
	static bool created = false;
	assert(!created);  // Assert that only one global is ever instantiated
	globals = std::unique_ptr<Global>(new Global());
}
