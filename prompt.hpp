#pragma once

#include <ncurses.h>
    
#include <string>

std::string prompt(const std::string &message)
{
	int x, y;
	char c = 0;
	std::string in;

	getmaxyx(stdscr, y, x);
	echo();
	timeout(-1);

	auto clearp = [x, y, &message]()
	{
		move(y - 1, 0);
		for(int i = 0; i < x; i++)
		{
			addch(' ');
		}
	};

	auto printp = [x, y, &in, &message]()
	{
		mvprintw(y - 1, 0, "%s%s", message.data(), in.c_str() );
	};

	auto exitp = [&clearp, &printp]()
	{
		clearp();
		noecho();
		timeout(300);
	};

	printp();

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
				clearp();
				printp();
				break;
			case 27:
				exitp();
				return "";
			case '\n':
				clearp();
				exitp();
				return in;
		}

		if(std::isprint(c) ) in.push_back(c);
	}

	return "";
}
