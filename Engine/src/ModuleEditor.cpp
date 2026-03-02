#include "ModuleEditor.h"
#include <imgui.h>
#include <imgui_impl_sdl3.h>
#include <imgui_impl_opengl3.h>
#include <SDL3/SDL.h>
#include <IL/il.h>
#include <filesystem>
#include <fstream>
#include <windows.h>
#include <commdlg.h> // For file dialogs
#include <shobjidl.h> // For folder selection
#include <nlohmann/json.hpp>

#include "Application.h"
#include "Log.h"
#include "GameObject.h"
#include "SelectionManager.h"
#include "ModuleScene.h"
#include "Primitives.h"
#include "ComponentMesh.h"
#include "Transform.h"           
#include "ComponentCamera.h"  
#include "CameraLens.h"   

#include "EditorCamera.h"   
#include "ComponentMaterial.h"
#include "ComponentScript.h"

#include "ConfigurationWindow.h"
#include "HierarchyWindow.h"
#include "InspectorWindow.h"
#include "ConsoleWindow.h"
#include "SceneWindow.h"
#include "GameWindow.h"
#include "AssetsWindow.h"
#include "MetaFile.h"
#include "LibraryManager.h"
#include "ShaderEditorWindow.h"
#include "ScriptEditorWindow.h"
#include "DeleteCommand.h"
#include "CreateCommand.h"
#include "CompositeCommand.h"

ModuleEditor::ModuleEditor() : Module()
{
    name = "ModuleEditor";
}

ModuleEditor::~ModuleEditor()
{

}

bool ModuleEditor::Start()
{
    LOG_DEBUG("Initializing Editor");

    IMGUI_CHECKVERSION();
    std::string layoutPath = layoutDirectory + currentLayoutFile;
    fs::copy_file(layoutDirectory + defaultLayoutFile, layoutPath, fs::copy_options::overwrite_existing);
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    ImGui::LoadIniSettingsFromDisk(io.IniFilename);

    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
    std::filesystem::create_directories(layoutDirectory);
    std::filesystem::create_directories("../Scene");

    // Setup layout file path
    static std::string layoutPathStatic = layoutPath;
    io.IniFilename = autoSaveLayout ? layoutPathStatic.c_str() : nullptr;

    ImGui_ImplSDL3_InitForOpenGL(
        Application::GetInstance().window->GetWindow(),
        Application::GetInstance().renderContext->GetContext()
    );
    ImGui_ImplOpenGL3_Init();

    ImGui::StyleColorsDark();

    ImGuiStyle& style = ImGui::GetStyle();
    style.Colors[ImGuiCol_TitleBg] = ImVec4(0.7f, 0.5f, 0.6f, 1.0f);
    style.Colors[ImGuiCol_TitleBgActive] = ImVec4(1.0f, 0.7f, 0.9f, 1.0f);
    style.Colors[ImGuiCol_TitleBgCollapsed] = ImVec4(0.6f, 0.4f, 0.5f, 1.0f);
    style.Colors[ImGuiCol_Tab] = ImVec4(0.7f, 0.5f, 0.6f, 1.0f);
    style.Colors[ImGuiCol_TabActive] = ImVec4(1.0f, 0.7f, 0.9f, 1.0f);
    style.Colors[ImGuiCol_TabHovered] = ImVec4(1.0f, 0.8f, 0.95f, 1.0f);

    // Create all windows
    configWindow = std::make_unique<ConfigurationWindow>();
    hierarchyWindow = std::make_unique<HierarchyWindow>();
    inspectorWindow = std::make_unique<InspectorWindow>();
    consoleWindow = std::make_unique<ConsoleWindow>();
    sceneWindow = std::make_unique<SceneWindow>(inspectorWindow.get());
    gameWindow = std::make_unique<GameWindow>();
    assetsWindow = std::make_unique<AssetsWindow>();
    shaderEditorWindow = std::make_unique<ShaderEditorWindow>();
    commandHistory = std::make_unique<CommandHistory>();

    editorCamera = new EditorCamera();

    Application::GetInstance().events->Subscribe(Event::Type::EventSDL, this);

    LOG_CONSOLE("Editor initialized");

    return true;
}

bool ModuleEditor::PreUpdate()
{
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplSDL3_NewFrame();
    ImGui::NewFrame();

    return true;
}

bool ModuleEditor::Update()
{
    if (editorCamera)
        editorCamera->Update();

    // Create fullscreen dockspace window
    ImGuiViewport* viewport = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(viewport->Pos);
    ImGui::SetNextWindowSize(viewport->Size);
    ImGui::SetNextWindowViewport(viewport->ID);

    ImGuiWindowFlags window_flags = ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_NoDocking;
    window_flags |= ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse;
    window_flags |= ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove;
    window_flags |= ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoNavFocus;
    window_flags |= ImGuiWindowFlags_NoBackground;

    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0.0f, 0.0f));

    ImGui::Begin("DockSpaceWindow", nullptr, window_flags);
    ImGui::PopStyleVar(3);

    ShowMenuBar();
    ShowPlayToolbar();

    ImGuiID dockspace_id = ImGui::GetID("MyDockSpace");
    ImGui::DockSpace(dockspace_id, ImVec2(0.0f, 0.0f), ImGuiDockNodeFlags_PassthruCentralNode);

    ImGui::End();
    
    sceneWindow->Draw();
    gameWindow->Draw();
    configWindow->Draw();
    consoleWindow->Draw();
    hierarchyWindow->Draw();
    inspectorWindow->Draw();
    assetsWindow->Draw();
    shaderEditorWindow->Draw();

    if (showAbout) {
        DrawAboutWindow();
    }

    HandleDeleteKey();
    HandleUndoRedo();
    HandleCopyPaste();



    if (sceneWindow)
    {
        ImVec2 oldSize = sceneViewportSize;
        sceneViewportPos = sceneWindow->GetViewportPos();
        sceneViewportSize = sceneWindow->GetViewportSize();
    }

    if (gameWindow)
    {
        gameViewportPos = gameWindow->GetViewportPos();
        gameViewportSize = gameWindow->GetViewportSize();
    }

    UpdateCurrentWindow();

    // Check for meta file changes
    metaFileCheckTimer += ImGui::GetIO().DeltaTime;
    if (metaFileCheckTimer >= metaFileCheckInterval) {
        MetaFileManager::CheckForChanges();
        metaFileCheckTimer = 0.0f;
    }

    return true;
}

