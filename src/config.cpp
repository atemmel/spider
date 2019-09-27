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

	Token::Type expected = Token::Type::String;
	size_t i = 0;

	for(; i < tokens.size(); i++)
	{
		if(tokens[i].type == Token::Type::Set)
		{
			expected = Token::Type::ConfigOffset;
		}
		if(tokens[i].type == Token::Type::Bind)
		{
			//Expect string
			++i;
			if(i == tokens.size() ) return;
			if(tokens[i].type != Token::Type::String
					|| tokens[i].value.empty() 
					|| tokens[i].value.size() != 1) continue;
			
			int ch = tokens[i].value.front();

			//Expect string
			++i;
			if(i == tokens.size() ) return;
			if(tokens[i].type != Token::Type::String
					|| tokens[i].value.empty() ) continue;

			Bind bind;
			bind.description = tokens[i].value;

			bindings.insert(std::make_pair(ch, bind) );
		}
		else if(tokens[i].type > Token::Type::ConfigOffset)
		{
			if(expected != Token::Type::ConfigOffset) continue;

			expected = tokens[i].type;
			++i;
			if(i == tokens.size() ) return;

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
