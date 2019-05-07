#pragma once

#include <magic.h>

namespace Global
{

void init();

void destroy();

constexpr unsigned tick = 1000; //ms

extern magic_t cookie;

}
