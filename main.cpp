#include "prompt.hpp"
#include "utils.hpp"

// External dependencies
#include <ncurses.h>

// This looks good :)
#include <filesystem>
#include <algorithm>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

struct FileEntry
{
	std::string name;
	fs::file_status type;
};

//TODO: Move to separate header/impl
/**
 *	Implements less-than comparison between two file entries
 */
struct FileEntryComp
{
	bool operator()(const FileEntry &lhs, const FileEntry &rhs)
	{
		if(fs::is_directory(rhs.type) )
		{
			if(fs::is_directory(lhs.type) ) return caseInsensitive(lhs.name, rhs.name);
			else return false;
		}
		else if(fs::is_directory(lhs.type) ) return true;

		return caseInsensitive(lhs.name, rhs.name); 
	}

private:
	bool caseInsensitive(const std::string &lhs, const std::string &rhs)
	{
		auto lit = lhs.begin(), rit = rhs.begin();

		while(lit != lhs.end() && rit != rhs.end() )
		{
			char a = toupper(*lit), b = toupper(*rit);

			if(a < b) return true;
			else if(a > b) return false;

			++lit;
			++rit;
		}

		return lit == lhs.end() && rit != rhs.end();
	}
};

constexpr unsigned tick_rate = 300; //ms

//TODO: Wrap in global object
std::vector<FileEntry> entries;	
fs::path current_path;
int index = 0;
int n_index = 0;
int window_width = 0;
int window_height = 0;

//TODO: Implement function
void findPath()
{
	std::string str;
	char c = '\0';

	while(c != 27)
	{
		c = continuousPrompt(str, "Go:");

		if(c != '\0') str.push_back(c);

		//if(fileLike(str) open(str);
	}

}

void fillList() 
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

	//entries.sort(FileEntryComp{} );
	std::sort(entries.begin(), entries.end(), FileEntryComp() );
	//entryIterator = entries.begin();
}

void printHeader() 
{
	attron(A_BOLD | COLOR_PAIR(1) );
	mvprintw(0, 0, current_path.string().substr(0, window_width).c_str() );
	attroff(A_BOLD | COLOR_PAIR(1) );
}

void printDirs() 
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

		attroff(A_REVERSE);
		mvprintw(i + oy, ox, "%s", blanks.c_str() );
		index == i + limit ? attron(A_REVERSE) : attroff(A_REVERSE);
		fs::is_directory(it->type) ? attron(A_BOLD) : attroff(A_BOLD);
		mvprintw(i + oy, ox, " %s ", it->name.substr(last_sep + 1, window_width - ox).c_str() );
		
	}

	attroff(A_REVERSE);
}

void enterDir() 
{
	//fs::path path(entryIterator->name);
	fs::path path(entries[index].name);

	if(fs::is_directory(path) )
	{
		current_path /= path;
		fs::current_path(current_path);
		fillList();
		index = 0;
	}
	else 
	{	
		endwin();
		//TODO: Move into config/similar
		system( ("nvim " + (path).string() ).c_str() );
		initscr();
	}
}

void createTerminal()
{
	createProcess([]()
	{
		system("urxvt");
	});
}

void processInput(char input) 
{
	switch(input)
	{
		case -1: break;
		case's':
			endwin();
			system("bash");
			initscr();
			break;
		case 'S':
			createTerminal();
			break;
		case 68:	/* Left */
		case 'h':
			clear();
			current_path = current_path.parent_path();
			fs::current_path(current_path);
			index = 0;
			fillList();
			break;
		case 67:	/* Right */
		case 'l':
			clear();
			enterDir();
			break;
		case 66:	/* Down */
		case 'j':
			++index;
			if(index >= n_index)  index = 0;
			break;
		case 65:	/* Up */
		case 'k':
			--index;
			if(index < 0) index = n_index - 1;
			break;
		case 'c':
			auto fileName = prompt("Name of file:");
			if(fs::exists(fileName.c_str() ) ) return;
			std::ofstream file(fileName.c_str() );
			fillList();
			printHeader();
			printDirs();
			break;
		//case 'f':
			//findPath();
			//break;
	}
}

//int main(int argc, char** argv)
int main()
{
	char c = '\0';
	current_path = fs::current_path();
	fillList();

	setlocale(LC_ALL, "");
	initscr();
	noecho();
	timeout(tick_rate);
	curs_set(0);
	start_color();	//TODO: Check for return
	init_pair(1, COLOR_YELLOW, COLOR_BLACK);	//TODO: Move into config

	try
	{
		while(c != 'q')
		{
			getmaxyx(stdscr, window_height, window_width);
			printHeader();
			printDirs();
			c = getch();
			processInput(c);
		}
	}
	catch(...)
	{
		std::cerr << "Unexpected execption caught\n";
	}

	endwin();
}
