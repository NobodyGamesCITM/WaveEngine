#include "Log.h"
#include <iostream>
#include <cstdarg>
#include <cstdio>
#include <string>

void LogExternal(const char file[], int line, const char* format, ...)
{
    static char tmpString1[4096];
    static va_list ap;

    va_start(ap, format);
    vsnprintf(tmpString1, 4096, format, ap);
    va_end(ap);

    std::string logMessage = std::string("\n") + file + "(" + std::to_string(line) + ") : " + tmpString1;

    std::cerr << logMessage << std::endl;
}

void LogInternal(LogType type, const char file[], int line, const char* format, ...)
{
    static char tmpString[4096];
    static va_list ap;

    va_start(ap, format);
    vsnprintf(tmpString, 4096, format, ap);
    va_end(ap);

    std::string message = tmpString;

    std::cerr << message << std::endl;

    ConsoleLog::GetInstance().AddLog(type, message);
}