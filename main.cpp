#include <ncurses.h>
#include <filesystem>

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
		index == n_index ? attron(A_REVERSE) : attroff(A_REVERSE);
		mvprintw(n_index + oy, ox, " %s", fs::relative(it.path() ).c_str() );
		++n_index;
	}

	attroff(A_REVERSE);
}

void enter_dir()
{
	auto it = fs::directory_iterator(current_path);
	for(int i = 0; i < index; i++) ++it;
	current_path /= it->path();
}

void process_input(char input)
{
	switch(input)
	{
		case 68:	/* Left */
		case 'h':
			clear();
			printw("LEFT\n");
			current_path = current_path.parent_path();
			break;
		case 67:	/* Right */
		case 'l':
			clear();
			printw("RIGHT\n");
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

	while(c != 'q')
	{
		print_header();
		print_dirs();
		c = getch();
		process_input(c);
	}


	endwin();
}
