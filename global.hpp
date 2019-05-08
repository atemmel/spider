#pragma once

#include "config.hpp"

#include <magic.h>

namespace Global
{

void init();

void destroy();

constexpr unsigned tick = 1000; //ms

extern Config config;

extern magic_t cookie;

}
