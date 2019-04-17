#pragma once

#include <ncurses.h>
    
#include <string>

class Prompt
{
public:
	static std::string getString(const std::string &message);

	static char get(const std::string &value, const std::string &message);

private:
	Prompt() = delete;
	Prompt(const Prompt &instance) = delete;
	Prompt(Prompt &&instance) = delete;
	Prompt operator=(const Prompt &rhs) = delete;
	Prompt operator=(Prompt &&rhs) = delete;

	static void clear(int x, int y);

	static void print(int y, const char* value, const char* message);

	static void exit(int x, int y);
};
