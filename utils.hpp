#pragma once

#include <ncurses.h>

#include <sys/types.h>
#include <algorithm>
#include <unistd.h>
#include <cstdlib>
#include <string>

bool caseInsensitiveComparison(const std::string &lhs, const std::string &rhs);

bool startsWith(const std::string &origin, const std::string &match);

void toUpper(std::string &str);

template<typename T>
void createProcess(T function)
{
	endwin();
	pid_t pid = fork();

	if(pid == 0)	//Child process
	{
		function();
		std::exit(EXIT_SUCCESS);
	}
	else //Parent process (Original)
	{
		initscr();
	}

}
