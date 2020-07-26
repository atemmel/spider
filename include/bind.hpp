#pragma once
#include <functional>
#include <string>

struct Bind {
	std::function<void()> action;
	std::string description;
};
