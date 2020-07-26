#pragma once

#include <ncurses.h>

#include <string>

namespace prompt {

std::string getString(const std::string &message);

int get(const std::string &value, const std::string &message);

}  // namespace prompt