bool ModuleEditor::PostUpdate()
{
    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    return true;
}

bool ModuleEditor::CleanUp()
{
    Application::GetInstance().events->UnsubscribeAll(this);

    delete editorCamera;
    editorCamera = nullptr;

    LOG_DEBUG("Cleaning up Editor");

    commandHistory->Clear();

    // Save if auto save is enabled
    if (autoSaveLayout && ImGui::GetIO().IniFilename != nullptr)
    {
        ImGui::SaveIniSettingsToDisk(ImGui::GetIO().IniFilename);
        LOG_DEBUG("Layout auto-saved to %s", ImGui::GetIO().IniFilename);
    }

    // Windows will be automatically destroyed by unique_ptr

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplSDL3_Shutdown();
    ImGui::DestroyContext();

    return true;
}

void ModuleEditor::ShowMenuBar()
{
    if (ImGui::BeginMenuBar())
    {
        if (ImGui::BeginMenu("File"))
        {
            if (ImGui::MenuItem("New Scene"))
            {
                Application::GetInstance().scene->NewScene();
            }

            if (ImGui::MenuItem("Save Scene"))
            {
                std::string filepath = OpenSaveFile("../Scene/scene.json");
                if (!filepath.empty())
                {
                    Application& app = Application::GetInstance();
                    app.scene->SaveScene(filepath);
                    LOG_CONSOLE("Scene saved to %s", filepath.c_str());
                }
            }

            if (ImGui::MenuItem("Load Scene"))
            {
                std::string filepath = OpenLoadFile("../Scene/scene.json");
                if (!filepath.empty())
                {
                    Application& app = Application::GetInstance();
                    app.scene->LoadScene(filepath);
                    LOG_CONSOLE("Scene loaded from %s", filepath.c_str());
                }
            }

            ImGui::Separator();

            if (ImGui::MenuItem("Build Game..."))
            {
                BuildGame();
            }

            ImGui::Separator();

            if (ImGui::MenuItem("Exit"))
            {
                Application::GetInstance().RequestExit();
            }
            ImGui::EndMenu();
        }

        if (ImGui::BeginMenu("View"))
        {
            bool sceneOpen = sceneWindow->IsOpen();
            if (ImGui::MenuItem("Scene", NULL, &sceneOpen))
            {
                sceneWindow->SetOpen(sceneOpen);
            }

            bool gameOpen = gameWindow->IsOpen();
            if (ImGui::MenuItem("Game", NULL, &gameOpen))
            {
                gameWindow->SetOpen(gameOpen);
            }

            bool configOpen = configWindow->IsOpen();
            if (ImGui::MenuItem("Configuration", NULL, &configOpen))
            {
                configWindow->SetOpen(configOpen);
            }

            bool consoleOpen = consoleWindow->IsOpen();
            if (ImGui::MenuItem("Console", NULL, &consoleOpen))
            {
                consoleWindow->SetOpen(consoleOpen);
            }

            bool hierarchyOpen = hierarchyWindow->IsOpen();
            if (ImGui::MenuItem("Hierarchy", NULL, &hierarchyOpen))
            {
                hierarchyWindow->SetOpen(hierarchyOpen);
            }

            bool inspectorOpen = inspectorWindow->IsOpen();
            if (ImGui::MenuItem("Inspector", NULL, &inspectorOpen))
            {
                inspectorWindow->SetOpen(inspectorOpen);
            }

            bool assetsOpen = assetsWindow->IsOpen();
            if (ImGui::MenuItem("Assets", NULL, &assetsOpen))
            {
                assetsWindow->SetOpen(assetsOpen);
            }

            if (assetsWindow->scriptEditorWindow)
            {
                bool scriptEditorOpen = assetsWindow->scriptEditorWindow->IsOpen();
                if (ImGui::MenuItem("Script Editor", NULL, &scriptEditorOpen))
                {
                    assetsWindow->scriptEditorWindow->SetOpen(scriptEditorOpen);
                }
            }

            bool shaderEditorOpen = shaderEditorWindow->IsOpen();
            if (ImGui::MenuItem("Shader Editor", NULL, &shaderEditorOpen))
            {
                shaderEditorWindow->SetOpen(shaderEditorOpen);
            }

            ImGui::Separator();

            if (ImGui::BeginMenu("Layout"))
            {
                if (ImGui::MenuItem("Save Layout As..."))
                {
                    showSaveLayoutPopup = true;
                }

                ImGui::Separator();

                // Load saved layouts
                std::vector<std::string> savedLayouts = GetSavedLayouts();
                if (!savedLayouts.empty())
                {
                    ImGui::Text("Saved Layouts:");
                    for (const auto& layout : savedLayouts)
                    {
                        bool isCurrentLayout = (layout == currentLayoutFile);
                        if (ImGui::MenuItem(layout.c_str(), nullptr, isCurrentLayout))
                        {
                            LoadLayout(layout);
                        }
                    }
                }
                else
                {
                    ImGui::TextDisabled("No saved layouts");
                }

                ImGui::Separator();

                // Auto save 
                if (ImGui::MenuItem("Auto save Layout", nullptr, &autoSaveLayout))
                {
                    ImGuiIO& io = ImGui::GetIO();
                    if (autoSaveLayout)
                    {
                        std::string layoutPath = layoutDirectory + currentLayoutFile;
                        static std::string layoutPathStatic = layoutPath;
                        io.IniFilename = layoutPathStatic.c_str();
                        LOG_CONSOLE("Auto save enabled");
                    }
                    else
                    {
                        io.IniFilename = nullptr;
                        LOG_CONSOLE("Auto save disabled");
                    }
                }
                ImGui::EndMenu();
            }
            ImGui::EndMenu();
        }


        if (ImGui::BeginMenu("GameObject"))
        {

            if (ImGui::BeginMenu("3D Primitives"))
            {
                if (ImGui::MenuItem("Cube"))
                {
                    CreatePrimitiveGameObject("Cube", Primitives::CreateCube());
                }
                if (ImGui::MenuItem("Pyramid"))
                {
                    CreatePrimitiveGameObject("Pyramid", Primitives::CreatePyramid());
                }
                if (ImGui::MenuItem("Plane"))
                {
                    CreatePrimitiveGameObject("Plane", Primitives::CreatePlane());
                }
                if (ImGui::MenuItem("Sphere"))
                {
                    CreatePrimitiveGameObject("Sphere", Primitives::CreateSphere());
                }
                if (ImGui::MenuItem("Cylinder"))
                {
                    CreatePrimitiveGameObject("Cylinder", Primitives::CreateCylinder());
                }
                ImGui::EndMenu();
            }

            ImGui::Separator();

            if (ImGui::BeginMenu("UI"))
            {
                if (ImGui::MenuItem("Create Canvas"))
                {
                    GameObject* canvasGO = new GameObject("Canvas");
                    canvasGO->CreateComponent(ComponentType::CANVAS);
                    Application::GetInstance().scene->GetRoot()->AddChild(canvasGO);
                    LOG_CONSOLE("Canvas GameObject created");
				}
                ImGui::EndMenu();
            }

            ImGui::Separator();
 
            if (ImGui::MenuItem("Empty GameObject"))
            {
                GameObject* empty = Application::GetInstance().scene->CreateGameObject("GameObject");
                commandHistory->ExecuteCommand(std::make_unique<CreateCommand>(empty));

                Application::GetInstance().selectionManager->SetSelectedObject(empty);
            }
            
            ImGui::Separator();

            if (ImGui::MenuItem("Add Auto Rotate Component"))
            {
                GameObject* selected = Application::GetInstance().selectionManager->GetSelectedObject();
                if (selected != nullptr)
                {
                    selected->CreateComponent(ComponentType::ROTATE);
                    LOG_CONSOLE("Auto Rotate component added to %s", selected->GetName().c_str());
                }
            }

            ImGui::EndMenu();
        }

        if (ImGui::BeginMenu("Help"))
        {
            if (ImGui::MenuItem("Web"))
            {
                SDL_OpenURL("https://audra0000.github.io/Engine/");
            }
            if (ImGui::MenuItem("Documentation"))
            {
                SDL_OpenURL("https://github.com/Audra0000/Engine/blob/main/README.md");
            }
            if (ImGui::MenuItem("Report a Bug"))
            {
                SDL_OpenURL("https://github.com/Audra0000/Engine/issues");
            }
            if (ImGui::MenuItem("Download Latest"))
            {
                SDL_OpenURL("https://github.com/Audra0000/Engine/releases");
            }
            ImGui::Separator();
            if (ImGui::MenuItem("About"))
            {
                showAbout = true;
            }
            ImGui::EndMenu();
        }

        ImGui::Separator();
        ImGui::Checkbox("Snap", &sceneWindow.get()->snapEnabled);
        ImGui::PushItemWidth(80);
        ImGui::DragFloat("Position", &sceneWindow.get()->positionSnap, 0.1f, 0.0f, 100.0f, "%.3fx");
        ImGui::SameLine();
        ImGui::DragFloat("Rotation", &sceneWindow.get()->rotationSnap, 0.1f, 0.0f, 100.0f, "%.3fx");
        ImGui::SameLine();
        ImGui::DragFloat("Scale", &sceneWindow.get()->scaleSnap, 0.1f, 0.0f, 100.0f, "%.3fx");
        ImGui::SameLine();
        
        ImGui::Separator();
        ImGui::Checkbox("Center On Paste", &centerOnPaste);
        ImGui::SameLine();

        if (centerOnPaste)
        {
            ImGui::DragFloat("Paste Distance", &pasteDistance, 0.1f, 1.0f, 100.0f);
            ImGui::SameLine();
        }

        ImGui::EndMenuBar();
    }

    // Save Layout Popup 
    if (showSaveLayoutPopup)
    {
        ImGui::OpenPopup("Save Layout");
        showSaveLayoutPopup = false;
    }

    if (ImGui::BeginPopupModal("Save Layout", nullptr, ImGuiWindowFlags_AlwaysAutoResize))
    {
        ImGui::Text("Enter layout name:");
        ImGui::SetNextItemWidth(300.0f);
        ImGui::InputText("##layoutname", layoutNameBuffer, sizeof(layoutNameBuffer));

        ImGui::Spacing();

        if (ImGui::Button("Save", ImVec2(145, 0)))
        {
            std::string filename = layoutNameBuffer;
			if (filename.find(".ini") == std::string::npos) // npos means not found
            {
                filename += ".ini";
            }
            SaveLayoutAs(filename);
            ImGui::CloseCurrentPopup();
        }
        ImGui::SameLine();
        if (ImGui::Button("Cancel", ImVec2(145, 0)))
        {
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }
}

void ModuleEditor::ShowPlayToolbar()
{
    Application& app = Application::GetInstance();
    Application::PlayState currentState = app.GetPlayState();

    ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(8, 4));
    ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(8, 4));

    // Left side: Play controls
    float windowWidth = ImGui::GetWindowWidth();
    ImGui::SetCursorPosX(10.0f);

    // Play button
    bool isPlaying = currentState == Application::PlayState::PLAYING;
    if (isPlaying) {
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.2f, 0.8f, 0.2f, 1.0f));
    }

    if (ImGui::Button("Play", ImVec2(40, 0))) {
        commandHistory->Clear();
        ObjectsCopy.clear();
        app.Play();
        // Focus the Game window when entering play mode
        if (gameWindow && gameWindow->IsOpen()) {
            ImGui::SetWindowFocus("Game");
        }
    }

    if (isPlaying) {
        ImGui::PopStyleColor();
    }

    ImGui::SameLine();

    // Pause button
    bool isPaused = currentState == Application::PlayState::PAUSED;
    if (isPaused) {
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.8f, 0.2f, 1.0f));
    }

    if (ImGui::Button("Pause", ImVec2(50, 0))) {
        app.Pause();
    }

    if (isPaused) {
        ImGui::PopStyleColor();
    }

    ImGui::SameLine();

    // Stop button
    if (ImGui::Button("Stop", ImVec2(40, 0))) {
        commandHistory->Clear();
        app.Stop();
        if (sceneWindow && sceneWindow->IsOpen()) {
            ImGui::SetWindowFocus("Scene");
        }
    }

    ImGui::SameLine();

    // Step button (only when game is paused or stopped)
    bool canStep = (currentState == Application::PlayState::PAUSED);
    if (!canStep) {
        ImGui::BeginDisabled();
    }

    if (ImGui::Button("Step", ImVec2(40, 0))) {
        app.Step();
    }

    if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) {
        ImGui::SetTooltip("Advance one frame (only when paused)");
    }

    if (!canStep) {
        ImGui::EndDisabled();
    }

    // Center: Time display
    ImGui::SameLine(windowWidth * 0.4f);

    float totalTime = app.time->GetTotalTime();
    float gameTime = app.time->GetGameTime();
    float realDt = app.time->GetRealDeltaTime();
    ImGui::Text("Total: %.2fs | Game: %.2fs | FPS: %.0f", totalTime, gameTime, realDt > 0 ? 1.0f / realDt : 0.0f);

    // Right side: Time scale
    ImGui::SameLine(windowWidth - 220.0f);
    ImGui::Text("Time Scale:");

    ImGui::SameLine();
    float timeScale = app.time->GetTimeScale();
    ImGui::SetNextItemWidth(80.0f);
    if (ImGui::DragFloat("##timescale", &timeScale, 0.05f, 0.0f, 5.0f, "%.2fx")) {
        app.time->SetTimeScale(timeScale);
    }

    if (ImGui::IsItemHovered()) {
        ImGui::SetTooltip("Game speed multiplier\n0.5x = slow motion\n2.0x = fast forward\n5.0x = super fast!");
    }

    ImGui::PopStyleVar(2);
    ImGui::Separator();
}

