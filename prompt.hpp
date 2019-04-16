#pragma once

#include <ncurses.h>
    
#include <string>

void clearPrompt(int x, int y)
{
	move(y - 1, 0);
	for(int i = 0; i < x; i++)
	{
		addch(' ');
	}
}

void printPrompt(int y, const char* value, const char* message)
{
	mvprintw(y - 1, 0, "%s%s", message, value);
}

void exitPrompt(int x, int y)
{
	clearPrompt(x, y);
	noecho();
	timeout(300);
}

std::string prompt(const std::string &message)
{
	int x, y;
	char c = 0;
	std::string in;

	getmaxyx(stdscr, y, x);
	echo();
	timeout(-1);

	printPrompt(y, in.c_str(), message.c_str() );

	while(1)
	{
		c = getch();

		switch(c)
		{
			case '\b':
			case '\t':
				continue;
			case 127:
				if(!in.empty() ) in.pop_back();
				clearPrompt(x, y);
				printPrompt(y, in.c_str(), message.c_str() );
				break;
			case 27:
				exitPrompt(x, y);
				return "";
			case '\n':
				clearPrompt(x, y);
				exitPrompt(x, y);
				return in;
		}

		if(std::isprint(c) ) in.push_back(c);
	}

	return "";
}

char continuousPrompt(const std::string &value, const std::string &message)
{
	int x, y;
	char c = 0;
	std::string in;

	getmaxyx(stdscr, y, x);
	echo();
	timeout(-1);

	printPrompt(y, value.c_str(), message.c_str() );

	c = getch();

	exitPrompt(x, y);

	return isprint(c) || c == 27 ? c : '\0';
}

