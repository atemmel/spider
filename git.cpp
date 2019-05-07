#include "git.hpp"

Git::Repository::Repository(const char* path)
{
	m_error = git_repository_open(&m_repo, path);
}

Git::Repository::operator git_repository* ()
{
	return m_repo;
}

Git::Repository::operator int ()
{
	return m_error;
}

Git::Repository::~Repository()
{
	git_repository_free(m_repo);
}

void Git::activate(const char* path)
{
	Repository repo(path);

	if(repo != 0) 
	{
		Prompt::get(giterr_last()->message, "Could not enter git mode, error: ");
		return;
	}

	auto callback = [](const char* file, unsigned int status_flags, void* payload)
	{
		if(payload) return 1;

		switch(status_flags)
		{
			case GIT_STATUS_WT_NEW:
			printw("A");
			break;
			case GIT_STATUS_WT_MODIFIED:
			printw("M");
			break;
			case GIT_STATUS_WT_DELETED:
			printw("D");
			break;
			case GIT_STATUS_IGNORED:
			//printw("I");
			return 0;
			break;
			case GIT_STATUS_WT_TYPECHANGE:
			printw("T");
			break;
			case GIT_STATUS_WT_RENAMED:
			printw("R");
			break;
			case GIT_STATUS_WT_UNREADABLE:
			printw("X");
			break;
			default:
			printw("%d", status_flags);
			break;
		}

		printw("\t%s", file);

		printw("\n");

		return 0;
	};

	move(0, 0);
	git_status_foreach(repo, callback, nullptr);

	int c = 0;
	while(c != 'q')
	{
		c = getch();
	}
}