void ModuleEditor::DrawAboutWindow()
{
    ImGui::Begin("About", &showAbout);

    ImGui::Text("Engine Name: Wave Engine");
    ImGui::Text("Version: 0.1.0");

    ImGui::Separator();

    ImGui::Text("Team Members:");
    ImGui::BulletText("Haosheng Li");
    ImGui::BulletText("Ana Alcaraz");

    ImGui::Separator();

    ImGui::Text("Libraries Used:");

    int sdlVersion = SDL_GetVersion();
    int major = SDL_VERSIONNUM_MAJOR(sdlVersion);
    int minor = SDL_VERSIONNUM_MINOR(sdlVersion);
    int patch = SDL_VERSIONNUM_MICRO(sdlVersion);
    ImGui::BulletText("SDL3: %d.%d.%d", major, minor, patch);

    ImGui::BulletText("OpenGL: %s", glGetString(GL_VERSION));
    ImGui::BulletText("ImGui: %s", IMGUI_VERSION);

    ILint devilVersion = ilGetInteger(IL_VERSION_NUM);
    int devilMajor = devilVersion / 100;
    int devilMinor = (devilVersion / 10) % 10;
    int devilPatch = devilVersion % 10;
    ImGui::BulletText("DevIL: %d.%d.%d", devilMajor, devilMinor, devilPatch);

    ImGui::BulletText("Glad");
    ImGui::BulletText("Glm");
    ImGui::BulletText("Assimp");

    ImGui::Separator();

    ImGui::TextWrapped("MIT License");
    ImGui::Spacing();
    ImGui::TextWrapped("Copyright (c) 2025 Engine");
    ImGui::Spacing();
    ImGui::TextWrapped(
        "Permission is hereby granted, free of charge, to any person obtaining a copy "
        "of this software and associated documentation files (the \"Software\"), to deal "
        "in the Software without restriction, including without limitation the rights "
        "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell "
        "copies of the Software, and to permit persons to whom the Software is "
        "furnished to do so, subject to the following conditions:"
    );
    ImGui::Spacing();
    ImGui::TextWrapped(
        "The above copyright notice and this permission notice shall be included in all "
        "copies or substantial portions of the Software."
    );
    ImGui::Spacing();
    ImGui::TextWrapped(
        "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR "
        "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, "
        "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE "
        "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER "
        "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, "
        "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE "
        "SOFTWARE."
    );

    ImGui::End();
}

