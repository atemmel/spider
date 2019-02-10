#include <ncurses.h>
#include <filesystem>
#include <string>
#include <iostream>

namespace fs = std::filesystem;

fs::path current_path;
int index = 0;
int n_index = 0;

void print_header()
{
	attron(A_BOLD | COLOR_PAIR(1) );
	mvprintw(0, 0, current_path.c_str() );
	attroff(A_BOLD | COLOR_PAIR(1) );
}

void print_dirs()
{
	constexpr int ox = 0, oy = 1;
	n_index = 0;

	for(auto & it : fs::directory_iterator(current_path) )
	{
		std::string path = it.path().string();
		int last_sep = path.find_last_of('/');

		index == n_index ? attron(A_REVERSE) : attroff(A_REVERSE);
		mvprintw(n_index + oy, ox, " %s", path.c_str() + last_sep + 1);

		++n_index;
	}

	attroff(A_REVERSE);
}

void enter_dir()
{
	auto it = fs::directory_iterator(current_path);
	for(int i = 0; i < index; i++) ++it;
		
	index = 0;

	if(fs::is_directory(it->path() ) )
	{
		current_path /= it->path();
		return;
	}
}

void process_input(char input)
{
	switch(input)
	{
		case 68:	/* Left */
		case 'h':
			clear();
			current_path = current_path.parent_path();
			index = 0;
			break;
		case 67:	/* Right */
		case 'l':
			clear();
			enter_dir();
			break;
		case 66:	/* Down */
		case 'j':
			++index;
			if(index >= n_index) index = 0;
			break;
		case 65:	/* Up */
		case 'k':
			--index;
			if(index < 0) index = n_index - 1;
			break;
		default:
			printw("%d", input);
	}
}

int main()
{
	char c = '\0';
	current_path = fs::current_path();
		
	initscr();
	noecho();
	curs_set(0);
	start_color(); //Check for return
	init_pair(1, 4, COLOR_BLACK);

	try
	{
		while(c != 'q')
		{
			print_header();
			print_dirs();
			c = getch();
			process_input(c);
		}
	}
	catch(...)
	{
		std::cerr << "Unexpected execption caught\n";
	}

	endwin();
}
