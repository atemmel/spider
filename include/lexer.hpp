#pragma once

#include "token.hpp"

class Lexer
{
public:
	std::vector<Token> open(const char* path);
private:
	std::string read(std::ifstream &file);

	std::vector<Token> parse(const std::string &str);
};

