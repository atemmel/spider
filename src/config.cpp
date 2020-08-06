#include "config.hpp"

#include <iostream>

#include "debug.hpp"
#include "lexer.hpp"

void Config::load() {
	char* editorEnv = getenv("VISUAL");
	char* terminalEnv = getenv("TERMCMD");
	char* openerEnv = getenv("SPIDER-OPENER");
	char* shellEnv = getenv("SHELL");

	editor = editorEnv ? editorEnv : "nvim";
	terminal = terminalEnv ? terminalEnv : "urxvt";
	opener = openerEnv ? openerEnv : "xdg-open";
	shell = shellEnv ? shellEnv : "bash";
	home = getenv("HOME");

	Lexer lexer;

	auto tokens = lexer.open((home + "/.config/spider/spider.conf").c_str());

	Token::Type expected = Token::Type::String;
	size_t i = 0;

	for (; i < tokens.size(); i++) {
		if (tokens[i].type == Token::Type::Set) {
			expected = Token::Type::ConfigOffset;
		}
		if (tokens[i].type == Token::Type::Bind) {
			// Expect string
			++i;
			if (i == tokens.size()) {
				return;
			}
			if (tokens[i].type != Token::Type::String ||
			    tokens[i].value.empty() || tokens[i].value.size() != 1) {
				continue;
			}

			int ch = static_cast<unsigned char>(tokens[i].value.front());

			// Expect string
			++i;
			if (i == tokens.size()) {
				return;
			}
			if (tokens[i].type != Token::Type::String ||
			    tokens[i].value.empty()) {
				continue;
			}

			Bind bind;
			bind.description = tokens[i].value;

			LOG << "Inserted funny thing at " << ch << '\n';
			bindings.insert(std::make_pair(ch, bind));
		} else if (tokens[i].type > Token::Type::ConfigOffset) {
			if (expected != Token::Type::ConfigOffset) {
				continue;
			}

			expected = tokens[i].type;
			++i;
			if (i == tokens.size()) {
				return;
			}

			if (tokens[i].type != Token::Type::String ||
			    tokens[i].value.empty()) {
				continue;
			}

			switch (expected) {
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
