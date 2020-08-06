#include "git.hpp"

#include "global.hpp"

Repository::Repository(const char* path) {
	error = git_repository_open(&repo, path);
}

Repository::operator git_repository*() { return repo; }

Repository::operator int() { return error; }

Repository::~Repository() { git_repository_free(repo); }

void Git::update(int keypress) {
	switch (keypress) {
		case 'q':
			global::popState();
			break;
	}
}

void Git::draw() {  // TODO: Draw calls should appear here, not in onActivate
}

void Git::onActivate() {
	Repository repo(global::currentPath.c_str());

	if (repo != 0) {
		prompt::get(giterr_last()->message,
		            "Could not enter git mode, error: ");
		return;
	}

	auto callback = [](const char* file, unsigned int statusFlags,
	                   void* payload) {
		if (payload) {
			return 1;
		}

		switch (statusFlags) {
			case GIT_STATUS_INDEX_NEW:
			case GIT_STATUS_WT_NEW:
				printw("A");
				break;
			case GIT_STATUS_INDEX_MODIFIED:
			case GIT_STATUS_WT_MODIFIED:
				printw("M");
				break;
			case GIT_STATUS_INDEX_DELETED:
			case GIT_STATUS_WT_DELETED:
				printw("D");
				break;
			case GIT_STATUS_IGNORED:
				return 0;
				break;
			case GIT_STATUS_INDEX_TYPECHANGE:
			case GIT_STATUS_WT_TYPECHANGE:
				printw("T");
				break;
			case GIT_STATUS_INDEX_RENAMED:
			case GIT_STATUS_WT_RENAMED:
				printw("R");
				break;
			case GIT_STATUS_WT_UNREADABLE:
				printw("X");
				break;
			default:
				printw("%d", statusFlags);
				break;
		}

		printw("\t%s", file);

		printw("\n");

		return 0;
	};

	move(0, 0);
	git_status_foreach(repo, callback, nullptr);
}

void Git::onDeactivate() {}
