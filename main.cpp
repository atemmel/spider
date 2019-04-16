#include "prompt.hpp"
#include "utils.hpp"

// External dependencies
#include <ncurses.h>

// This looks good :)
#include <filesystem>
#include <algorithm>
#include <iostream>
#include <fstream>
#include <cassert>
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
			if(fs::is_directory(lhs.type) ) return caseInsensitiveComparison(lhs.name, rhs.name);
			else return false;
		}
		else if(fs::is_directory(lhs.type) ) return true;

		return caseInsensitiveComparison(lhs.name, rhs.name); 
	}
};

constexpr unsigned tick_rate = 300; //ms

//TODO: Wrap in global object
std::vector<FileEntry> entries;	
fs::path current_path;
int index = 0;
int window_width = 0;
int window_height = 0;

void fillList() 
{
	entries.clear();
	FileEntry entry;

	for(auto &it : fs::directory_iterator(current_path) )
	{
		entry.name = std::move(it.path().string() );
		entry.type = it.status();
		entries.push_back(entry);
	}

	std::sort(entries.begin(), entries.end(), FileEntryComp() );
}

void enterDir() 
{
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

void printHeader() 
{
	attron(A_BOLD | COLOR_PAIR(1) );
	mvprintw(0, 0, current_path.string().substr(0, window_width).c_str() );
	attroff(A_BOLD | COLOR_PAIR(1) );
}

void printDirs() 
{
	constexpr int ox = 0, oy = 1;
	const int upperLimit = std::abs(static_cast<int>(entries.size() ) - window_height + oy);
	int limit = oy + static_cast<int>(index) - (window_height >> 1);
	auto it = entries.begin();
	std::string blanks(window_width, ' ');
	
	limit = std::clamp(limit, 0, upperLimit);

	it += limit;

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

void findPath()
{
	std::string input;
	char c = '\0';
	bool consecutive = false;

	while(1)
	{
		c = Prompt::get(input, "Go:");

		if(c == 127 && !input.empty() ) input.pop_back();
		else if(c == 27) break;
		else if(c != '\0') input.push_back(c);

		if(input.empty() ) continue;

		for(size_t i = 0; i < entries.size(); i++)
		{
			std::string str = entries[i].name;
			str = str.substr(str.find_last_of('/') + 1);

			if(startsWith(str, input) ) 
			{
				index = static_cast<int>(i);
				consecutive = !consecutive;
			}
			else if(consecutive) 
			{
				clear();
				enterDir();
				return;
			}
		}
	}

}

void createTerminal()
{
	createProcess([]()
	{
		//TODO: Move into config/similar
		system("urxvt");
	});
}

void processInput(char input) 
{

	std::string fileName;
	std::ofstream file;

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
			if(index >= static_cast<int>(entries.size() ) )  index = 0;
			break;
		case 65:	/* Up */
		case 'k':
			--index;
			if(index < 0) index = entries.size() - 1;
			break;
		case 'c':
			fileName = Prompt::getString("Name of file:");
			if(fs::exists(fileName.c_str() ) ) return;
			file.open(fileName.c_str() );
			fillList();
			printHeader();
			printDirs();
			break;
		case 'f':
			findPath();
			break;
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
