#pragma once

#include <string>
#include <vector>

struct Token
{
	enum Type
	{
		Bind = 0,
		Exec,
		Set,

		ConfigOffset,
		Terminal,
		Visual,

		String
	};

	Type type;
	std::string value;
};

std::ostream &operator<<(std::ostream &os, const Token& token);

extern std::vector<std::string> validTokens;
extern std::vector<std::string> validConfig;
