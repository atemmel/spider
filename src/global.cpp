#include "global.hpp"

#include <ncurses.h>
#include <cassert>
#include <git2.h>

#include <clocale>

Global::Global()
{
	std::setlocale(LC_ALL, "");
	initscr();
	noecho();
	keypad(stdscr, TRUE);
	timeout(Global::tick);
	curs_set(0);
	start_color();	//TODO: Check for return
	init_pair(1, COLOR_YELLOW, COLOR_BLACK);	//TODO: Move into config
	Global::cookie = magic_open(MAGIC_MIME);	//TODO: Check for return
	magic_load(Global::cookie, 0);	//TODO: Check for return
	git_libgit2_init();	//TODO: Check for return
}

Global::~Global()
{
	endwin();
	magic_close(cookie);
	git_libgit2_shutdown();
}

std::unique_ptr<Global> makeGlobal()
{
	static bool created = 0;
	assert(!created);	//Assert that only one global is ever instantiated
	return std::unique_ptr<Global>(new Global() );
}
