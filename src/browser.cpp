#include "browser.hpp"

namespace fs = std::filesystem;

void Browser::fillList() 
{
	int oldSize = entries.size() + 1;
	entries.clear();
	int newSize = entries.size() + 1;
	FileEntry entry;
	std::string blanks(globals->windowWidth, ' ');

	for(auto &it : fs::directory_iterator(current_path) )
	{
		entry.name = std::move(it.path().string() );
		entry.status = it.status();

		if(fs::is_regular_file(entry.name) && !fs::is_symlink(entry.name) ) 
		{
			entry.size = fs::file_size(it);
			entry.sizeStr = Utils::bytesToString(entry.size);
		}
		else entry.size = std::numeric_limits<std::uintmax_t>::max();

		entries.push_back(entry);
	}

	std::sort(entries.begin(), entries.end(), FileEntryComp() );
	for(int i = newSize; i < oldSize; i++) mvprintw(i, 0, blanks.c_str() );
}

void Browser::enterDir() 
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

		std::string mime = magic_file(globals->cookie, path.c_str() );

		if(mime.find("text") == 0 || mime.find("inode/x-empty") == 0)
		{
			system( (globals->config.editor + " \"" + (path).string() + '\"').c_str() );
			fillList();
		}
		else if(mime.find("application/x-pie-executable") == 0)
		{
			system(path.c_str() );
		}
		else 
		{
			Utils::createProcess([&]()
			{
				system( (globals->config.opener + ' ' + (path).string() ).c_str() );
			});
		}

		initscr();
	}
}

void Browser::printHeader() 
{
	mvprintw(0, 0, std::string(globals->windowWidth, ' ').c_str() );
	attron(A_BOLD | COLOR_PAIR(1) );
	mvprintw(0, 0, current_path.string().substr(0, globals->windowWidth).c_str() );
	attroff(A_BOLD | COLOR_PAIR(1) );
}

void Browser::printDirs() 
{
	constexpr int ox = 0, oy = 1;
	int upperLimit = std::abs(static_cast<int>(entries.size() ) - globals->windowHeight + oy);
	int limit = oy + static_cast<int>(index) - (globals->windowHeight >> 1);
	auto it = entries.begin();
	std::string blanks(globals->windowWidth, ' ');
	constexpr std::string_view dirStr = "/  ";
	constexpr std::string_view lnStr  = "~> ";
	
	if(static_cast<int>(entries.size() ) < globals->windowHeight - oy) upperLimit = 0;
	limit = std::clamp(limit, 0, upperLimit);

	it += limit;

	for(int i = 0; it != entries.end(); i++, it++)
	{
		int last_sep = it->name.find_last_of('/');

		attroff(A_REVERSE);
		mvprintw(i + oy, ox, "%s", blanks.c_str() );
		index == i + limit ? attron(A_REVERSE) : attroff(A_REVERSE);
		fs::is_directory(it->name) ? attron(A_BOLD) : attroff(A_BOLD);

		mvprintw(i + oy, ox, " %o %10s %s%s ", 
					static_cast<int>(it->status.permissions() ) & 00777, 
					fs::is_symlink(it->name) ? lnStr.data() :
						it->hasSize() ? it->sizeStr.c_str() :
							dirStr.data(),
					marks.find(it->name) != marks.end() ? " " : "",
					it->name.substr(last_sep + 1, globals->windowWidth - ox).c_str() 
				);
	}

	attroff(A_REVERSE);
}

