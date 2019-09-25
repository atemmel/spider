#include "utils.hpp"

namespace Utils
{

std::string file(const std::string &str)
{
	return str.substr(str.find_last_of('/') + 1);
}

std::string dir(const std::string &str)
{
	return str.substr(0, str.find_last_of('/') );
}

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

std::string bytesToString(std::uintmax_t bytes)
{
	constexpr std::string_view prefix[] = {"Byt", "KiB", "MiB", "GiB", "TiB"};
	std::uintmax_t remainder = 0;
	int i = 0;

	while(bytes > 1024)
	{
		remainder = bytes & 1023; 
		bytes >>= 10, ++i;
	}

	auto right = static_cast<float>(remainder);

	right /= 1024.f;	//normalize
	right *= 10.f;		//Scale so that 0 < right < 10

	right = static_cast<float>(static_cast<int>(right + 0.5f) );

	std::string str(10, '\0');

	if(right > 1.f)
	{
		std::snprintf(str.data(), str.size(), "%zu.%.0f%s", bytes, right, prefix[i].data() );
	}
	else
	{
		std::snprintf(str.data(), str.size(), "%zu%s", bytes, prefix[i].data() );
	}

	return str;
}

}
