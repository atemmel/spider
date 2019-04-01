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
			else return false;
		}
		else if(fs::is_directory(lhs.type) ) return true;

		return lhs.name < rhs.name;
	}

private:
	bool caseInsensitive(const std::string &lhs, const std::string &rhs)
	{
		auto lit = lhs.begin(), rit = rhs.begin();

		while(lit != lhs.end() && rit != rhs.end() )
		{
			if(toupper(*lit) < toupper(*rit) ) return true;
			++lit, ++rit;
		}

		return lit == lhs.end();
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
	const int upperLimit = std::abs(n_index - window_height + oy);
	int limit = oy + index - (window_height >> 1);
	auto it = entries.begin();
	std::string blanks(window_width, ' ');
	
	limit = std::clamp(limit, 0, upperLimit);

	for(int i = 0; i < limit; i++) ++it;

	for(int i = 0; it != entries.end(); i++, it++)
	{
		int last_sep = it->name.find_last_of('/');

		index == i + limit ? attron(A_REVERSE) : attroff(A_REVERSE);
		mvprintw(i + oy, ox, "%s", blanks.c_str() );
		mvprintw(i + oy, ox, " %s", it->name.substr(last_sep + 1, window_width - ox).c_str() );
		
	}
	

	attroff(A_REVERSE);
}

void enter_dir()
{
	fs::path path(entryIterator->name);

	if(fs::is_directory(path) )
	{
		current_path /= path;
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
