#pragma once

#include <git2.h>

#include "plugin.hpp"
#include "prompt.hpp"

class Repository {
public:
	Repository(const char* path);

	operator git_repository*();

	operator int();

	~Repository();

private:
	git_repository* repo;
	int error;
};

class Git : public Plugin {
	void onActivate() override;
};