void ModuleEditor::CreatePrimitiveGameObject(const std::string& name, Mesh mesh)
{
    GameObject* Object = new GameObject(name);
    ComponentMesh* meshComp = static_cast<ComponentMesh*>(
        Object->CreateComponent(ComponentType::MESH)
        );

    Mesh selectedMesh;

    if (name == "Cube")
        selectedMesh = Primitives::CreateCube();
    else if (name == "Pyramid")
        selectedMesh = Primitives::CreatePyramid();
    else if (name == "Plane")
        selectedMesh = Primitives::CreatePlane();
    else if (name == "Sphere")
        selectedMesh = Primitives::CreateSphere();
    else if (name == "Cylinder")
        selectedMesh = Primitives::CreateCylinder();
    else
        selectedMesh = mesh;

    meshComp->SetMesh(selectedMesh);
    meshComp->SetPrimitiveType(name); 

    ComponentMaterial* materialComp = static_cast<ComponentMaterial*>(
        Object->CreateComponent(ComponentType::MATERIAL)
        );
    materialComp->CreateCheckerboardTexture(); 

    GameObject* root = Application::GetInstance().scene->GetRoot();
    root->AddChild(Object);
    commandHistory->ExecuteCommand(std::make_unique<CreateCommand>(Object));

    Application::GetInstance().scene->RebuildOctree();

    LOG_CONSOLE("%s created", name.c_str());
    LOG_DEBUG("Primitive created: %s", name.c_str());
}

