#include "prompt.hpp"

void Prompt::clear(int x, int y)
{
	move(y - 1, 0);
	for(int i = 0; i < x; i++)
	{
		addch(' ');
	}
}

void Prompt::print(int y, const char* value, const char* message)
{
	mvprintw(y - 1, 0, "%s%s", message, value);
}

void Prompt::exit(int x, int y)
{
	clear(x, y);
	noecho();
	timeout(300);
}

std::string Prompt::getString(const std::string &message)
{
	int x, y;
	char c = 0;
	std::string in;

	getmaxyx(stdscr, y, x);
	echo();
	timeout(-1);

	print(y, in.c_str(), message.c_str() );

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
				clear(x, y);
				print(y, in.c_str(), message.c_str() );
				break;
			case 27:
				exit(x, y);
				return "";
			case '\n':
				clear(x, y);
				exit(x, y);
				return in;
		}

		if(std::isprint(c) ) in.push_back(c);
	}

	return "";
}

char Prompt::get(const std::string &value, const std::string &message)
{
	int x, y;
	char c = 0;
	std::string in;

	getmaxyx(stdscr, y, x);
	echo();
	timeout(-1);

	print(y, value.c_str(), message.c_str() );

	c = getch();

	exit(x, y);

	return isprint(c) || c == 27 || c == ' ' || c == 127 ? c : '\0';
}
