#pragma once
#include <string_view>
#include <functional>

struct Bind
{
	std::function<void()> action;
	std::string_view description;
};