void ModuleEditor::HandleDeleteKey()
{
    if (ImGui::IsKeyPressed(ImGuiKey_Delete) || ImGui::IsKeyPressed(ImGuiKey_Backspace))
    {
        if (ImGui::GetIO().WantTextInput) return;

        std::vector<GameObject*> selectedObjects =
            Application::GetInstance().selectionManager->GetSelectedObjects();

        std::vector<GameObject*> candidates;
        GameObject* sceneRoot = Application::GetInstance().scene->GetRoot();
        for (GameObject* obj : selectedObjects)
        {
            if (obj && obj != sceneRoot && obj->GetParent())
                candidates.push_back(obj);
        }

        if (candidates.empty()) return;

        auto IsAncestorSelected = [&](GameObject* obj) -> bool
            {
                GameObject* current = obj->GetParent();
                while (current && current != sceneRoot)
                {
                    for (GameObject* candidate : candidates)
                    {
                        if (candidate == current) return true;
                    }
                    current = current->GetParent();
                }
                return false;
            };

        std::vector<GameObject*> toDelete;
        for (GameObject* obj : candidates)
        {
            if (!IsAncestorSelected(obj))
                toDelete.push_back(obj);
        }

        if (toDelete.empty()) return;

        Application::GetInstance().selectionManager->ClearSelection();

        auto composite = std::make_unique<CompositeCommand>();
        for (GameObject* obj : toDelete)
        {
            composite->AddCommand(std::make_unique<DeleteCommand>(obj));
        }

        commandHistory->ExecuteCommand(std::move(composite));

        LOG_CONSOLE("GameObject(s) deleted: %d", (int)toDelete.size());
    }
}

bool ModuleEditor::ShouldShowVertexNormals() const
{
    if (inspectorWindow)
        return inspectorWindow->ShouldShowVertexNormals();
    return false;
}

bool ModuleEditor::ShouldShowFaceNormals() const
{
    if (inspectorWindow)
        return inspectorWindow->ShouldShowFaceNormals();
    return false;
}

bool ModuleEditor::ShouldShowAABB() const
{
    if (configWindow)
        return configWindow->ShouldShowAABB();
    return false;
}

bool ModuleEditor::ShouldShowOctree() const
{
    if (configWindow)
        return configWindow->ShouldShowOctree();
    return false;
}

bool ModuleEditor::ShouldShowRaycast() const
{
    if (configWindow)
        return configWindow->ShouldShowRaycast();
    return false;
}

void ModuleEditor::UpdateCurrentWindow()
{
    ImVec2 mousePos = ImGui::GetMousePos();

    isMouseOverSceneViewport = false;

    currentWindow = lastHoveredWindow;
    lastHoveredWindow = EditorWindowType::NONE;

    if (sceneWindow && sceneWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::SCENE;
    }

    if (configWindow && configWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::CONFIGURATION;
    }

    if (inspectorWindow && inspectorWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::INSPECTOR;
    }

    if (consoleWindow && consoleWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::CONSOLE;
    }

    if (hierarchyWindow && hierarchyWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::HIERARCHY;
    }

    if (assetsWindow && assetsWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::ASSETS;
    }

    if (shaderEditorWindow && shaderEditorWindow->IsHovered()) {
        lastHoveredWindow = EditorWindowType::SHADER_EDITOR;
    }

    if (lastHoveredWindow != EditorWindowType::NONE) {
        currentWindow = lastHoveredWindow;
    }

    if (currentWindow == EditorWindowType::SCENE || currentWindow == EditorWindowType::NONE)
    {
        if (mousePos.x >= sceneViewportPos.x &&
            mousePos.x <= sceneViewportPos.x + sceneViewportSize.x &&
            mousePos.y >= sceneViewportPos.y &&
            mousePos.y <= sceneViewportPos.y + sceneViewportSize.y)
        {
            currentWindow = EditorWindowType::SCENE;
            isMouseOverSceneViewport = true;
        }
    }
}

