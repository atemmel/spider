#include "prompt.hpp"
#include "utils.hpp"

// External dependencies
#include <ncurses.h>
#include <magic.h>

// This looks good :)
#include <string_view>
#include <filesystem>
#include <iostream>
#include <fstream>
#include <cassert>
#include <vector>
#include <limits>

namespace fs = std::filesystem;

struct FileEntry
{
	bool hasSize() const
	{
		return size != std::numeric_limits<std::uintmax_t>::max();
	}

	std::string name;
	fs::file_status status;
	std::uintmax_t size;
	std::string sizeStr;
};


//TODO: Move to separate header/impl
/**
 *	Implements less-than comparison between two file entries
 */
struct FileEntryComp
{
	bool operator()(const FileEntry &lhs, const FileEntry &rhs)
	{
		if(fs::is_directory(rhs.status) )
		{
			if(fs::is_directory(lhs.status) ) return caseInsensitiveComparison(lhs.name, rhs.name);
			else return false;
		}
		else if(fs::is_directory(lhs.status) ) return true;

		return caseInsensitiveComparison(lhs.name, rhs.name); 
	}
};

constexpr unsigned tick_rate = 1000; //ms

//TODO: Wrap in global object
std::vector<FileEntry> entries;	
fs::path current_path;
int index = 0;
int window_width = 0;
int window_height = 0;

magic_t cookie;

void fillList() 
{
	entries.clear();
	FileEntry entry;

	for(auto &it : fs::directory_iterator(current_path) )
	{
		entry.name = std::move(it.path().string() );
		entry.status = it.status();

		if(fs::is_regular_file(entry.status) || fs::is_symlink(entry.status) ) 
		{
			entry.size = fs::file_size(it);
			entry.sizeStr = bytesToString(entry.size);
		}
		else entry.size = std::numeric_limits<std::uintmax_t>::max();

		entries.push_back(entry);
	}

	std::sort(entries.begin(), entries.end(), FileEntryComp() );
}

void enterDir() 
{
	fs::path path(entries[index].name);

	if(fs::is_directory(path) )
	{
		std::string blanks(window_width, ' ');
		current_path /= path;
		fs::current_path(current_path);
		int oldSize = entries.size() + 1;
		fillList();
		int newSize = entries.size() + 1;

		for(int i = newSize; i < oldSize; i++) mvprintw(i, 0, blanks.c_str() );
		index = 0;
	}
	else 
	{	
		endwin();

		std::string mime = magic_file(cookie, path.c_str() );

		if(mime.find("text") == 0)
		{
			system( ("nvim " + (path).string() ).c_str() );	//TODO: Move into config/similar
		}
		else 
		{
			createProcess([&]()
			{
				system( ("xdg-open " + (path).string() ).c_str() );	//TODO: Move into config/similar
			});
		}

		fillList();

		initscr();
	}
}

void printHeader() 
{
	mvprintw(0, 0, std::string(window_width, ' ').c_str() );
	attron(A_BOLD | COLOR_PAIR(1) );
	mvprintw(0, 0, current_path.string().substr(0, window_width).c_str() );
	attroff(A_BOLD | COLOR_PAIR(1) );
}

void printDirs() 
{
	constexpr int ox = 0, oy = 1;
	int upperLimit = std::abs(static_cast<int>(entries.size() ) - window_height + oy);
	int limit = oy + static_cast<int>(index) - (window_height >> 1);
	auto it = entries.begin();
	std::string blanks(window_width, ' ');
	constexpr std::string_view dirStr = "/  ";
	
	if(static_cast<int>(entries.size() ) < window_height - oy) upperLimit = 0;
	limit = std::clamp(limit, 0, upperLimit);

	it += limit;

	for(int i = 0; it != entries.end(); i++, it++)
	{
		int last_sep = it->name.find_last_of('/');

		attroff(A_REVERSE);
		mvprintw(i + oy, ox, "%s", blanks.c_str() );
		index == i + limit ? attron(A_REVERSE) : attroff(A_REVERSE);
		fs::is_directory(it->status) ? attron(A_BOLD) : attroff(A_BOLD);

		mvprintw(i + oy, ox, " %o %10s %s ", 
					static_cast<int>(it->status.permissions() ) & 00777, 
					it->hasSize() ? it->sizeStr.c_str() : dirStr.data(), 
					it->name.substr(last_sep + 1, window_width - ox).c_str() 
				);
	}

	attroff(A_REVERSE);
}

void findPath()
{
	std::string input;
	int c = '\0';
	std::vector<bool> bits(entries.size(), false);

	while(1)
	{
		c = Prompt::get(input, "Go:");

		if(c == 127 && !input.empty() ) input.pop_back();
		else if(c == 27) break;
		else if(c != '\0') input.push_back(c);

		if(input.empty() ) continue;

		std::fill(bits.begin(), bits.end(), false);

		for(size_t i = 0; i < entries.size(); i++)
		{
			std::string str = entries[i].name;
			str = str.substr(str.find_last_of('/') + 1);

			bits[i] = startsWith(str, input);
		}

		if(auto it = std::find(bits.begin(), bits.end(), true ); it != bits.end() )
		{
			index = it - bits.begin();

			if(std::find(it + 1, bits.end(), true) == bits.end() )
			{
				enterDir();
				return;
			}

			printHeader();
			printDirs();
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

void processInput(int input) 
{

	std::string prompt, blanks(window_width, ' ');
	std::ofstream file;
	int oldSize, newSize;

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
		case KEY_LEFT:	/* Left */
		case 'h':
			current_path = current_path.parent_path();
			fs::current_path(current_path);
			index = 0;
			oldSize = entries.size() + 1;
			fillList();
			newSize = entries.size() + 1;

			for(int i = newSize; i < oldSize; i++) mvprintw(i, 0, blanks.c_str() );
			break;
		case KEY_RIGHT:/* Right */
		case 'l':
			enterDir();
			break;
		case KEY_DOWN:	/* Down */
		case 'j':
			++index;
			if(index >= static_cast<int>(entries.size() ) )  index = 0;
			break;
		case KEY_UP:	/* Up */
		case 'k':
			--index;
			if(index < 0) index = entries.size() - 1;
			break;
		case 'c':
			prompt = Prompt::getString("Name of file:");
			if(fs::exists(prompt.c_str() ) ) return;
			file.open(prompt.c_str() );
			fillList();
			printHeader();
			printDirs();
			break;
		case 'C':
			prompt = Prompt::getString("Name of directory:");
			if(fs::exists(prompt.c_str() ) ) return;
			fs::create_directory(prompt.c_str() );
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
	int c = '\0';
	current_path = fs::current_path();
	fillList();

	setlocale(LC_ALL, "");
	initscr();
	noecho();
	keypad(stdscr, TRUE);
	timeout(tick_rate);
	curs_set(0);
	start_color();	//TODO: Check for return
	init_pair(1, COLOR_YELLOW, COLOR_BLACK);	//TODO: Move into config

	cookie = magic_open(MAGIC_MIME);	//TODO: Check for return
	magic_load(cookie, 0);	//TODO: Check for return

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
		endwin();
	}
	catch(...)
	{
		endwin();
		std::cerr << "Unexpected execption caught\n";
	}

	magic_close(cookie);
}
