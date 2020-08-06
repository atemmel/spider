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

// TODO Plan out this a bit more
class Git final : public Plugin {
	void update(int keypress) override;
	void draw() override;
	void onActivate() override;
	void onDeactivate() override;
};