bool ModuleEditor::IsMouseOverScene() const
{
    return isMouseOverSceneViewport;
}

const char* ModuleEditor::EditorWindowTypeToString(EditorWindowType type)
{
    switch (type)
    {
    case EditorWindowType::NONE:           return "NONE";
    case EditorWindowType::SCENE:          return "SCENE";
    case EditorWindowType::CONFIGURATION:  return "CONFIGURATION";
    case EditorWindowType::HIERARCHY:      return "HIERARCHY";
    case EditorWindowType::INSPECTOR:      return "INSPECTOR";
    case EditorWindowType::CONSOLE:        return "CONSOLE";
    case EditorWindowType::ABOUT:          return "ABOUT";
    default:                               return "UNKNOWN";
    }
}

void ModuleEditor::SaveLayoutAs(const std::string& filename)
{
    std::string fullPath = layoutDirectory + filename;

    std::filesystem::create_directories(layoutDirectory);

    ImGui::SaveIniSettingsToDisk(fullPath.c_str());
    currentLayoutFile = filename;
    LOG_CONSOLE("Layout saved to %s", fullPath.c_str());
}

void ModuleEditor::LoadLayout(const std::string& filename)
{
    std::string fullPath = layoutDirectory + filename;

    if (std::filesystem::exists(fullPath))
    {
        ImGui::LoadIniSettingsFromDisk(fullPath.c_str());
        currentLayoutFile = filename;
        LOG_CONSOLE("Layout loaded from %s", fullPath.c_str());
    }
    else
    {
        LOG_CONSOLE("Layout file not found: %s", fullPath.c_str());
    }
}

std::vector<std::string> ModuleEditor::GetSavedLayouts()
{
    std::vector<std::string> layouts;

    if (!std::filesystem::exists(layoutDirectory))
    {
        return layouts;
    }

    for (const auto& entry : std::filesystem::directory_iterator(layoutDirectory))
    { 
        // is_regular_file: check if is a file 
        // extension: check for example my_layout.ini has .ini extension
		if (entry.is_regular_file() && entry.path().extension() == ".ini") 
        {
            layouts.push_back(entry.path().filename().string());
        }
    }

    return layouts;
}

std::string ModuleEditor::OpenSaveFile(const std::string& defaultPath)
{
    OPENFILENAMEA ofn;
    char szFile[260] = { 0 };

    std::string sceneDir;
	if (!defaultPath.empty()) // Default path
        sceneDir = defaultPath;
	else // Current path
        sceneDir = (std::filesystem::current_path().parent_path().parent_path() / "Scene").string();

    ZeroMemory(&ofn, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn); 
    ofn.hwndOwner = NULL;
    ofn.lpstrFile = szFile; // Path
    ofn.nMaxFile = sizeof(szFile); // Path size
    ofn.lpstrFilter = "JSON Files\0*.json\0All Files\0*.*\0";
	ofn.nFilterIndex = 1; // Default filter: .json
	ofn.lpstrFileTitle = NULL; // Filename
    ofn.nMaxFileTitle = 0; 
	ofn.lpstrInitialDir = sceneDir.c_str(); // Open on
	ofn.lpstrDefExt = "json"; // Default extension if not specified
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_OVERWRITEPROMPT; // Folder must exist, prompt if overwriting

    if (GetSaveFileNameA(&ofn) == TRUE)
    {
        return std::string(ofn.lpstrFile);
    }

    return ""; // User cancelled
}

std::string ModuleEditor::OpenLoadFile(const std::string& defaultPath)
{
    OPENFILENAMEA ofn;
    char szFile[260] = { 0 };

    std::string sceneDir;
    if (!defaultPath.empty()) // Default path
        sceneDir = defaultPath;
    else // Current path
        sceneDir = (std::filesystem::current_path().parent_path().parent_path() / "Scene").string();

    ZeroMemory(&ofn, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = NULL;
    ofn.lpstrFile = szFile;
    ofn.nMaxFile = sizeof(szFile);
    ofn.lpstrFilter = "JSON Files\0*.json\0All Files\0*.*\0";
    ofn.nFilterIndex = 1;
    ofn.lpstrFileTitle = NULL;
    ofn.nMaxFileTitle = 0;
    ofn.lpstrInitialDir = sceneDir.c_str();
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

    if (GetOpenFileNameA(&ofn) == TRUE)
    {
        return std::string(ofn.lpstrFile);
    }

    return ""; // User cancelled


}


void ModuleEditor::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::EventSDL:
    {
        ImGui_ImplSDL3_ProcessEvent(event.data.event.event);
        break;
    }
    case Event::Type::CastRay:
    {
        //startLastRay = event.data.ray.ray->origin;
        //endLastRay = event.data.ray.ray->origin + (event.data.ray.ray->direction * 100.0f);
        break;
    }
    case Event::Type::SceneCleared:
    {
        /*selectedGameObjects.clear();*/
        break;
    }
    case Event::Type::GameObjectDestroyed:
    {
        /*GameObject* destroyedGO = event.data.gameObject.gameObject;

        auto it = std::remove(selectedGameObjects.begin(), selectedGameObjects.end(), destroyedGO);

        if (it != selectedGameObjects.end())
        {
            selectedGameObjects.erase(it, selectedGameObjects.end());
        }
        break;*/
    }
    default:
        break;
    }
}

