#include "config.hpp"

Config::Config()
{
	char* editorEnv = getenv("VISUAL");
	char* terminalEnv = getenv("TERMCMD");
	char* openerEnv = getenv("SPIDER-OPENER");

	editor = editorEnv ? editorEnv : "nvim";
	terminal = terminalEnv ? terminalEnv : "urxvt";
	opener = openerEnv ? openerEnv : "xdg-open";
}
