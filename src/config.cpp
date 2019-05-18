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

	std::cerr << "Reading tokens from " << home + "/.config/spider/conf\n";
	auto tokens = lexer.open((home + "/.config/spider/conf").c_str() );

	for(auto &t : tokens)
	{
		std::cerr << t << '\n';
	}
}