std::string ModuleEditor::OpenFolderDialog()
{
    std::string result; // string use UTF-8, while windows use UTF-16
    // HRESULT is a Windows API type used for error handling.
	// CoInitializeEx initializes the COM(Component Object Model. Basically a system created by windows to act has intermediary) library for use by the calling thread.
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED); 
    if (FAILED(hr)) return result;

	IFileDialog* pDialog = nullptr; 
    hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL, IID_IFileDialog, (void**)&pDialog); // https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-cocreateinstance
    if (SUCCEEDED(hr))
    {
        // Create the file dialog 
        DWORD options;
        pDialog->GetOptions(&options);
		pDialog->SetOptions(options | FOS_PICKFOLDERS); // FOS_PICKFOLDERS: only select folders
        pDialog->SetTitle(L"Select Export Folder"); // L means wchar_t*, windows use UTF-16 

        // Show the dialog 
		hr = pDialog->Show(NULL); // NULL means that the dialog has no parent window
        if (SUCCEEDED(hr))
        {
            IShellItem* pItem = nullptr; // IShellItem stores the selected folder
            hr = pDialog->GetResult(&pItem);
            if (SUCCEEDED(hr))
            {
                PWSTR pszPath = nullptr; // Store the folder path
                hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszPath); // Function to get the path
                if (SUCCEEDED(hr))
                {
                    int len = WideCharToMultiByte(CP_UTF8, 0, pszPath, -1, NULL, 0, NULL, NULL); 
                    result.resize(len - 1); // remove \0
					WideCharToMultiByte(CP_UTF8, 0, pszPath, -1, &result[0], len, NULL, NULL); // Convert from UTF-16 to UTF-8
                    CoTaskMemFree(pszPath);
                }
                pItem->Release();
            }
        }
        pDialog->Release();
    }

    CoUninitialize();
    return result;
}

void ModuleEditor::BuildGame()
{
    std::string destFolder = OpenFolderDialog();
    if (destFolder.empty())
    {
        LOG_CONSOLE("[Build] Export cancelled.");
        return;
    }

    namespace fs = std::filesystem;
    fs::path dest(destFolder); // https://en.cppreference.com/w/cpp/filesystem/path

    // Search the exe directory
    char exePath[MAX_PATH]; // Windows has a MAX_PATH limit of 260 characters
    GetModuleFileNameA(NULL, exePath, MAX_PATH); // https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-getmodulefilenamea
    fs::path exeDir = fs::path(exePath).parent_path();
	// Example: exePath = C:\WaveEngine\Engine\build\Release\Engine.exe --> exeDir = C:\WaveEngine\Engine\build\Release

    fs::path gameExeSrc = exeDir / "Game.exe";
    if (!fs::exists(gameExeSrc))
    {
        LOG_CONSOLE("[Build] ERROR: Game.exe not found at %s", gameExeSrc.string().c_str());
        return;
    }

    try 
    {
        // Copy Game.exe
        fs::copy_file(gameExeSrc, dest / "Game.exe", fs::copy_options::overwrite_existing); // https://en.cppreference.com/w/cpp/filesystem/copy_file
        LOG_CONSOLE("[Build] Copied Game.exe");

        // Copy all dlls 
        int dllCount = 0;
        for (const auto& entry : fs::directory_iterator(exeDir)) // https://en.cppreference.com/w/cpp/filesystem/directory_iterator
        {
			if (entry.is_regular_file() && entry.path().extension() == ".dll") // is a file and has .dll
            {
                fs::copy_file(entry.path(), dest / entry.path().filename(), fs::copy_options::overwrite_existing);
                dllCount++;
            }
        }
        LOG_CONSOLE("[Build] Copied %d DLL(s)", dllCount);

        // Copy Assets/ folder
        fs::path assetsSrc(LibraryManager::GetAssetsRoot());
        if (fs::exists(assetsSrc))
        {
            fs::copy(assetsSrc, dest / "Assets", fs::copy_options::overwrite_existing | fs::copy_options::recursive);
            LOG_CONSOLE("[Build] Copied Assets/ folder");
        }
        else
        {
            LOG_CONSOLE("[Build] WARNING: Assetsfolder not found");
        }

        // Copy Library/ folder
        fs::path libRoot(LibraryManager::GetLibraryRoot());
        if (fs::exists(libRoot))
        {
            fs::copy(libRoot, dest / "Library", fs::copy_options::overwrite_existing | fs::copy_options::recursive);
            LOG_CONSOLE("[Build] Copied Library/ folder");
        }
        else
        {
            LOG_CONSOLE("[Build] WARNING: Library folder not found");
        }

        // Export scene
        fs::create_directories(dest / "Scene");
        fs::path projectRoot = fs::path(LibraryManager::GetLibraryRoot()).parent_path();
        std::string sceneFolder = (projectRoot / "Scene").string();
        std::string sceneSrc = OpenLoadFile(sceneFolder);
        std::string startupSceneName;
        if (!sceneSrc.empty())
        {
            fs::path sceneFilename = fs::path(sceneSrc).filename();
            fs::copy_file(sceneSrc, dest / "Scene" / sceneFilename, fs::copy_options::overwrite_existing);
            startupSceneName = sceneFilename.string();
            LOG_CONSOLE("[Build] Copied scene '%s'", startupSceneName.c_str());
        }
        else
        {
            startupSceneName = "game_scene.json";
            std::string sceneDestPath = (dest / "Scene" / startupSceneName).string();
            Application::GetInstance().scene->SaveScene(sceneDestPath);
            LOG_CONSOLE("[Build] No scene selected, saved current scene");
        }

        nlohmann::json config;
        config["startup_scene"] = startupSceneName;
        std::ofstream configFile(dest / "build_config.json");
        configFile << config.dump(4);
        LOG_CONSOLE("[Build] Export complete %s", destFolder.c_str());
    }
    catch (const std::exception& error)
    {
        LOG_CONSOLE("[Build] ERROR: %s", error.what());
    }
}
void ModuleEditor::HandleUndoRedo()
{
    ImGuiIO& io = ImGui::GetIO();
    if (io.WantTextInput) return;

    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_Z, false))
        commandHistory->Undo();

    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_Y, false))
        commandHistory->Redo();
}

