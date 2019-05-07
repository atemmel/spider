#include "global.hpp"

#include <ncurses.h>
#include <git2.h>

#include <clocale>

namespace Global
{

void init()
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

void destroy()
{
	endwin();
	magic_close(cookie);
	git_libgit2_shutdown();
}

magic_t cookie;

}
