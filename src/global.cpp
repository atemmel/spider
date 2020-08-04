#include "global.hpp"

#include <git2.h>
#include <ncurses.h>

#include <cassert>
#include <clocale>


Config Global::config;
magic_t Global::cookie;
std::filesystem::path Global::current_path;
std::stack<PluginPtr> Global::state;

void Global::init() {
	LOG << "Global initialized\n";
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

void Global::cleanup() {
	endwin();
	magic_close(cookie);
	git_libgit2_shutdown();
	LOG << "Global cleaned up\n";
}
