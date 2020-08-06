#include "global.hpp"

#include <git2.h>
#include <ncurses.h>

#include <cassert>
#include <clocale>

Config global::config;
magic_t global::cookie;
std::filesystem::path global::currentPath;
std::stack<PluginPtr> global::state;

void global::init() {
	LOG << "Global initialized\n";
	config.load();
	std::setlocale(LC_ALL, "");
	initscr();
	noecho();
	keypad(stdscr, TRUE);
	timeout(TICK);
	curs_set(0);
	start_color();                            // TODO: Check for return
	init_pair(1, COLOR_YELLOW, COLOR_BLACK);  // TODO: Move into config
	cookie = magic_open(MAGIC_MIME);          // TODO: Check for return
	magic_load(global::cookie, nullptr);      // TODO: Check for return
	git_libgit2_init();                       // TODO: Check for return
}

void global::cleanup() {
	endwin();
	magic_close(cookie);
	git_libgit2_shutdown();
	LOG << "Global cleaned up\n";
}

void global::pushState(PluginPtr&& ptr) {
	state.top()->onDeactivate();
	state.push(std::move(ptr));
	state.top()->onActivate();
}

void global::popState() {
	endwin();
	LOG << "Popping state...\n";
	LOG << "State size " << state.size() << '\n';
	initscr();
	state.top()->onDeactivate();
	state.pop();
	if (!state.empty()) {
		state.top()->onActivate();
	}
}
