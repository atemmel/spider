#pragma once

#include <ncurses.h>

#include <cstdlib>
#include <unistd.h>
#include <sys/types.h>

template<typename T>
void createProcess(T function)
{
	endwin();
	pid_t pid = fork();

	if(pid == 0)	//Child process
	{
		function();
		//system("urxvt");
		std::exit(EXIT_SUCCESS);
	}
	else //Parent process (Original)
	{
		initscr();
	}

}