void ModuleEditor::HandleCopyPaste()
{
    ImGuiIO& io = ImGui::GetIO();
    if (io.WantTextInput) return;
    
    //copy (ctrl c)
    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_C, false))
        ObjectsCopy = Application::GetInstance().selectionManager->GetFilteredObjects();

    //paste (ctrl v)
    if ((io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_V, false)) && !ObjectsCopy.empty())
    {
        GameObject* root = Application::GetInstance().scene->GetRoot();
        Application::GetInstance().selectionManager->ClearSelection();

        //center pos option
        glm::vec3 centerPos(0.0f);
        
        if (centerOnPaste)
        {
            EditorCamera* editorCam = Application::GetInstance().editor->GetEditorCamera();

            if (editorCam)
            {
                CameraLens* camLens = editorCam->GetCameraLens();
                glm::vec3 camPos = camLens->position;
                glm::vec3 camForward = editorCam->forward;
                centerPos = camPos + camForward * pasteDistance;
            }
        }

        auto composite = std::make_unique<CompositeCommand>();

        for (GameObject* obj : ObjectsCopy)
        {
            GameObject* clonedObject = CloneGameObject(obj);

            if (centerOnPaste)
                clonedObject->transform->SetPosition(centerPos);

            root->AddChild(clonedObject);
            ischild = false;

            Application::GetInstance().selectionManager->AddToSelection(clonedObject);
            composite->AddCommand(std::make_unique<CreateCommand>(clonedObject));
        }

        commandHistory->PushWithoutExecute(std::move(composite));
        Application::GetInstance().scene->RebuildOctree();
    }

    //cut (ctrl x)
    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_X, false))
    {
        std::vector<GameObject*> toCut =
            Application::GetInstance().selectionManager->GetFilteredObjects();

        if (!toCut.empty())
        {
            ObjectsCopy = toCut;

            Application::GetInstance().selectionManager->ClearSelection();

            auto composite = std::make_unique<CompositeCommand>();
            for (GameObject* obj : toCut)
            {
                if (obj && obj != Application::GetInstance().scene->GetRoot() && obj->GetParent())
                    composite->AddCommand(std::make_unique<DeleteCommand>(obj));
            }
            commandHistory->ExecuteCommand(std::move(composite));
        }
    }

    //duplicate (ctrl d)
    if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_D, false))
    {
        std::vector<GameObject*> toClone =
            Application::GetInstance().selectionManager->GetFilteredObjects();

        if (!toClone.empty())
        {
            GameObject* root = Application::GetInstance().scene->GetRoot();
            Application::GetInstance().selectionManager->ClearSelection();

            auto composite = std::make_unique<CompositeCommand>();

            for (GameObject* obj : toClone)
            {
                GameObject* cloned = CloneGameObject(obj);
                root->AddChild(cloned);
                Application::GetInstance().selectionManager->AddToSelection(cloned);
                composite->AddCommand(std::make_unique<CreateCommand>(cloned));
            }

            commandHistory->PushWithoutExecute(std::move(composite));
            Application::GetInstance().scene->RebuildOctree();
        }
    }
}

GameObject* ModuleEditor::CloneGameObject(GameObject* original)
{
    std::string name = original->GetName() + "_copy";
    GameObject* clone = new GameObject(name.c_str());

    Transform* originalTransform =
        (Transform*)original->GetComponent(ComponentType::TRANSFORM);
   
    clone->transform->SetGlobalPosition(originalTransform->GetGlobalPosition());
    clone->transform->SetGlobalScale(originalTransform->GetGlobalScale());
    clone->transform->SetGlobalRotation(originalTransform->GetGlobalRotation());

    if (ischild)
    {
        clone->transform->SetPosition(originalTransform->GetPosition());
        clone->transform->SetScale(originalTransform->GetScale());
        clone->transform->SetRotation(originalTransform->GetRotation());
    }

    if (original->GetComponent(ComponentType::MESH))
    {
        ComponentMesh* originalMesh =
            (ComponentMesh*)original->GetComponent(ComponentType::MESH);

        ComponentMesh* newMesh =
            (ComponentMesh*)clone->CreateComponent(ComponentType::MESH);

        newMesh->SetMesh(originalMesh->GetMesh());
        newMesh->SetPrimitiveType(name);
    }

    if (original->GetComponent(ComponentType::MATERIAL))
    {
        ComponentMaterial* originalMaterial =
            (ComponentMaterial*)original->GetComponent(ComponentType::MATERIAL);

        ComponentMaterial* newMaterial =
            (ComponentMaterial*)clone->CreateComponent(ComponentType::MATERIAL);
        UID tempUid = originalMaterial->GetTextureUID();
        if(tempUid !=0)newMaterial->LoadTextureByUID(tempUid);
    
        newMaterial->SetDiffuseColor(originalMaterial->GetDiffuseColor());
    }
    if (original->GetComponent(ComponentType::SCRIPT))
    {
        ComponentScript * originalScript =
            (ComponentScript*)original->GetComponent(ComponentType::SCRIPT);

        ComponentScript* newScript =
            (ComponentScript*)clone->CreateComponent(ComponentType::SCRIPT);

        newScript->LoadScriptByUID(originalScript->GetScriptUID());
    }
    for (GameObject* child : original->GetChildren())
    {
        ischild = true;
        GameObject* childClone = CloneGameObject(child);
        clone->AddChild(childClone);
    }
    ischild = false;

    return clone;
}
