#include "browser.hpp"

#include <sys/wait.h>

#include <regex>

#include "git.hpp"

namespace fs = std::filesystem;

void Browser::showBookmarks() {
	auto it = bookmarks.begin();
	int y = 0, c = 'a';

	erase();

	for (; it != bookmarks.end(); it++, y++) {
		mvprintw(y, 0, "%c %s", y + 'a', it->c_str());
	}

	c = prompt::get("Select bookmark:", "");

	if (!std::isalpha(c) && c - 'a' < static_cast<char>(bookmarks.size())) {
		return;
	}

	it = bookmarks.begin();
	std::advance(it, c - 'a');
	global::currentPath = *it;
	fs::current_path(global::currentPath);
	index = 0;
	fillList();
}

void Browser::fillList() {
	entries.clear();
	FileEntry entry;

	for (auto &it : fs::directory_iterator(global::currentPath)) {
		entry.name = std::move(it.path().string());
		entry.status = it.status();

		if (fs::is_regular_file(entry.name) && !fs::is_symlink(entry.name)) {
			entry.size = fs::file_size(it);
			entry.sizeStr = utils::bytesToString(entry.size);
		} else {
			entry.size = std::numeric_limits<std::uintmax_t>::max();
		}

		entries.push_back(entry);
	}

	std::sort(entries.begin(), entries.end(), FileEntryComp());
	erase();
}

void Browser::enterDir() {
	fs::path path(entries[index].name);

	if (fs::is_directory(path)) {
		global::currentPath /= path;
		fs::current_path(global::currentPath);
		fillList();
		index = 0;
	} else {
		std::string mime = magic_file(global::cookie, path.c_str());

		auto hold = [&](pid_t pid) {
			int status;
			waitpid(pid, &status, 0);
		};

		if (mime.find("text") == 0 || mime.find("inode/x-empty") == 0) {
			utils::createProcess(
			    [&]() {
				    execlp(global::config.editor.c_str(),
				           global::config.editor.c_str(), path.c_str(),
				           nullptr);
			    },
			    hold);
			fillList();
		} else if (static_cast<int>(entries[index].status.permissions()) &
		           00111)  // If executable
		{
			// TODO: This entire situation should be generalized
			utils::createProcess(
			    [&]() { execlp(path.c_str(), path.c_str(), nullptr); }, hold);

			// Display output and confirm user input
			timeout(0);
			endwin();
			printf("Press ENTER to return");
			getchar();

			// Restore state
			initscr();
			fillList();
			timeout(global::TICK);
		} else {
			utils::createProcess(
			    [&]() {
				    execlp(global::config.opener.c_str(),
				           global::config.opener.c_str(), path.c_str(),
				           nullptr);
			    },
			    hold);
		}
	}
}

void Browser::printHeader() {
	int x = getmaxx(stdscr);
	mvprintw(0, 0, std::string(x, ' ').c_str());
	attron(A_BOLD | COLOR_PAIR(1));
	mvprintw(0, 0, global::currentPath.string().substr(0, x).c_str());
	attroff(A_BOLD | COLOR_PAIR(1));
}

