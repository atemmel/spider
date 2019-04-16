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
		std::exit(EXIT_SUCCESS);
	}
	else //Parent process (Original)
	{
		initscr();
	}

}

bool caseInsensitiveComparison(const std::string &lhs, const std::string &rhs)
{
	auto lit = lhs.begin(), rit = rhs.begin();

	while(lit != lhs.end() && rit != rhs.end() )
	{
		char a = toupper(*lit), b = toupper(*rit);

		if(a < b) return true;
		else if(a > b) return false;

		++lit;
		++rit;
	}

	return lit == lhs.end() && rit != rhs.end();
}
