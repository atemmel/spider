#include "utils.hpp"

bool caseInsensitiveComparison(const std::string &lhs, const std::string &rhs)
{
	auto lit = lhs.begin(), rit = rhs.begin();

	while(lit != lhs.end() && rit != rhs.end() )
	{
		char a = toupper(*lit), b = toupper(*rit);

		if(a < b) return true;
		else if(a > b) return false;

		++lit, ++rit;
	}

	return lit == lhs.end() && rit != rhs.end();
}

bool startsWith(const std::string &origin, const std::string &match)
{
	if(origin.size() < match.size() ) return false;

	auto originIt = origin.begin(), matchIt = match.begin();

	while(matchIt != match.end() )
	{
		if(*originIt != *matchIt) return false;

		++originIt, ++matchIt;
	}

	return true;
}

void toUpper(std::string &str)
{
	std::transform(str.begin(), str.end(), str.begin(), [](unsigned char c)
	{
		return std::toupper(c);
	});
}
