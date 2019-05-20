#pragma once

#include "prompt.hpp"
#include "plugin.hpp"

#include <git2.h>

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

class Git : public Plugin
{
	void onActivate() override;

};
