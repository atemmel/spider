#include "token.hpp"

#include <iostream>

std::vector<std::string> validTokens = 
{
	"bind", "exec", "set"
};

std::vector<std::string> validConfig =
{
	"terminal", "visual"
};

std::ostream &operator<<(std::ostream &os, const Token& token)
{
	switch(token.type)
	{
		case Token::Type::Bind:
			os << "Bind:     ";
			break;
		case Token::Type::Exec:
			os << "Exec:     ";
			break;
		case Token::Type::Set:
			os << "Set:      ";
			break;
		case Token::Type::Terminal:
			os << "Terminal: ";
			break;
		case Token::Type::Visual:
			os << "Visual:   ";
			break;
		case Token::Type::String:
			os << "String:   ";
			break;
		default:
			os << static_cast<int>(token.type) << ":       ";
	}

	token.value.empty() ? os << "Null " : os << token.value;

	return os;
}
