#pragma once
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <string_view>
#include <unordered_set>
#include <vector>

#include "git.hpp"
#include "global.hpp"
#include "plugin.hpp"
#include "prompt.hpp"
#include "utils.hpp"

namespace fs = std::filesystem;

class Browser final : public Plugin {
public:
	void draw() override;

	void update(int keypress) override;

	void onActivate() override;

	void onDeactivate() override;

private:
	void fillList();
	void enterDir();
	void printHeader();
	void printDirs();
	void findPath();
	void createTerminal();
	void deleteEntry();
	void showBookmarks();

	void loadBookmarks();
	void saveBookmarks();

	struct FileEntry {
		bool hasSize() const {
			return size != std::numeric_limits<std::uintmax_t>::max();
		}

		fs::path file() const { return fs::path(name).filename(); }

		std::string dir() const { return utils::dir(name); }

		std::string name;
		fs::file_status status;
		std::uintmax_t size;
		std::string sizeStr;
	};

	// TODO: Move to separate header/impl
	/**
	 *	Implements less-than comparison between two file entries
	 */
	struct FileEntryComp {
		bool operator()(const FileEntry &lhs, const FileEntry &rhs) {
			if (fs::is_directory(rhs.name)) {
				if (fs::is_directory(lhs.name)) {
					return utils::caseInsensitiveComparison(lhs.name, rhs.name);
				} else {
					return false;
				}
			} else if (fs::is_directory(lhs.name)) {
				return true;
			}

			return utils::caseInsensitiveComparison(lhs.name, rhs.name);
		}
	};

	using FileEntries = std::vector<FileEntry>;
	FileEntries entries;
	std::unordered_set<std::string> marks;
	std::unordered_set<std::string> bookmarks;
	int index = 0;

	const std::string bookmarkPath = "/.spider-bookmarks";
};
