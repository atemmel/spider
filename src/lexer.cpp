#include "lexer.hpp"

#include <algorithm>
#include <fstream>
#include <iostream>

std::vector<Token> Lexer::open(const char* path)
{
	std::ifstream file;
	file.open(path, std::ios::in | std::ios::binary | std::ios::ate);

	if(!file.is_open() ) return std::vector<Token>();

	std::string str = read(file);
	
	return parse(str);
}

std::string Lexer::read(std::ifstream &file)
{
	auto size = file.tellg();
	file.seekg(0, std::ios::beg);

	std::vector<char> bytes(size);
	file.read(bytes.data(), size);

	return std::string(bytes.data(), size);
}

std::vector<Token> Lexer::parse(const std::string &str)
{
	std::string word;
	std::vector<Token> tokens;
	auto it = str.begin(), wordstart = str.begin(), end = str.end();

	//TODO: replace cerr with logging stream
	/*
	for(size_t i = 0; i < str.size(); i++) {
		std::cerr << i << " > " << str[i] << " : " << static_cast<int>(str[i]) << '\n';
	}
	*/

Next:
	if(it == end) goto Done;
	while(std::isspace(*it) )
	{
		++it, ++wordstart;
		if(it == end) goto Done;
	}
	//std::cerr << "Token starts at: " << std::distance(str.begin(), it) << '\n';

	if(*it == '#')
	{
		wordstart = it = std::find(std::next(it), end, '\n');
		goto Next;
	}
	else if(*it == '"')
	{
		Token token;
		auto endquote = std::find(std::next(it), end, '"');
		token.value = std::string(std::next(it), endquote);
		token.type = Token::Type::String;

		//std::cerr << token << '\n';
		tokens.push_back(token);
		wordstart = it = endquote;
		++it, ++wordstart;
		goto Next;
	}
	else
	{
		it = std::find_if(it, end, [](const char c) {
			return std::isspace(c);
		});

		if(it + 1 == end) goto Done;

		Token token;
		word.assign(wordstart, it);
		if(word.empty() ) goto Next;

		//Replace this once more tokens are added

		//If token
		if(auto vt = std::find(validTokens.begin(), validTokens.end(), word); vt != validTokens.end() )
		{
			token.type = static_cast<Token::Type>(std::distance(validTokens.begin(), vt) );
		}
		//If setting
		else if(auto vc = std::find(validConfig.begin(), validConfig.end(), word); vc != validConfig.end() )
		{
			int offset = static_cast<int>(Token::Type::ConfigOffset) + 1;
			token.type = static_cast<Token::Type>(offset + std::distance(validConfig.begin(), vc) );
		}
		//Otherwise, it must be a value
		else
		{
			token.type = Token::Type::String;
			token.value = word;
		}

		wordstart = it;
		//std::cerr << token << '\n';
		tokens.push_back(token);

		goto Next;
	}

Done:
	return tokens;
}
