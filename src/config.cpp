#include "config.hpp"
#include "lexer.hpp"

#include <iostream>

Config::Config()
{
	char* editorEnv = getenv("VISUAL");
	char* terminalEnv = getenv("TERMCMD");
	char* openerEnv = getenv("SPIDER-OPENER");

	editor = editorEnv ? editorEnv : "nvim";
	terminal = terminalEnv ? terminalEnv : "urxvt";
	opener = openerEnv ? openerEnv : "xdg-open";
	home = getenv("HOME");

	Lexer lexer;

	//std::cerr << "Reading tokens from " << home + "/.config/spider/spider.conf\n";
	auto tokens = lexer.open((home + "/.config/spider/spider.conf").c_str() );

	/*
	for(auto &t : tokens)
	{
		std::cerr << t << '\n';
	}
	*/

	Token::Type expected;

	for(size_t i = 0; i < tokens.size(); i++)
	{
		if(tokens[i].type == Token::Type::Set)
		{
			expected = Token::Type::ConfigOffset;
		}
		else if(tokens[i].type > Token::Type::ConfigOffset)
		{
			if(expected != Token::Type::ConfigOffset) continue;

			expected = tokens[i].type;
			++i;

			if(tokens[i].type != Token::Type::String
					|| tokens[i].value.empty() ) continue;

			switch(expected)
			{
				case Token::Type::Terminal:
					terminal = tokens[i].value;
					break;
				case Token::Type::Visual:
					editor = tokens[i].value;
					break;
				default:
					break;
			}
		}
	}
}
