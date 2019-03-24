// External dependencies
#include <ncurses.h>

// This looks good :)
#include <filesystem>
#include <algorithm>
#include <iostream>
#include <string>
#include <list>

namespace fs = std::filesystem;

struct FileEntry
{
	std::string name;
	fs::file_status type;
};

using EntryIterator = std::list<FileEntry>::iterator;

/**
 *	Implements less-than comparison between two file entries
 */
struct FileEntryComp
{
	bool operator()(const FileEntry &lhs, const FileEntry &rhs)
	{
		if(fs::is_directory(rhs.type) )
		{
			if(fs::is_directory(lhs.type) ) return lhs.name < rhs.name;
			else return true;
		}
		else if(fs::is_directory(lhs.type) ) return false;

		return lhs.name < rhs.name;
	}
};

constexpr unsigned tick_rate = 300; //ms

std::list<FileEntry> entries;
fs::path current_path;
EntryIterator entryIterator;
int index = 0;
int n_index = 0;
int window_width = 0;
int window_height = 0;

void fill_list()
{
	entries.clear();
	FileEntry entry;

	n_index = 0;

	for(auto &it : fs::directory_iterator(current_path) )
	{
		entry.name = std::move(it.path().string() );
		entry.type = it.status();
		entries.push_back(entry);
		++n_index;
	}

	entries.sort(FileEntryComp{} );
	entryIterator = entries.begin();
}

void print_header()
{
	attron(A_BOLD | COLOR_PAIR(1) );
	mvprintw(0, 0, current_path.string().substr(0, window_width).c_str() );
	attroff(A_BOLD | COLOR_PAIR(1) );
}

void print_dirs()
{
	constexpr int ox = 0, oy = 1;
	std::string path;
	n_index = 0;

	for(auto &entry : entries)
	{
		int last_sep = entry.name.find_last_of('/');

		index == n_index ? attron(A_REVERSE) : attroff(A_REVERSE);
		mvprintw(n_index + oy, ox, " %s", entry.name.substr(last_sep + 1, window_width - ox).c_str() );

		++n_index;
	}

	attroff(A_REVERSE);
}

void enter_dir()
{
	fs::path path(entryIterator->name);

	if(fs::is_directory(path) )
	{
		current_path /= path;
		std::cerr << current_path.c_str() << '\n';
		fill_list();
		index = 0;
	}
}

void process_input(char input)
{
	switch(input)
	{
		case -1: 
			break;
		case 68:	/* Left */
		case 'h':
			clear();
			current_path = current_path.parent_path();
			index = 0;
			fill_list();
			break;
		case 67:	/* Right */
		case 'l':
			clear();
			enter_dir();
			break;
		case 66:	/* Down */
		case 'j':
			++index, ++entryIterator;
			if(index >= n_index) 
			{
				index = 0;
				entryIterator = entries.begin();
			}
			break;
		case 65:	/* Up */
		case 'k':
			--index, --entryIterator;
			if(index < 0) 
			{
				index = n_index - 1;
				entryIterator = entries.end(), --entryIterator;
			}
			break;
	}
}

int main(int argc, char** argv)
{
	char c = '\0';
	current_path = fs::current_path();
	fill_list();

	initscr();
	noecho();
	timeout(tick_rate);
	curs_set(0);
	start_color(); //Check for return
	init_pair(1, 4, COLOR_BLACK);

	try
	{
		while(c != 'q')
		{
			getmaxyx(stdscr, window_height, window_width);
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
