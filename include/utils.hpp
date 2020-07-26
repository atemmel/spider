#pragma once

#include <ncurses.h>
#include <sys/types.h>
#include <unistd.h>

#include <algorithm>
#include <cstdlib>
#include <string>

namespace utils {

std::string file(const std::string &str);

std::string dir(const std::string &str);

bool caseInsensitiveComparison(const std::string &lhs, const std::string &rhs);

bool startsWith(const std::string &origin, const std::string &match);

void toUpper(std::string &str);

std::string bytesToString(std::uintmax_t bytes);

template <typename T>
void createProcess(T function) {
	endwin();
	pid_t pid = fork();

	if (pid == 0)  // Child process
	{
		function();
		std::exit(EXIT_SUCCESS);
	} else  // Parent process (Original)
	{
		initscr();
	}
}

template <typename T, typename U>
void createProcess(T child, U parent) {
	endwin();
	pid_t pid = fork();

	if (pid == 0) {  // Child process
		child();
		std::exit(EXIT_SUCCESS);
	} else {  // Parent process (Original)
		parent(pid);
		initscr();
	}
}

}  // namespace utils
