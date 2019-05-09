#pragma once

#include <ncurses.h>
    
#include <string>

namespace Prompt
{

std::string getString(const std::string &message);

int get(const std::string &value, const std::string &message);

/*
static void clear(int x, int y);

static void print(int y, const char* value, const char* message);

static void exit(int x, int y);
*/

}
