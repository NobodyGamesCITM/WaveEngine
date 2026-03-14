#pragma once

#include <memory>
#include <list>
#include "Window.h"
#include "Module.h"
#include "Input.h"
#include "RenderContext.h"
#include "Renderer.h"
#include "ModuleLoader.h"
#include "Time.h"
#include "ModuleScene.h"
#include "Grid.h"
#ifndef WAVE_GAME
#include "ModuleEditor.h"
#include "Backup.h"
#else
#include "ModuleGame.h"
#endif
#include "SelectionManager.h"
#include "ModuleCamera.h" 
#include "UI.h"
#include "ModuleResources.h"
#include "ScriptManager.h"  
#include "ModulePhysics.h"
#include "NavMeshManager.h"
#include "ModuleAudio.h"
#include "ModuleEvents.h"

class Module;

class Application
{
public:
    // Singleton instance
    static Application& GetInstance();

    // Called before render is available
    bool Awake();

    // Called before the first frame
    bool Start();

    // Called each loop iteration
    bool Update();
    
    // Called each physics loop iteration
    bool FixedUpdate();

    // Called before quitting
    bool CleanUp();

    // Request application exit
    void RequestExit() { isRunning = false; }

    // Play mode control
    enum class PlayState
    {
        EDITING,
        PLAYING,
        PAUSED
    };

    void Play();
    void Pause();
    void PauseGameOnly();
    void Stop();
	void Resume() { if (playState == PlayState::PAUSED) playState = PlayState::PLAYING; }
    void Step();
    PlayState GetPlayState() const { return playState; }

    // Modules
    std::shared_ptr<Window> window;
    std::shared_ptr<Input> input;
    std::shared_ptr<RenderContext> renderContext;
    std::shared_ptr<Renderer> renderer;
    std::shared_ptr<ModuleEvents> events;
    
    std::shared_ptr<ModuleLoader> loader;
    
    std::shared_ptr<Time> time;
    std::shared_ptr<ModuleScene> scene;
    std::shared_ptr<ModuleCamera> camera;
#ifndef WAVE_GAME
    std::shared_ptr<ModuleEditor> editor;
    std::shared_ptr<Backup> backup;
#else
    std::shared_ptr<ModuleGame> game;
#endif
    std::shared_ptr<ModuleAudio> audio;
    std::shared_ptr<Grid> grid;
    std::shared_ptr<ModuleResources> resources;
    std::shared_ptr<UI> ui;
    std::shared_ptr<ScriptManager> scripts; 
    std::shared_ptr<ModuleNavMesh> navMesh;
    std::shared_ptr<ModulePhysics> physics; 
    

    SelectionManager* selectionManager;

private:
    // Private constructor for singleton
    Application();
    ~Application() = default;

    // Delete copy constructor and assignment
    Application(const Application&) = delete;
    Application& operator=(const Application&) = delete;

    void AddModule(std::shared_ptr<Module> module);
    std::list<std::shared_ptr<Module>> moduleList;

    bool isRunning;
    PlayState playState;
    
    // Scene state saved in memory for Play/Stop
    std::string savedSceneState;  

    // Call modules before each loop iteration
    bool PreUpdate();

    // Call modules on each loop iteration
    bool DoUpdate();

    // Call modules after each loop iteration
    bool PostUpdate();

public:

    enum EngineState
    {
        CREATE = 1,
        AWAKE,
        START,
        LOOP,
        CLEAN,
        FAIL,
        EXIT
    };

};