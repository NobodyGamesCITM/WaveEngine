#include "Application.h"
#include <iostream>
#include <chrono>
#include <filesystem>
#include <fstream>
#include "LibraryManager.h"
#include "FileSystem.h"
#ifdef WAVE_GAME
#include <nlohmann/json.hpp>
#include <windows.h>
#endif
#include "UIManager.h"
#include "ComponentScript.h"
#include "Backup.h" 

Application::Application() : isRunning(true), playState(PlayState::EDITING)
{
    LOG_DEBUG("=== Creating Application Instance ===");
    LOG_CONSOLE("Starting engine...");

    window = std::make_shared<Window>();
    events = std::make_shared<ModuleEvents>();
    input = std::make_shared<Input>();
    renderContext = std::make_shared<RenderContext>();
    renderer = std::make_shared<Renderer>();
    scene = std::make_shared<ModuleScene>();
    camera = std::make_shared<ModuleCamera>();
    audio = std::make_shared<ModuleAudio>();
    loader = std::make_shared<ModuleLoader>();
    time = std::make_shared<Time>();
    grid = std::make_shared<Grid>();
    resources = std::make_shared<ModuleResources>();
    ui = std::make_shared<UI>();
    scripts = std::make_shared<ScriptManager>();  
    physics = std::make_shared<ModulePhysics>();
    navMesh = std::make_shared<ModuleNavMesh>();
#ifndef WAVE_GAME
    editor = std::make_shared<ModuleEditor>();
    backup = std::make_shared<Backup>();
#else
    game = std::make_shared<ModuleGame>();
#endif

    AddModule(std::static_pointer_cast<Module>(window));
    AddModule(std::static_pointer_cast<Module>(events));
    AddModule(std::static_pointer_cast<Module>(input));
    AddModule(std::static_pointer_cast<Module>(physics));
    AddModule(std::static_pointer_cast<Module>(renderContext));
    AddModule(std::static_pointer_cast<Module>(scene));
    AddModule(std::static_pointer_cast<Module>(camera));
    AddModule(std::static_pointer_cast<Module>(resources));
    AddModule(std::static_pointer_cast<Module>(audio));
    AddModule(std::static_pointer_cast<Module>(navMesh));
    AddModule(std::static_pointer_cast<Module>(scripts));  
    AddModule(std::static_pointer_cast<Module>(loader));
    AddModule(std::static_pointer_cast<Module>(time));
    AddModule(std::static_pointer_cast<Module>(grid));
    AddModule(std::static_pointer_cast<Module>(ui));
    AddModule(std::static_pointer_cast<Module>(renderer));
#ifndef WAVE_GAME
    AddModule(std::static_pointer_cast<Module>(editor));
    AddModule(std::static_pointer_cast<Backup>(backup));
#else
    AddModule(std::static_pointer_cast<Module>(game));
#endif

    selectionManager = new SelectionManager();
}
Application& Application::GetInstance()
{
    static Application instance;
    return instance;
}

void Application::AddModule(std::shared_ptr<Module> module)
{
    moduleList.push_back(module);
}

bool Application::Awake()
{
    return true;
}

