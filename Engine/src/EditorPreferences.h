#pragma once

#include <string>
#include <nlohmann/json.hpp>

enum class ExternalEditor
{
    INTERNAL = 0,
    VISUAL_STUDIO_2022,
    VSCODE,
    CUSTOM
};

class EditorPreferences
{
public:
    static void Initialize();
    static void Save();
    static void Load();

    // External editor settings
    static ExternalEditor GetPreferredEditor() { return preferredEditor; }
    static void SetPreferredEditor(ExternalEditor editor) { preferredEditor = editor; Save(); }

    static std::string GetCustomEditorPath() { return customEditorPath; }
    static void SetCustomEditorPath(const std::string& path) { customEditorPath = path; Save(); }

    // Get executable path for external editor
    static std::string GetEditorExecutablePath();

    // Open file with preferred editor
    static bool OpenFileWithPreferredEditor(const std::string& filePath);

private:
    static ExternalEditor preferredEditor;
    static std::string customEditorPath;
    static std::string preferencesPath;
};