#ifndef __LOG_H__
#define __LOG_H__

#include <cstdio>
#include <cstdarg>
#include <string>
#include <vector>
#include <functional>

enum LogType {
    LOG_INFO,
    LOG_WARNING,
    LOG_ERROR
};

struct LogInfo
{
    LogType type = LOG_INFO;
    std::string message = "";
    size_t messageHash = 0;
    int count = 0;
};

#define LOG(type, format, ...)       LogInternal(type, __FILE__, __LINE__, format, ##__VA_ARGS__)
#define LOG_CONSOLE(format, ...)     LogInternal(LOG_INFO, __FILE__, __LINE__, format, ##__VA_ARGS__)

#define LOG_DEBUG(format, ...)       LogExternal(__FILE__, __LINE__, format, ##__VA_ARGS__)

void LogInternal(LogType type, const char file[], int line, const char* format, ...);
void LogExternal(const char file[], int line, const char* format, ...);

class ConsoleLog
{
public:
    static ConsoleLog& GetInstance() {
        static ConsoleLog instance;
        return instance;
    }

    void AddLog(LogType type, const std::string& msg) {
        size_t incomingHash = std::hash<std::string>{}(msg);
        bool found = false;

        for (auto it = logs.begin(); it != logs.end(); ++it)
        {
            if (it->messageHash == incomingHash && it->type == type)
            {
                if (it->message == msg)
                {
                    LogInfo existingLog = *it;
                    existingLog.count++;
                    logs.erase(it);
                    logs.push_back(existingLog);
                    found = true;
                    break;
                }
            }
        }

        if (!found)
        {
            LogInfo newLog;
            newLog.type = type;
            newLog.message = msg;
            newLog.messageHash = incomingHash;
            newLog.count = 1;
            logs.push_back(newLog);
        }

        if (logs.size() > 1000) {
            logs.erase(logs.begin());
        }
    }

    void Clear() { logs.clear(); }

    const std::vector<LogInfo>& GetLogs() const { return logs; }

    void Shutdown()
    {
        logs.clear();
        logs.shrink_to_fit();
    }

private:
    ConsoleLog() = default;
    ~ConsoleLog() = default;

    ConsoleLog(const ConsoleLog&) = delete;
    ConsoleLog& operator=(const ConsoleLog&) = delete;

    std::vector<LogInfo> logs;
};

#endif