void Browser::printDirs() {
	constexpr int ox = 0, oy = 1;
	int height, width;
	getmaxyx(stdscr, height, width);
	int upperLimit = std::abs(static_cast<int>(entries.size()) - height + oy);
	int limit = oy + static_cast<int>(index) - (height >> 1);
	auto it = entries.begin();

	constexpr std::string_view dirStr = "/  ";
	constexpr std::string_view lnStr = "~> ";
	static_assert(dirStr.size() == lnStr.size());
	constexpr int padBeforeFileName =
	    +3    // Length of permissions string
	    + 10  // Length of filesize/dirdef string
	    + 4;  // Sum of individual padding between each column

	if (static_cast<int>(entries.size()) < height - oy) {
		upperLimit = 0;
	}

	limit = std::clamp(limit, 0, upperLimit);
	it += limit;

	for (int i = 0; it != entries.end(); i++, it++) {
		int lastSep = it->name.find_last_of('/');

		attroff(A_REVERSE);
		index == i + limit ? attron(A_REVERSE) : attroff(A_REVERSE);
		fs::is_directory(it->name) ? attron(A_BOLD) : attroff(A_BOLD);

		mvprintw(
		    i + oy, ox, " %o %10s %s%s ",
		    static_cast<int>(it->status.permissions()) & 00777,  // Permissions
		    fs::is_symlink(it->name) ? lnStr.data() :  // Filesize/dirdef
		        it->hasSize() ? it->sizeStr.c_str() : dirStr.data(),
		    marks.find(it->name) != marks.end() ? " " : "",  // Filename
		    it->name.substr(lastSep + 1, width - ox - padBeforeFileName)
		        .c_str());
	}

	attroff(A_REVERSE);
	attroff(A_BOLD);
}

void Browser::findPath() {
	std::string input;
	int c = '\0';
	std::vector<bool> bits(entries.size(), false);

	while (true) {
		c = prompt::get(input, "Go:");

		if (c == KEY_BACKSPACE && !input.empty()) {
			input.pop_back();
		} else if (c == 27) {
			break;
		} else if (c != '\0') {
			input.push_back(c);
		}

		if (input.empty()) {
			continue;
		}

		std::fill(bits.begin(), bits.end(), false);

		for (size_t i = 0; i < entries.size(); i++) {
			std::string str = entries[i].file();

			bits[i] = utils::startsWith(str, input);
		}

		if (auto it = std::find(bits.begin(), bits.end(), true);
		    it != bits.end()) {
			index = it - bits.begin();

			if (std::find(it + 1, bits.end(), true) == bits.end()) {
				enterDir();
				return;
			}

			printHeader();
			printDirs();
		}
	}
}

void Browser::createTerminal() {
	utils::createProcess([&]() {
		const char *term = global::config.terminal.data();
		execlp(term, term, nullptr);
	});
}

void Browser::deleteEntry() {
	if (!marks.empty()) {
		int prompt = prompt::get(
		    "", "Delete " + std::to_string(marks.size()) + " objects?(Y/N):");

		if (prompt == 'y' || prompt == 'Y') {
			for (auto &mark : marks) {
				if (fs::is_directory(mark)) {
					fs::remove_all(mark);
				} else {
					fs::remove(mark);
				}
			}

			marks.clear();
		}
		return;
	}

	int prompt =
	    prompt::get("", "Delete " + entries[index].file().string() + "?(Y/N):");

	if (prompt != 'y' && prompt != 'Y') {
		return;
	}

	if (fs::is_directory(entries[index].name)) {
		fs::remove_all(entries[index].name);
	} else {
		fs::remove(entries[index].name);
	}
}

void Browser::onActivate() {
	global::currentPath = fs::current_path();

	for (auto &bind : global::config.bindings) {
		if (!bind.second.action) {
			bind.second.action = [&]() {
				std::string cmd = std::regex_replace(
				    bind.second.description, std::regex("\\%F"),
				    std::string(" ") + global::currentPath.c_str() + ' ');

				// TODO: Violation of DRY
				auto hold = [&](pid_t pid) {
					int status;
					waitpid(pid, &status, 0);
				};

				utils::createProcess(
				    [&]() { execlp("sh", "sh", "-c", cmd.c_str(), nullptr); },
				    hold);

				fillList();
			};
		}
	}

	loadBookmarks();
	fillList();
}

void Browser::onDeactivate() {}

void Browser::draw() {
	erase();
	printHeader();
	printDirs();
}

// TODO: Load bindings from file/similar
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

