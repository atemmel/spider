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
	git_repository* repo;
	int error;
};

class Git : public Plugin
{
	void onActivate() override;

};
