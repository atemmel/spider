#include "prompt.hpp"
#include "global.hpp"

static void clear(int x, int y)
{
	move(y - 1, 0);
	for(int i = 0; i < x; i++)
	{
		addch(' ');
	}
}

static void print(int y, const char* value, const char* message)
{
	mvprintw(y - 1, 0, "%s%s", message, value);
}

static void exit(int x, int y)
{
	clear(x, y);
	noecho();
	timeout(Global::TICK);
}

std::string prompt::getString(const std::string &message)
{
	int x, y, c = 0;
	std::string in = "";

	getmaxyx(stdscr, y, x);
	timeout(-1);

	clear(x, y);
	print(y, in.c_str(), message.c_str() );

	while(true)
	{
		c = getch();

		switch(c)
		{
			case '\t':
				continue;
			case KEY_BACKSPACE:
				if(!in.empty() ) { in.pop_back();
}
				break;
			case 27:	//ESC
				exit(x, y);
				return "";
			case '\n':
				exit(x, y);
				return in;
			default:
				in.push_back(c);
		}

		clear(x, y);
		print(y, in.c_str(), message.c_str() );
	}

	return "";	//Only here so that all paths return a value
}

int prompt::get(const std::string &value, const std::string &message)
{
	int x, y, c = 0;
	std::string in;

	getmaxyx(stdscr, y, x);
	echo();
	timeout(-1);

	print(y, value.c_str(), message.c_str() );

	c = getch();

	exit(x, y);

	return isprint(c) || c == 27 || c == ' ' || c > 127 ? c : '\0';
}