void Browser::update(int input) {
	std::string prompt;
	std::ofstream file;
	std::error_code ec;
	int c = 0;

	switch (input) {
		case -1:
			break;
		case 's':
			endwin();
			system(global::config.shell.c_str());
			initscr();
			fillList();
			printDirs();
			break;
		case 'S':
			createTerminal();
			break;
		case KEY_LEFT: /* Left */
		case 'h':
			global::currentPath = global::currentPath.parent_path();
			fs::current_path(global::currentPath);
			index = 0;
			fillList();
			break;
		case KEY_RIGHT: /* Right */
		case 'l':
			enterDir();
			break;
		case KEY_DOWN: /* Down */
		case 'j':
			++index;
			if (index >= static_cast<int>(entries.size())) {
				index = 0;
			}
			break;
		case KEY_UP: /* Up */
		case 'k':
			--index;
			if (index < 0) {
				index = static_cast<int>(entries.size()) - 1;
			}
			break;
		case 'c':
			prompt = prompt::getString("Name of file:");
			if (prompt.empty() || fs::exists(prompt.c_str())) {
				return;
			}
			file.open(prompt.c_str());
			fillList();
			printHeader();
			printDirs();
			break;
		case 'C':
			prompt = prompt::getString("Name of directory:");
			if (prompt.empty() || fs::exists(prompt.c_str())) {
				return;
			}
			fs::create_directory(prompt.c_str());
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
			if (auto mark = marks.find(entries[index].name);
			    mark != marks.end()) {
				marks.erase(mark);
			} else {
				marks.insert(entries[index].name);
			}
			if (index < static_cast<int>(entries.size()) - 1) {
				++index;
			}
			printDirs();
			break;
		case 'R':
			prompt = prompt::getString("New name:");
			if (prompt.empty()) {
				return;
			}
			if (fs::exists(prompt.c_str()) && prompt.find("..") != 0 &&
			    prompt != ".") {
				c = prompt::get("", "Warning: " + prompt +
				                        " already exists. Overwrite?(Y/N):");
				if (c != 'Y' && c != 'y') {
					return;
				}
			}
			fs::rename(entries[index].name, prompt, ec);
			fillList();
			printDirs();
			break;
		case 'G':
			clear();
			global::pushState(std::make_unique<Git>());
		case 'm':
			marks.clear();
			break;
		case 'a':
			prompt = magic_file(global::cookie, entries[index].name.c_str());
			prompt::get(prompt, "MIME type: ");
			break;
		case 'p':
			for (auto &mark : marks) {
				fs::copy(mark, global::currentPath / utils::file(mark),
				         fs::copy_options::recursive, ec);
			}
			marks.clear();
			fillList();
			printDirs();
			break;
		case 'v':
			for (auto &mark : marks) {
				fs::rename(mark, global::currentPath / utils::file(mark), ec);
			}
			marks.clear();
			fillList();
			printDirs();
			break;
		case 'b':
			loadBookmarks();
			if (auto mark = bookmarks.find(global::currentPath);
			    mark != bookmarks.end()) {
				bookmarks.erase(mark);
			} else if (static_cast<char>(bookmarks.size()) < 'z' - 'a') {
				bookmarks.insert(global::currentPath);
				saveBookmarks();
			}
			printDirs();
			break;
		case 'g':
			showBookmarks();
			break;
		case 4:
		case 'q':
			global::popState();
			return;
			break;
		default:
			LOG << "Found weird input\n";
			if (auto it = global::config.bindings.find(input);
			    it != global::config.bindings.end()) {
				LOG << "Doing werid thing\n";
				it->second.action();
			}
	}

	if (ec) {
		prompt::get(ec.message(), "Operation failed: ");
	}
}

void Browser::loadBookmarks() {
	std::ifstream file((global::config.home + bookmarkPath).c_str());
	if (!file.is_open()) {
		return;
	}

	std::string line;

	while (std::getline(file, line)) {
		bookmarks.insert(line);
	}
}

void Browser::saveBookmarks() {
	std::ofstream file((global::config.home + bookmarkPath).c_str());
	if (!file.is_open()) {
		return;
	}

	std::string line;

	for (auto &mark : bookmarks) {
		file << mark << '\n';
	}
}
