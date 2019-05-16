#pragma once
#include "plugin.hpp"
#include "global.hpp"
#include "prompt.hpp"
#include "utils.hpp"
#include "git.hpp"

// This looks good :)
#include <string_view>
#include <filesystem>
#include <iostream>
#include <fstream>
#include <vector>
#include <limits>
#include <set>

namespace fs = std::filesystem;

class Browser : public Plugin
{
public:
	void draw() override;

	void update(int keypress) override;

	void onActivate() override;

private:
	void fillList();
	void enterDir();
	void printHeader();
	void printDirs();
	void findPath();
	void createTerminal();
	void deleteEntry();

	struct FileEntry
	{
		bool hasSize() const
		{
			return size != std::numeric_limits<std::uintmax_t>::max();
		}

		fs::path file() const
		{
			return fs::path(name).filename();
		}

		std::string dir() const
		{
			return Utils::dir(name);
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
			if(fs::is_directory(rhs.name) )
			{
				if(fs::is_directory(lhs.name) ) return Utils::caseInsensitiveComparison(lhs.name, rhs.name);
				else return false;
			}
			else if(fs::is_directory(lhs.name) ) return true;

			return Utils::caseInsensitiveComparison(lhs.name, rhs.name); 
		}
	};

	using FileEntries = std::vector<FileEntry>;
	FileEntries entries;	
	std::set<std::string> marks;
	fs::path current_path;
	int index = 0;
};

//SPIDER_PLUGIN_EXPORT(Browser)