void Browser::findPath()
{
	std::string input;
	int c = '\0';
	std::vector<bool> bits(entries.size(), false);

	while(1)
	{
		c = Prompt::get(input, "Go:");

		if(c == KEY_BACKSPACE && !input.empty() ) input.pop_back();
		else if(c == 27) break;
		else if(c != '\0') input.push_back(c);

		if(input.empty() ) continue;

		std::fill(bits.begin(), bits.end(), false);

		for(size_t i = 0; i < entries.size(); i++)
		{
			std::string str = entries[i].file();

			bits[i] = Utils::startsWith(str, input);
		}

		if(auto it = std::find(bits.begin(), bits.end(), true); it != bits.end() )
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

void Browser::createTerminal()
{
	Utils::createProcess([&]()
	{
		system(globals->config.terminal.data() );
	});
}

void Browser::deleteEntry()
{
	if(!marks.empty() )
	{
		int prompt = Prompt::get("", "Delete " + std::to_string(marks.size() ) + " objects?(Y/N):");

		if(prompt == 'y' || prompt == 'Y')
		{
			for(auto &mark : marks)
			{
				if(fs::is_directory(mark) ) fs::remove_all(mark);
				else fs::remove(mark);
			}

			marks.clear();
		}
		return;
	}

	int prompt = Prompt::get("", "Delete " + entries[index].file().string() +  "?(Y/N):");

	if(prompt != 'y' && prompt != 'Y') return;

	if(fs::is_directory(entries[index].name) )
	{
		fs::remove_all(entries[index].name);
	}
	else
	{
		fs::remove(entries[index].name);
	}
}

void Browser::onActivate()
{
	current_path = fs::current_path();
	fillList();
}

void Browser::draw()
{
	printHeader();
	printDirs();
}

//TODO: Load bindings from file/similar
/*
 *	h: Left (../)
 *	l: Right (go down/open)
 *	j: Down
 *	k: Up
 *	c: Create file
 *	C: Create directoru
 *	D: Delete item(s)
 *	f: Fast travel
 *	 : Mark item
 *	R: Rename item
 *	G: Enter git mode (experimental)
 *	m: Remove all marks
 *	a: Read MIME data
 *	p: Paste marked files
 *	v: Move marked files
 */

void Browser::update(int input) 
{
	std::string prompt;
	std::ofstream file;
	std::error_code ec;
	int c = 0;

	switch(input)
	{
		case -1: break;
		case's':
			endwin();
			system("bash");
			initscr();
			fillList();
			printDirs();
			break;
		case 'S':
			createTerminal();
			break;
		case KEY_LEFT:	/* Left */
		case 'h':
			current_path = current_path.parent_path();
			fs::current_path(current_path);
			index = 0;
			fillList();
			break;
		case KEY_RIGHT:	/* Right */
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
			if(prompt.empty() || fs::exists(prompt.c_str() ) ) return;
			file.open(prompt.c_str() );
			fillList();
			printHeader();
			printDirs();
			break;
		case 'C':
			prompt = Prompt::getString("Name of directory:");
			if(prompt.empty() || fs::exists(prompt.c_str() ) ) return;
			fs::create_directory(prompt.c_str() );
			fillList();
			printHeader();
			printDirs();
			break;
		case 'D':
			deleteEntry();
			index = 0;
			fillList();
			printHeader();
			printDirs();
			break;
		case 'f':
			findPath();
			break;
		case ' ':
			if(auto mark = marks.find(entries[index].name); mark != marks.end() )
			{
				marks.erase(mark);
			}
			else marks.insert(entries[index].name);
			if(index < static_cast<int>(entries.size() ) - 1) ++index;
			printDirs();
			break;
		case 'R':
			prompt = Prompt::getString("New name:");
			if(prompt.empty() ) return;
			if(fs::exists(prompt.c_str() ) && prompt.find("..") != 0 && prompt != ".") 
			{
				c = Prompt::get("", "Warning: " + prompt + " already exists. Overwrite?(Y/N):");
				if(c != 'Y' && c != 'y') return;
			}
			fs::rename(entries[index].name, prompt, ec);
			fillList();
			printDirs();
			break;
		case 'G':
			clear();
			Git::activate(current_path.c_str() );
			break;
		case 'm':
			marks.clear();
			break;
		case 'a':
			prompt = magic_file(globals->cookie, entries[index].name.c_str() );
			c = Prompt::get(prompt, "MIME type: ");
			break;
		case 'p':
			for(auto &mark : marks)
			{
				fs::copy(mark, 
						current_path / Utils::file(mark),
						fs::copy_options::recursive, 
						ec);
			}
			marks.clear();
			fillList();
			printDirs();
			break;
		case 'v':
			for(auto &mark : marks)
			{
				fs::rename(mark,
						current_path / Utils::file(mark),
						ec);
			}
			marks.clear();
			fillList();
			printDirs();
			break;
		case 'y':
			system(("echo " + current_path.string() + " | xclip -selection clipboard").c_str() );
			break;
	}

	if(ec)
	{
		Prompt::get(ec.message(), "Operation failed: ");
	}
}