bool Application::Start()
{
    LOG_CONSOLE("Starting engine modules...");
    LOG_CONSOLE("========================================");

    FileSystem::Initialize();

    auto totalStart = std::chrono::high_resolution_clock::now();

    bool result = true;
    for (const auto& module : moduleList) {
        auto moduleStart = std::chrono::high_resolution_clock::now();

        LOG_CONSOLE("Initializing: %s...", module->name.c_str());

        result = module.get()->Start();

        auto moduleEnd = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(moduleEnd - moduleStart).count();

        LOG_CONSOLE("  -> %s: %lld ms", module->name.c_str(), duration);

        if (!result) {
            LOG_DEBUG("ERROR: Module failed to start: %s", module->name.c_str());
            LOG_CONSOLE("ERROR: Failed to initialize module: %s", module->name.c_str());
            break;
        }
    }

    auto totalEnd = std::chrono::high_resolution_clock::now();
    auto totalDuration = std::chrono::duration_cast<std::chrono::milliseconds>(totalEnd - totalStart).count();

    LOG_CONSOLE("========================================");
    LOG_CONSOLE("TOTAL INIT TIME: %lld ms", totalDuration);
    LOG_CONSOLE("========================================");

    if (result)
    {
        LOG_CONSOLE("Engine ready - All systems initialized");
    }

#ifdef WAVE_GAME
    // Load scene and start in play mode
    if (result)
    {
        std::filesystem::path projectRoot = std::filesystem::path(FileSystem::GetLibraryRoot()).parent_path(); // Example: /WaveEngine/Engine/Build then --> /WaveEngine/Engine

        char exeBuffer[MAX_PATH];
        GetModuleFileNameA(NULL, exeBuffer, MAX_PATH);
        std::filesystem::path execDir = std::filesystem::path(exeBuffer).parent_path();

        LOG_CONSOLE("[Game] Loaded scene: %s", execDir.generic_string().c_str());

        UID startupScene = 0;
        std::filesystem::path configPath = execDir / "build_config.json";

        LOG_CONSOLE("[Game] Loaded scene: %s", configPath.generic_string().c_str());
        if (std::filesystem::exists(configPath))
        {
            std::ifstream f(configPath);
            nlohmann::json config = nlohmann::json::parse(f);
            if (config.contains("startup_scene"))
                startupScene = config["startup_scene"].get<UID>();
        }

        if (loader->LoadScene(startupScene))
        {
            LOG_CONSOLE("[Game] Loaded scene: %llu", startupScene);
            int w = 0, h = 0;
            window->GetWindowSize(w, h);
            events->PublishImmediate(Event(Event::Type::WindowResize, w, h));
        }
        else
        {
            LOG_CONSOLE("[Game] WARNING: Could not load scene: %llu", startupScene);
        }

        //std::string scenePath = (projectRoot / "Scene" / startupScene).string();
       


        std::function<void(GameObject*)> callStartOnAll = [&](GameObject* obj) {
            if (!obj || !obj->IsActive()) return;
            for (Component* comp : obj->GetComponents()) {
                if (comp->GetType() == ComponentType::SCRIPT) {
                    ComponentScript* script = static_cast<ComponentScript*>(comp);
                    if (script->IsActive()) {
                        script->CallStart();
                    }
                }
            }
            for (GameObject* child : obj->GetChildren()) {
                callStartOnAll(child);
            }
        };
        callStartOnAll(scene->GetRoot());

        playState = PlayState::PLAYING;
        time->Resume();
        LOG_CONSOLE("[Game] Play state: PLAYING");
    }
#endif

    return true;
}

bool Application::Update()
{
    // Check if exit was requested from menu first
    if (!isRunning) {
        LOG_DEBUG("Exit requested by user");
        LOG_CONSOLE("Shutting down...");
        return false;
    }

    bool ret = true;

    if (input->GetWindowEvent(WE_QUIT) == true) {
        LOG_DEBUG("Window close event detected");
        LOG_CONSOLE("Shutting down...");
        ret = false;
    }

    if (ret == true)
        ret = PreUpdate();

    if (ret == true)
        ret = DoUpdate();

    if (ret == true)
        ret = PostUpdate();

    return ret;
}

bool Application::FixedUpdate()
{
    if (playState == PlayState::PAUSED) {
        return true;
    }

    bool result = true;
    for (const auto& module : moduleList) {
        result = module.get()->FixedUpdate();
        if (!result) {
            break;
        }
    }

    return result;
}

bool Application::PreUpdate()
{
    //Iterates the module list and calls PreUpdate on each module
    bool result = true;
    for (const auto& module : moduleList) {
        result = module.get()->PreUpdate();
        if (!result) {
            break;
        }
    }

    return result;
}

