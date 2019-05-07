#pragma once

#include "prompt.hpp"

#include <git2.h>

namespace Git
{

class Repository
{
public:
	Repository(const char* path);

	operator git_repository* ();

	operator int ();

	~Repository();

private:
	git_repository* m_repo;
	int m_error;
};

void activate(const char* path);

}
