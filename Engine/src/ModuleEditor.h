#pragma once

#include "Module.h"
#include "EventListener.h"
#include "CommandHistory.h"
#include <imgui.h>
#include <memory>
#include <string>
#include <vector>


class ConfigurationWindow;
class HierarchyWindow;
class InspectorWindow;
class ConsoleWindow;
class SceneWindow;
class GameWindow;
class GameObject;
struct Mesh;
class AssetsWindow;
class ShaderEditorWindow;
class MaterialEditorWindow;
class ScriptEditorWindow;
class EditorCamera;

enum class EditorWindowType
{
    NONE = 0,
    SCENE,
    GAME,
    CONFIGURATION,
    HIERARCHY,
    INSPECTOR,
    CONSOLE,
    ASSETS,
    SHADER_EDITOR,
    ABOUT
};

class ModuleEditor : public Module, public EventListener
{
public:
    ModuleEditor();
    ~ModuleEditor();

    bool Start() override;
    bool PreUpdate() override;
    bool Update() override;
    bool PostUpdate() override;
    bool CleanUp() override;

    // Access to windows
    InspectorWindow* GetInspector() const { return inspectorWindow.get(); }
    SceneWindow* GetSceneWindow() const { return sceneWindow.get(); }
    GameWindow* GetGameWindow() const { return gameWindow.get(); }
    ConfigurationWindow* GetConfigWindow() const { return configWindow.get(); }
    AssetsWindow* GetAssetsWindow() const { return assetsWindow.get(); }
    ConsoleWindow* GetConsoleWindow() { return consoleWindow.get(); }
    EditorCamera* GetEditorCamera() const { return editorCamera; }
    CommandHistory* GetCommandHistory() { return commandHistory.get(); }
    MaterialEditorWindow* GetMaterialEditor() { return materialEditorWindow.get(); }
    ScriptEditorWindow* GetScriptEditor() { return scriptEditorWindow.get(); }

    ImVec2 sceneViewportPos = ImVec2(0, 0);
    ImVec2 sceneViewportSize = ImVec2(1280, 720);

    ImVec2 gameViewportPos = ImVec2(0, 0);
    ImVec2 gameViewportSize = ImVec2(1280, 720);

    // Methods for accessing viewport and debug settings
    bool ShouldShowVertexNormals() const;
    bool ShouldShowFaceNormals() const;
    bool ShouldShowAABB() const;
    bool ShouldShowOctree() const;
    bool ShouldShowRaycast() const;

    // Window State
    EditorWindowType GetCurrentWindow() const { return currentWindow; }
    bool IsSceneWindowActive() const { return currentWindow == EditorWindowType::SCENE;  }
    bool IsMouseOverScene() const;

    //EVENTS
    void OnEvent(const Event& event) override;

    GameObject* CloneGameObject(GameObject* original);
private:
    void ShowMenuBar();
    void ShowPlayToolbar();
    void DrawAboutWindow();
    void CreatePrimitiveGameObject(const std::string& name, Mesh mesh);
    void HandleDeleteKey();
    void UpdateCurrentWindow();
    const char* EditorWindowTypeToString(EditorWindowType type);

    // Layout management
    void SaveLayoutAs(const std::string& filename);
    void LoadLayout(const std::string& filename);
    std::vector<std::string> GetSavedLayouts();

    // File Browser
    std::string OpenSaveFile(const std::string& defaultPath);
    std::string OpenLoadFile(const std::string& defaultPath);
    std::string OpenFolderDialog();

    // Build
    void BuildGame();

    // Editor windows (owned by ModuleEditor)
    std::unique_ptr<ConfigurationWindow> configWindow;
    std::unique_ptr<HierarchyWindow> hierarchyWindow;
    std::unique_ptr<InspectorWindow> inspectorWindow;
    std::unique_ptr<ConsoleWindow> consoleWindow;
    std::unique_ptr<SceneWindow> sceneWindow;
    std::unique_ptr<GameWindow> gameWindow;
    std::unique_ptr<AssetsWindow> assetsWindow;
    std::unique_ptr<ShaderEditorWindow> shaderEditorWindow;
    std::unique_ptr<MaterialEditorWindow> materialEditorWindow;
    std::unique_ptr<ScriptEditorWindow> scriptEditorWindow;

    // About window state
    bool showAbout = false;

    // Window states
    EditorWindowType currentWindow = EditorWindowType::NONE;
    bool isMouseOverSceneViewport = false;
    EditorWindowType lastHoveredWindow = EditorWindowType::NONE;

    // Layout management state
    bool autoSaveLayout = true;
    std::string layoutDirectory = "../Editor Layout/";
    std::string currentLayoutFile = "editor_layout.ini";
    std::string defaultLayoutFile = "editor_layout_default.ini";
    bool showSaveLayoutPopup = false;
    char layoutNameBuffer[128] = "my_layout";

    // Meta file monitoring
    float metaFileCheckTimer = 0.0f;
    const float metaFileCheckInterval = 2.0f;

    EditorCamera* editorCamera;
    // QOL
    std::unique_ptr<CommandHistory> commandHistory;
    void HandleUndoRedo();

    void HandleCopyPaste();

    std::vector<GameObject*> ObjectsCopy;
    bool ischild = false;

    bool centerOnPaste = false;
    float pasteDistance = 10.0f;

    //glm::vec3 tempScale;
};