// Call modules on each loop iteration
bool Application::DoUpdate()
{
    bool result = true;
    for (const auto& module : moduleList) {
#ifndef WAVE_GAME
        if (playState == PlayState::EDITING && module == scene) {
            continue;
        }
#endif
        result = module.get()->Update();
        if (!result) break;
    }
    return result;
}

// Call modules after each loop iteration
bool Application::PostUpdate()
{
    //Iterates the module list and calls PostUpdate on each module
    bool result = true;

    if (scripts) scripts->PostUpdate();

    for (const auto& module : moduleList) {
        if (module == window || module == scripts) {
            continue;
        }

        result = module.get()->PostUpdate();
        if (!result) {
            break;
        }
    }

    // Limpiar el estado de los botones pulsados en este frame
    UIManager::GetInstance().ClearFrameClicks();
    // Limpiar el estado de los botones en focus en este frame
    UIManager::GetInstance().ClearFrameFocused();

    if (result) {
        result = window->PostUpdate();
    }

    return result;
}

void Application::Play()
{
    bool wasEditing = (playState == PlayState::EDITING);

    if (wasEditing) {
        LOG_CONSOLE("Saving scene state to memory...");
        savedSceneState = scene->SerializeSceneToString();
    }

    playState = PlayState::PLAYING;

    if (wasEditing)
    {
        // Llamar Start en todos los scripts de la escena
        std::function<void(GameObject*)> callStartOnAll = [&](GameObject* obj) {
            if (!obj || !obj->IsActive()) return;
            for (Component* comp : obj->GetComponents()) {
                if (comp->GetType() == ComponentType::SCRIPT) {
                    ComponentScript* script = static_cast<ComponentScript*>(comp);
                    if (script->IsActive()) {
                        script->CallStart();
                    }
                }
            }
            for (GameObject* child : obj->GetChildren()) {
                callStartOnAll(child);
            }
        };
        callStartOnAll(scene->GetRoot());
    }

    time->Resume();
    AK::SoundEngine::WakeupFromSuspend();
}

void Application::Pause()
{
    playState = PlayState::PAUSED;
    
    time->Pause();

    AK::SoundEngine::Suspend();
}

void Application::PauseGameOnly()
{
    playState = PlayState::PAUSED;

    time->Pause();
    AK::SoundEngine::RenderAudio();
}

void Application::Stop()
{
    // Procesar operaciones pendientes de scripts ANTES de restaurar
    if (scripts) {
        scripts->PostUpdate();
    }

    // Limpiar objetos marcados para eliminación
    if (scene) {
        scene->CleanupMarkedObjects(scene->GetRoot());
    }

    // Restore from memory
    if (playState != PlayState::EDITING && !savedSceneState.empty()) {
        LOG_CONSOLE("Restoring scene from memory...");
        scene->DeserializeSceneFromString(savedSceneState);
    }

    playState = PlayState::EDITING;
    time->Reset();
    time->Pause();
    audio->audioSystem->StopAllAudio();
}

void Application::Step()
{
    if (playState != PlayState::EDITING)
    {
        time->StepFrame();
    }
}

bool Application::CleanUp()
{
    LOG_DEBUG("=== Cleaning Up Application ===");
    LOG_CONSOLE("Cleaning up modules...");

    bool result = true;

    for (auto it = moduleList.rbegin(); it != moduleList.rend(); ++it) {
        result = (*it)->CleanUp();
        if (!result) {
            LOG_DEBUG("ERROR: Module failed CleanUp: %s", (*it)->name.c_str());
        }
    }

    moduleList.clear();

#ifndef WAVE_GAME
    editor.reset();
#endif
    camera.reset();
    scene.reset();
    renderer.reset();
    grid.reset();
    time.reset();
    loader.reset();
    scripts.reset();
    renderContext.reset();
    physics.reset();
    input.reset();
    window.reset();
    resources.reset();
    audio.reset();

    delete selectionManager;
    selectionManager = nullptr;

    ConsoleLog::GetInstance().Shutdown();

    LOG_DEBUG("=== Application Cleanup Complete ===");
    LOG_CONSOLE("Shutdown complete");
    return result;
}