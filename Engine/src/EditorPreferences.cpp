#include "EditorPreferences.h"
#include "Log.h"
#include <fstream>
#include <filesystem>

#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>
#endif

ExternalEditor EditorPreferences::preferredEditor = ExternalEditor::INTERNAL;
std::string EditorPreferences::customEditorPath = "";
std::string EditorPreferences::preferencesPath = "EditorPreferences.json";

void EditorPreferences::Initialize()
{
    Load();
}

void EditorPreferences::Save()
{
    nlohmann::json j;

    j["preferredEditor"] = static_cast<int>(preferredEditor);
    j["customEditorPath"] = customEditorPath;

    std::ofstream file(preferencesPath);
    if (file.is_open())
    {
        file << j.dump(4);
        file.close();
        LOG_DEBUG("[EditorPreferences] Saved preferences");
    }
    else
    {
        LOG_CONSOLE("[EditorPreferences] ERROR: Cannot save preferences");
    }
}

void EditorPreferences::Load()
{
    if (!std::filesystem::exists(preferencesPath))
    {
        LOG_DEBUG("[EditorPreferences] No preferences file found, using defaults");
        return;
    }

    std::ifstream file(preferencesPath);
    if (!file.is_open())
    {
        LOG_CONSOLE("[EditorPreferences] ERROR: Cannot load preferences");
        return;
    }

    try
    {
        nlohmann::json j;
        file >> j;

        if (j.contains("preferredEditor"))
        {
            preferredEditor = static_cast<ExternalEditor>(j["preferredEditor"]);
        }

        if (j.contains("customEditorPath"))
        {
            customEditorPath = j["customEditorPath"];
        }

        LOG_DEBUG("[EditorPreferences] Loaded preferences");
    }
    catch (const std::exception& e)
    {
        LOG_CONSOLE("[EditorPreferences] ERROR parsing preferences: %s", e.what());
    }

    file.close();
}

std::string EditorPreferences::GetEditorExecutablePath()
{
    switch (preferredEditor)
    {
    case ExternalEditor::VISUAL_STUDIO_2022:
#ifdef _WIN32
        // Common VS 2022 paths
    {
        const char* vsPath = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\Common7\\IDE\\devenv.exe";
        if (std::filesystem::exists(vsPath))
            return vsPath;

        vsPath = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\Common7\\IDE\\devenv.exe";
        if (std::filesystem::exists(vsPath))
            return vsPath;

        vsPath = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Enterprise\\Common7\\IDE\\devenv.exe";
        if (std::filesystem::exists(vsPath))
            return vsPath;
    }
#endif
    return "";

    case ExternalEditor::VSCODE:
#ifdef _WIN32
    {
        const char* vscodePath = "C:\\Program Files\\Microsoft VS Code\\Code.exe";
        if (std::filesystem::exists(vscodePath))
            return vscodePath;

        vscodePath = "C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Microsoft VS Code\\Code.exe";
        // Expand %USERNAME%
        char expanded[MAX_PATH];
        ExpandEnvironmentStringsA(vscodePath, expanded, MAX_PATH);
        if (std::filesystem::exists(expanded))
            return expanded;
    }
#elif __linux__
        return "code";
#elif __APPLE__
        return "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code";
#endif
        return "";

    case ExternalEditor::CUSTOM:
        return customEditorPath;

    case ExternalEditor::INTERNAL:
    default:
        return "";
    }
}

bool EditorPreferences::OpenFileWithPreferredEditor(const std::string& filePath)
{
    if (preferredEditor == ExternalEditor::INTERNAL)
    {
        return false; // Caller should open internal editor
    }

    std::string editorPath = GetEditorExecutablePath();

    if (editorPath.empty())
    {
        LOG_CONSOLE("[EditorPreferences] ERROR: Editor executable not found");
        return false;
    }

    std::string absolutePath = std::filesystem::absolute(filePath).string();

#ifdef _WIN32
    // Use ShellExecute on Windows
    std::string command = "\"" + editorPath + "\" \"" + absolutePath + "\"";

    SHELLEXECUTEINFOA sei = { sizeof(sei) };
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = "open";
    sei.lpFile = editorPath.c_str();
    sei.lpParameters = absolutePath.c_str();
    sei.nShow = SW_SHOWNORMAL;

    if (ShellExecuteExA(&sei))
    {
        return true;
    }
    else
    {
        LOG_CONSOLE("[EditorPreferences] ERROR: Failed to open external editor");
        return false;
    }
#else
    // Unix-like systems
    std::string command = editorPath + " \"" + absolutePath + "\" &";
    int result = system(command.c_str());

    if (result == 0)
    {
        return true;
    }
    else
    {
        LOG_CONSOLE("[EditorPreferences] ERROR: Failed to open external editor");
        return false;
    }
#endif
}