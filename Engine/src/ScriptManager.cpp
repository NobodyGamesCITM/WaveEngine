#include "ScriptManager.h"
#include "Application.h"
#include "Input.h"
#include "Time.h"
#include "Log.h"
#include "Transform.h"
#include "GameObject.h"
#include "Component.h"
#include "ModuleScene.h"
#include "ComponentMesh.h"
#include "ComponentMaterial.h"
#include "ComponentScript.h"
#include "ModuleResources.h"
#include "PrefabManager.h"
#include "ResourcePrefab.h"
#include "ComponentCanvas.h"
#include "ComponentCamera.h" 
#include "Window.h"        
#include "ModuleCamera.h"   
#include <SDL3/SDL_scancode.h>
#include "GameWindow.h"
#ifndef WAVE_GAME
#include "EditorWindow.h"
#include "ModuleEditor.h"
#endif
#include "ConsoleWindow.h"
#include "Application.h"
#include "ComponentAnimation.h"
#include "UIManager.h"
#include "Rigidbody.h"

#include <filesystem>
#include <cmath>            
ScriptManager::ScriptManager() : Module(), L(nullptr) {
    name = "ScriptManager";
}

ScriptManager::~ScriptManager() {
}

bool ScriptManager::Awake() {
    return true;
}

bool ScriptManager::Start() {
    LOG_CONSOLE("[ScriptManager] Initializing Lua...");

    L = luaL_newstate();
    if (!L) {
        LOG_CONSOLE("[ScriptManager] ERROR: Failed to create Lua state");
        return false;
    }

    luaL_openlibs(L);
    LOG_CONSOLE("[ScriptManager] Lua initialized");

    RegisterEngineFunctions();
    RegisterGameObjectAPI();
    RegisterComponentAPI();
    RegisterPrefabAPI();

    LOG_CONSOLE("[ScriptManager] Started successfully");
    return true;
}

bool ScriptManager::Update() {
    if (!L) return true;
    return true;
}

// Execute all deferred operations
bool ScriptManager::PostUpdate() {
    if (!pendingOperations.empty()) {
        // Execute all pending operations
        for (auto& operation : pendingOperations) {
            operation();
        }

        pendingOperations.clear();
    }

    return true;
}

bool ScriptManager::CleanUp() {
    if (L) {
        lua_close(L);
        L = nullptr;
    }

    loadedScripts.clear();
    pendingOperations.clear();
    LOG_CONSOLE("[ScriptManager] Cleaned up");
    return true;
}

// Method to enqueue operations
void ScriptManager::EnqueueOperation(std::function<void()> operation) {
    pendingOperations.push_back(std::move(operation));
}

bool ScriptManager::LoadScript(const std::string& filepath) {
    if (!std::filesystem::exists(filepath)) {
        LOG_CONSOLE("[ScriptManager] ERROR: Script not found: %s", filepath.c_str());

        // Activar flash de error
        #ifndef WAVE_GAME
        Application& app = Application::GetInstance();
        if (app.editor && app.editor->GetConsoleWindow()) {
            app.editor->GetConsoleWindow()->FlashError();
        }

        return false;
        #endif 
    }

    int result = luaL_dofile(L, filepath.c_str());

    if (result != LUA_OK) {
        const char* error = lua_tostring(L, -1);
        LOG_CONSOLE("[ScriptManager] ERROR: %s", error);
        lua_pop(L, 1);

        #ifndef WAVE_GAME
        // Activar flash de error
        Application& app = Application::GetInstance();
        if (app.editor && app.editor->GetConsoleWindow()) {
            app.editor->GetConsoleWindow()->FlashError();
        }
        #endif // !1
        return false;
    }

    loadedScripts[filepath] = true;
    return true;
}
bool ScriptManager::ReloadScript(const std::string& filepath) {
    return LoadScript(filepath);
}

void ScriptManager::CallGlobalStart() {
    lua_getglobal(L, "Start");

    if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
            const char* error = lua_tostring(L, -1);
            LOG_CONSOLE("[ScriptManager] ERROR in Start(): %s", error);
            lua_pop(L, 1);

            #ifndef WAVE_GAME
            // Activar flash de error
            auto& app = Application::GetInstance();
            if (app.editor && app.editor->GetConsoleWindow()) {
                app.editor->GetConsoleWindow()->FlashError();
            }
            #endif
        }
    }
    else {
        lua_pop(L, 1);
    }
}

void ScriptManager::CallGlobalUpdate(float deltaTime) {
    lua_getglobal(L, "Update");

    if (lua_isfunction(L, -1)) {
        lua_pushnumber(L, deltaTime);

        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            const char* error = lua_tostring(L, -1);
            LOG_CONSOLE("[ScriptManager] ERROR in Update(): %s", error);
            lua_pop(L, 1);
            #ifndef WAVE_GAME
            // Activar flash de error
            auto& app = Application::GetInstance();
            if (app.editor && app.editor->GetConsoleWindow()) {
                app.editor->GetConsoleWindow()->FlashError();
            }
            #endif // !1
        }
    }
    else {
        lua_pop(L, 1);
    }
}

bool ScriptManager::HasGlobalFunction(const std::string& functionName) {
    lua_getglobal(L, functionName.c_str());
    bool isFunc = lua_isfunction(L, -1);
    lua_pop(L, 1);
    return isFunc;
}


//basic lua functions

static int Lua_Engine_Log(lua_State* L) {
    const char* message = luaL_checkstring(L, 1);
    LOG_CONSOLE("[Lua] %s", message);
    return 0;
}

static const std::unordered_map<std::string, SDL_Scancode> keyMap = {
    {"W", SDL_SCANCODE_W}, {"A", SDL_SCANCODE_A}, {"S", SDL_SCANCODE_S},
    {"D", SDL_SCANCODE_D}, {"Q", SDL_SCANCODE_Q}, {"E", SDL_SCANCODE_E},
    {"Space", SDL_SCANCODE_SPACE}, {"Escape", SDL_SCANCODE_ESCAPE},
    {"LeftShift", SDL_SCANCODE_LSHIFT}, {"RightShift", SDL_SCANCODE_RSHIFT},
    {"5", SDL_SCANCODE_5}, {"6", SDL_SCANCODE_6}, {"7", SDL_SCANCODE_7}
};

static int Lua_Input_GetKey(lua_State* L) {
    const char* keyName = luaL_checkstring(L, 1);
    auto it = keyMap.find(keyName);
    bool pressed = (it != keyMap.end()) &&
        Application::GetInstance().input->GetKey(it->second) == KEY_REPEAT;
    lua_pushboolean(L, pressed);
    return 1;
}

static int Lua_Input_GetKeyDown(lua_State* L) {
    const char* keyName = luaL_checkstring(L, 1);
    auto it = keyMap.find(keyName);
    bool pressed = (it != keyMap.end()) &&
        Application::GetInstance().input->GetKey(it->second) == KEY_DOWN;
    lua_pushboolean(L, pressed);
    return 1;
}

static int Lua_Input_GetMousePosition(lua_State* L) {

    glm::vec2 raw = Application::GetInstance().input.get()->GetMousePosition();
    int rawX = raw.x;
    int rawY = raw.y;

    #ifndef WAVE_GAME
    auto& app = Application::GetInstance();

    // Get the Game window directly
    GameWindow* gameWindow = app.editor->GetGameWindow();

    if (gameWindow) {


        ImVec2 viewportPos = gameWindow->GetViewportPos();
        ImVec2 viewportSize = gameWindow->GetViewportSize();
        
        // Convert to viewport-relative coordinates
        int relativeX = rawX - static_cast<int>(viewportPos.x);
        int relativeY = rawY - static_cast<int>(viewportPos.y);

        // Check if mouse is inside the game viewport
        if (relativeX >= 0 && relativeX < viewportSize.x &&
            relativeY >= 0 && relativeY < viewportSize.y) {
            lua_pushnumber(L, static_cast<lua_Number>(relativeX));
            lua_pushnumber(L, static_cast<lua_Number>(relativeY));
            return 2;
        }
    }
    #else 
        lua_pushnumber(L, static_cast<lua_Number>(rawX));
        lua_pushnumber(L, static_cast<lua_Number>(rawY));
        return 2;
    #endif

    // If not in game window, return nil
    lua_pushnil(L);
    lua_pushnil(L);
    return 2;
}

// Gamepad Lua Universal Bindings
// Possible Returns:
// Input.GetGamepadButton("A") - return true when is held
// Input.GetGamepadButtonDown("A") - return true only the first frame is pushed, next frame is false
// Input.GetGamepadAxis("LeftX") - number between -1.0 and 1.0
// Input.GetLeftStick() - two numbers, coords of the horizontal axis X and vertical axis Y of the joystick, player movement
// Input.GetRightStick() - same but is the right joystick, usually used for camera movement
// Input.HasGamepad() - return true if a gamepad is detected, false if is only mouse and keyboard
// Input.GetGamepadCount() - return number of gamepads connecteds
static GamepadButton LuaStringToButton(const char* name)
{
    if (strcmp(name, "A") == 0 || strcmp(name, "South") == 0) return GP_SOUTH;
    if (strcmp(name, "B") == 0 || strcmp(name, "East") == 0) return GP_EAST;
    if (strcmp(name, "X") == 0 || strcmp(name, "West") == 0) return GP_WEST;
    if (strcmp(name, "Y") == 0 || strcmp(name, "North") == 0) return GP_NORTH;
    if (strcmp(name, "Start") == 0)                                 return GP_START;
    if (strcmp(name, "Back") == 0 || strcmp(name, "Select") == 0) return GP_BACK;
    if (strcmp(name, "Guide") == 0)                                 return GP_GUIDE;
    if (strcmp(name, "LeftStick") == 0 || strcmp(name, "L3") == 0) return GP_LEFT_STICK;
    if (strcmp(name, "RightStick") == 0 || strcmp(name, "R3") == 0) return GP_RIGHT_STICK;
    if (strcmp(name, "LB") == 0 || strcmp(name, "L1") == 0 || strcmp(name, "LeftShoulder") == 0) return GP_LEFT_SHOULDER;
    if (strcmp(name, "RB") == 0 || strcmp(name, "R1") == 0 || strcmp(name, "RightShoulder") == 0) return GP_RIGHT_SHOULDER;
    if (strcmp(name, "DPadUp") == 0) return GP_DPAD_UP;
    if (strcmp(name, "DPadDown") == 0) return GP_DPAD_DOWN;
    if (strcmp(name, "DPadLeft") == 0) return GP_DPAD_LEFT;
    if (strcmp(name, "DPadRight") == 0) return GP_DPAD_RIGHT;
    return GP_SOUTH;
    // default setting
}

static GamepadAxis LuaStringToAxis(const char* name)
{
    if (strcmp(name, "LeftX") == 0) return GP_AXIS_LEFT_X;
    if (strcmp(name, "LeftY") == 0) return GP_AXIS_LEFT_Y;
    if (strcmp(name, "RightX") == 0) return GP_AXIS_RIGHT_X;
    if (strcmp(name, "RightY") == 0) return GP_AXIS_RIGHT_Y;
    if (strcmp(name, "LT") == 0 || strcmp(name, "L2") == 0 || strcmp(name, "LeftTrigger") == 0) return GP_AXIS_LEFT_TRIGGER;
    if (strcmp(name, "RT") == 0 || strcmp(name, "R2") == 0 || strcmp(name, "RightTrigger") == 0) return GP_AXIS_RIGHT_TRIGGER;
    return GP_AXIS_LEFT_X;
}

// Input.GetGamepadButton("A") will send the message to the gamepad number 1 connected
// Input.GetGamepadButton("A", 2) will send the message to the gamepad number 2
static int Lua_Input_GetGamepadButton(lua_State* L)
{
    const char* name = luaL_checkstring(L, 1);
    int idx = static_cast<int>(luaL_optinteger(L, 2, 1)) - 1;
    // In Lua the index starts at 1, in C++ it starts at 0 so a conversion is needed
    GamepadButton btn = LuaStringToButton(name);
    lua_pushboolean(L, Application::GetInstance().input->IsGamepadButtonPressed(btn, idx));
    return 1;
}

// Same
// Input.GetGamepadButtonDown("A")
// Input.GetGamepadButtonDown("A", 2)
static int Lua_Input_GetGamepadButtonDown(lua_State* L)
{
    const char* name = luaL_checkstring(L, 1);
    int idx = static_cast<int>(luaL_optinteger(L, 2, 1)) - 1;
    GamepadButton btn = LuaStringToButton(name);
    lua_pushboolean(L, Application::GetInstance().input->IsGamepadButtonDown(btn, idx));
    return 1;
}

// Input.GetGamepadAxis("LeftX")
static int Lua_Input_GetGamepadAxis(lua_State* L)
{
    const char* name = luaL_checkstring(L, 1);
    int idx = static_cast<int>(luaL_optinteger(L, 2, 1)) - 1;
    GamepadAxis axis = LuaStringToAxis(name);
    lua_pushnumber(L, static_cast<lua_Number>(Application::GetInstance().input->GetGamepadAxis(axis, idx)));
    return 1;
}

// Input.GetLeftStick() returns axis x and axis y
static int Lua_Input_GetLeftStick(lua_State* L)
{
    int idx = static_cast<int>(luaL_optinteger(L, 1, 1)) - 1;
    glm::vec2 v = Application::GetInstance().input->GetLeftStick(idx);
    lua_pushnumber(L, v.x);
    lua_pushnumber(L, v.y);
    return 2;
}

// Input.GetRightStick() returns axis x and axis y
static int Lua_Input_GetRightStick(lua_State* L)
{
    int idx = static_cast<int>(luaL_optinteger(L, 1, 1)) - 1;
    glm::vec2 v = Application::GetInstance().input->GetRightStick(idx);
    lua_pushnumber(L, v.x);
    lua_pushnumber(L, v.y);
    return 2;
}

// Input.HasGamepad()
static int Lua_Input_HasGamepad(lua_State* L)
{
    lua_pushboolean(L, Application::GetInstance().input->HasGamepad());
    return 1;
}

// Input.GetGamepadCount()
static int Lua_Input_GetGamepadCount(lua_State* L)
{
    lua_pushinteger(L, Application::GetInstance().input->GetGamepadCount());
    return 1;
}

// Example of using rumble in Lua Input.RumbleGamepad(0.8, 0.3, 500)
static int Lua_Input_RumbleGamepad(lua_State* L)
{
    float  lowFreq = static_cast<float>(luaL_checknumber(L, 1));
    float  highFreq = static_cast<float>(luaL_checknumber(L, 2));
    Uint32 durationMs = static_cast<Uint32>(luaL_checkinteger(L, 3));
    int    idx = static_cast<int>(luaL_optinteger(L, 4, 1)) - 1;
    // Lua starts with 1 and C++ with 0
    Application::GetInstance().input->RumbleGamepad(lowFreq, highFreq, durationMs, idx);
    return 0;
}

// Example to stop inmediatly the rumble Input.StopRumble()
static int Lua_Input_StopRumble(lua_State* L)
{
    int idx = static_cast<int>(luaL_optinteger(L, 1, 1)) - 1;
    Application::GetInstance().input->StopRumble(idx);
    return 0;
}

static int Lua_Time_GetDeltaTime(lua_State* L) {
    lua_pushnumber(L, Time::GetDeltaTimeStatic());
    return 1;
}

static int Lua_Time_GetRealDeltaTime(lua_State* L) {
    lua_pushnumber(L, Time::GetRealDeltaTimeStatic());
    return 1;
}

static int Lua_Camera_GetScreenToWorldPlane(lua_State* L) {
    int mouseX = static_cast<int>(luaL_checknumber(L, 1));
    int mouseY = static_cast<int>(luaL_checknumber(L, 2));
    float planeY = static_cast<float>(luaL_optnumber(L, 3, 0.0));

    auto& app = Application::GetInstance();

    // Get Game window dimensions
    int screenWidth = 800;
    int screenHeight = 600;

    #ifndef WAVE_GAME
    GameWindow* gameWindow = app.editor->GetGameWindow();
    if (gameWindow) {
        ImVec2 viewportSize = gameWindow->GetViewportSize();
        screenWidth = static_cast<int>(viewportSize.x);
        screenHeight = static_cast<int>(viewportSize.y);
    }
    #else 
    
    app.window->GetWindowSize(screenWidth, screenHeight);

    #endif
    ComponentCamera* camera = nullptr;


    if (app.GetPlayState() == Application::PlayState::PLAYING) {
        // En Play mode: usar la cámara de escena (ya cacheada)
        camera = app.camera->GetMainCamera();

        //// Fallback a editor si no hay cámara de juego
        //if (!camera) {
        //    camera = app.camera->GetEditorCamera();
        //}
    } /*else {*/
    //    // En Editor mode: usar cámara del editor
    //    camera = app.camera->GetEditorCamera();
    //}

    if (!camera) {
        LOG_CONSOLE("[Lua] ERROR: No camera available");
        lua_pushnil(L);
        lua_pushnil(L);
        return 2;
    }

    glm::vec3 rayDir = camera->ScreenToWorldRay(mouseX, mouseY, screenWidth, screenHeight);
    glm::vec3 rayOrigin = camera->owner->transform->GetPosition();

    // Calculate intersection with plane Y = planeY
    if (std::abs(rayDir.y) < 0.0001f) {
        lua_pushnil(L);
        lua_pushnil(L);
        return 2;
    }

    float t = (planeY - rayOrigin.y) / rayDir.y;

    if (t < 0) {
        lua_pushnil(L);
        lua_pushnil(L);
        return 2;
    }

    glm::vec3 intersection = rayOrigin + t * rayDir;

    lua_pushnumber(L, intersection.x);
    lua_pushnumber(L, intersection.z);
    return 2;
}

static int Lua_UI_WasClicked(lua_State* L) {
    const char* buttonName = luaL_checkstring(L, 1);
    bool clicked = UIManager::GetInstance().WasButtonJustClicked(buttonName);
    lua_pushboolean(L, clicked);
    return 1;
}

// Game API
static int Lua_Game_Exit(lua_State* L) {
    Application::GetInstance().RequestExit();
    return 0;
}
static int Lua_Game_Pause(lua_State* L) {
    Application::GetInstance().Pause();
    return 0;
}

static int Lua_Game_Resume(lua_State* L) {
    Application::GetInstance().Play();
    return 0;
}


void ScriptManager::RegisterEngineFunctions() {
    if (!L) {
        LOG_CONSOLE("[ScriptManager] ERROR: Cannot register functions, Lua state is null");
        return;
    }

    LOG_CONSOLE("[ScriptManager] Registering engine functions...");

    // Engine.Log
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Engine_Log);
    lua_setfield(L, -2, "Log");
    lua_setglobal(L, "Engine");

    // Input
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Input_GetKey);
    lua_setfield(L, -2, "GetKey");
    lua_pushcfunction(L, Lua_Input_GetKeyDown);
    lua_setfield(L, -2, "GetKeyDown");
    lua_pushcfunction(L, Lua_Input_GetMousePosition);
    lua_setfield(L, -2, "GetMousePosition");
    // Gamepad
    lua_pushcfunction(L, Lua_Input_GetGamepadButton);
    lua_setfield(L, -2, "GetGamepadButton");
    lua_pushcfunction(L, Lua_Input_GetGamepadButtonDown);
    lua_setfield(L, -2, "GetGamepadButtonDown");
    lua_pushcfunction(L, Lua_Input_GetGamepadAxis);
    lua_setfield(L, -2, "GetGamepadAxis");
    lua_pushcfunction(L, Lua_Input_GetLeftStick);
    lua_setfield(L, -2, "GetLeftStick");
    lua_pushcfunction(L, Lua_Input_GetRightStick);
    lua_setfield(L, -2, "GetRightStick");
    lua_pushcfunction(L, Lua_Input_HasGamepad);
    lua_setfield(L, -2, "HasGamepad");
    lua_pushcfunction(L, Lua_Input_GetGamepadCount);
    lua_setfield(L, -2, "GetGamepadCount");
    lua_pushcfunction(L, Lua_Input_RumbleGamepad);
    lua_setfield(L, -2, "RumbleGamepad");
    lua_pushcfunction(L, Lua_Input_StopRumble);
    lua_setfield(L, -2, "StopRumble");
    lua_setglobal(L, "Input");

    // Time
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Time_GetDeltaTime);
    lua_setfield(L, -2, "GetDeltaTime");
    lua_pushcfunction(L, Lua_Time_GetRealDeltaTime);
    lua_setfield(L, -2, "GetRealDeltaTime");
    lua_setglobal(L, "Time");

    // Camera
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Camera_GetScreenToWorldPlane);
    lua_setfield(L, -2, "GetScreenToWorldPlane");
    lua_setglobal(L, "Camera");

    // UI
    lua_newtable(L);
    lua_pushcfunction(L, Lua_UI_WasClicked);
    lua_setfield(L, -2, "WasClicked");
    lua_setglobal(L, "UI");

    // Game
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Game_Pause);
    lua_setfield(L, -2, "Pause");
    lua_pushcfunction(L, Lua_Game_Resume);
    lua_setfield(L, -2, "Resume");
    lua_pushcfunction(L, Lua_Game_Exit);
    lua_setfield(L, -2, "Exit");
    lua_setglobal(L, "Game");


    LOG_CONSOLE("[ScriptManager] Engine functions registered: Engine, Input, Time, Camera, UI, Game");
}
// GAMEOBJECT API

static int Lua_Animation_Play(lua_State* L)
{
    ComponentAnimation* anim = *static_cast<ComponentAnimation**>(lua_touserdata(L, 1));

    const char* animName = luaL_checkstring(L, 2);

    float blendTime = static_cast<float>(luaL_optnumber(L, 3, 0.2));

    if (anim)
    {
        anim->Play(std::string(animName), blendTime);
    }

    return 0;
}

static int Lua_Animation_Stop(lua_State* L)
{
    ComponentAnimation* anim = *static_cast<ComponentAnimation**>(lua_touserdata(L, 1));

    if (anim)
    {
        anim->Stop();
    }

    return 0;
}

static int Lua_Animation_IsPlaying(lua_State* L)
{
    ComponentAnimation* anim = *static_cast<ComponentAnimation**>(lua_touserdata(L, 1));

    bool playing = false;
    if (anim)
    {
        playing = anim->IsPlaying();
    }

    lua_pushboolean(L, playing);
    return 1;
}

static int Lua_Animation_IsPlayingAnimation(lua_State* L)
{
    ComponentAnimation* anim = *static_cast<ComponentAnimation**>(lua_touserdata(L, 1));
    const char* animName = luaL_checkstring(L, 2);

    bool playing = false;
    if (anim)
    {
        playing = anim->IsPlayingAnimation(animName);
    }

    lua_pushboolean(L, playing);
    return 1;
}

// GameObject.Create(name) - Deferred operation
static int Lua_GameObject_Create(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);

    // Create userdata that will be filled in PostUpdate
    GameObject** udata = static_cast<GameObject**>(lua_newuserdata(L, sizeof(GameObject*)));
    *udata = nullptr;  // Temporarily null

    // Assign metatable
    luaL_getmetatable(L, "GameObject");
    lua_setmetatable(L, -2);

    // Enqueue the real creation for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([name, udata]() {
        GameObject* obj = Application::GetInstance().scene->CreateGameObject(name);

        if (obj) {
            GameObject* root = Application::GetInstance().scene->GetRoot();
            if (root && obj->GetParent() == nullptr) {
                root->AddChild(obj);
            }

            *udata = obj;  // Assign the created GameObject
        }
        });

    return 1;
}

// GameObject.Destroy(obj) - Deferred operation
static int Lua_GameObject_Destroy(lua_State* L) {
    GameObject** udata = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!udata || !*udata) {
        LOG_CONSOLE("[Lua] ERROR: Invalid GameObject in Destroy()");
        return 0;
    }

    GameObject* obj = *udata;

    // Enqueue destruction for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([obj]() {
        obj->MarkForDeletion();
        });

    return 0;
}

static int Lua_GameObject_Find(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);

    GameObject* root = Application::GetInstance().scene->GetRoot();
    if (!root) {
        lua_pushnil(L);
        return 1;
    }

    std::function<GameObject* (GameObject*, const std::string&)> findByName;
    findByName = [&](GameObject* node, const std::string& targetName) -> GameObject* {
        if (node->GetName() == targetName) {
            return node;
        }

        for (GameObject* child : node->GetChildren()) {
            GameObject* result = findByName(child, targetName);
            if (result) return result;
        }

        return nullptr;
        };

    GameObject* found = findByName(root, name);

    if (!found) {
        lua_pushnil(L);
        return 1;
    }

    GameObject** udata = static_cast<GameObject**>(lua_newuserdata(L, sizeof(GameObject*)));
    *udata = found;

    luaL_getmetatable(L, "GameObject");
    lua_setmetatable(L, -2);

    return 1;
}

// Helper functions for GameObject methods
static int Lua_GameObject_SetActive(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot SetActive on invalid/deleted GameObject");
        return 0;
    }

    GameObject* obj = *objPtr;
    bool active = lua_toboolean(L, 2) != 0;

    // Enqueue state change for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([obj, active]() {
        if (!obj->IsMarkedForDeletion()) {
            obj->SetActive(active);
        }
        });

    return 0;
}

static int Lua_GameObject_IsActive(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        lua_pushboolean(L, false);
        return 1;
    }

    GameObject* obj = *objPtr;
    lua_pushboolean(L, obj->IsActive());
    return 1;
}

static int Lua_GameObject_AddComponent_MeshRenderer(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot add component to invalid/deleted GameObject");
        lua_pushboolean(L, false);
        return 1;
    }

    GameObject* obj = *objPtr;

    // Enqueue component addition for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([obj]() {
        if (!obj->IsMarkedForDeletion()) {
            obj->CreateComponent(ComponentType::MESH); 
        }
        });

    lua_pushboolean(L, true);
    return 1;
}

static int Lua_GameObject_AddComponent_Material(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot add component to invalid/deleted GameObject");
        lua_pushboolean(L, false);
        return 1;
    }

    GameObject* obj = *objPtr;

    // Enqueue component addition for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([obj]() {
        if (!obj->IsMarkedForDeletion()) {
            obj->CreateComponent(ComponentType::MATERIAL); 
        }
        });

    lua_pushboolean(L, true);
    return 1;
}

static int Lua_GameObject_AddComponent(lua_State* L) {
    GameObject* obj = *static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));
    const char* componentType = luaL_checkstring(L, 2);

    if (strcmp(componentType, "MeshRenderer") == 0) {
        return Lua_GameObject_AddComponent_MeshRenderer(L);
    }

    if (strcmp(componentType, "Material") == 0) {
        return Lua_GameObject_AddComponent_Material(L);
    }

    lua_pushboolean(L, false);
    return 1;
}

static int Lua_GameObject_LoadMesh(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot load mesh on invalid/deleted GameObject");
        lua_pushboolean(L, false);
        return 1;
    }

    GameObject* obj = *objPtr;
    UID meshUID = static_cast<UID>(luaL_checknumber(L, 2));

    Component* comp = obj->GetComponent(ComponentType::MESH);
    ComponentMesh* mesh = static_cast<ComponentMesh*>(comp);
    if (!mesh) {
        lua_pushboolean(L, false);
        return 1;
    }

    // Enqueue mesh load for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([mesh, meshUID]() {
        mesh->LoadMeshByUID(meshUID);
        });

    lua_pushboolean(L, true);
    return 1;
}

static int Lua_GameObject_LoadTexture(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot load texture on invalid/deleted GameObject");
        lua_pushboolean(L, false);
        return 1;
    }

    GameObject* obj = *objPtr;
    UID textureUID = static_cast<UID>(luaL_checknumber(L, 2));

    Component* comp = obj->GetComponent(ComponentType::MATERIAL);
    ComponentMaterial* mat = static_cast<ComponentMaterial*>(comp);
    if (!mat) {
        lua_pushboolean(L, false);
        return 1;
    }

    // Enqueue texture load for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([mat, textureUID]() {
        mat->LoadTextureByUID(textureUID);
        });

    lua_pushboolean(L, true);
    return 1;
}

// Helper for ComponentMesh.SetMesh
static int Lua_ComponentMesh_SetMesh(lua_State* L) {
    ComponentMesh* mesh = static_cast<ComponentMesh*>(lua_touserdata(L, lua_upvalueindex(1)));
    UID meshUID = static_cast<UID>(luaL_checknumber(L, 1));

    // Enqueue mesh change for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([mesh, meshUID]() {
        mesh->LoadMeshByUID(meshUID);
        });

    return 0;
}

// Helper for ComponentMaterial.SetTexture
static int Lua_ComponentMaterial_SetTexture(lua_State* L) {
    ComponentMaterial* mat = static_cast<ComponentMaterial*>(lua_touserdata(L, lua_upvalueindex(1)));
    UID textureUID = static_cast<UID>(luaL_checknumber(L, 1));

    // Enqueue texture change for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([mat, textureUID]() {
        mat->LoadTextureByUID(textureUID);
        });

    return 0;
}

static int Lua_Rigidbody_AddForce(lua_State* L) {
    Rigidbody* rb = static_cast<Rigidbody*>(lua_touserdata(L, lua_upvalueindex(1)));
    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));
    //modes: 1=FORCE(default), 2=IMPULSE, 3=VELOCITY_CHANGE, 4=ACCELERATION
    int modeInt = static_cast<int>(luaL_optinteger(L, 5, 1));
    Rigidbody::ForceMode mode = Rigidbody::ForceMode::FORCE;
    if (modeInt == 2) mode = Rigidbody::ForceMode::IMPULSE;
    else if (modeInt == 3) mode = Rigidbody::ForceMode::VELOCITY_CHANGE;
    else if (modeInt == 4) mode = Rigidbody::ForceMode::ACCELERATION;

    if (rb) {
        Application::GetInstance().scripts->EnqueueOperation([rb, x, y, z, mode]() {
            rb->AddForce(glm::vec3(x, y, z), mode);
            });
    }
    return 0;
}

static int Lua_Rigidbody_AddTorque(lua_State* L) {
    Rigidbody* rb = static_cast<Rigidbody*>(lua_touserdata(L, lua_upvalueindex(1)));
    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));
    int modeInt = static_cast<int>(luaL_optinteger(L, 5, 1));
    Rigidbody::ForceMode mode = Rigidbody::ForceMode::FORCE;
    if (modeInt == 2) mode = Rigidbody::ForceMode::IMPULSE;
    else if (modeInt == 3) mode = Rigidbody::ForceMode::VELOCITY_CHANGE;
    else if (modeInt == 4) mode = Rigidbody::ForceMode::ACCELERATION;

    if (rb) {
        Application::GetInstance().scripts->EnqueueOperation([rb, x, y, z, mode]() {
            rb->AddTorque(glm::vec3(x, y, z), mode);
            });
    }
    return 0;
}

static int Lua_Rigidbody_GetLinearVelocity(lua_State* L) {
    Rigidbody* rb = static_cast<Rigidbody*>(lua_touserdata(L, lua_upvalueindex(1)));
    if (rb) {
        glm::vec3 v = rb->GetLinearVelocity();
        lua_pushnumber(L, v.x);
        lua_pushnumber(L, v.y);
        lua_pushnumber(L, v.z);
        return 3;
    }
    lua_pushnumber(L, 0); lua_pushnumber(L, 0); lua_pushnumber(L, 0);
    return 3;
}

// Helper for ComponentCanvas.SetOpacity
static int Lua_ComponentCanvas_SetOpacity(lua_State* L) {
    ComponentCanvas* canvas = static_cast<ComponentCanvas*>(lua_touserdata(L, lua_upvalueindex(1)));
    float opacity = static_cast<float>(luaL_checknumber(L, 2));

    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([canvas, opacity]() {
        canvas->SetOpacity(opacity);
        });

    return 0;
}

static int Lua_Collider_Enable(lua_State* L) {
    Component* comp = static_cast<Component*>(lua_touserdata(L, lua_upvalueindex(1)));
    if (comp) 
    {
        Application::GetInstance().scripts->EnqueueOperation([comp]() {
            comp->Enable();
            comp->SetActive(true);
            });
    }
    return 0;
}

static int Lua_Collider_Disable(lua_State* L) {
    Component* comp = static_cast<Component*>(lua_touserdata(L, lua_upvalueindex(1)));
    if (comp) 
    {
        Application::GetInstance().scripts->EnqueueOperation([comp]() 
            {
            comp->Disable();
            comp->SetActive(false);
            });
    }
    return 0;
}

static int Lua_GameObject_GetComponent(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot get component from invalid/deleted GameObject");
        lua_pushnil(L);
        return 1;
    }

    GameObject* obj = *objPtr;
    const char* componentType = luaL_checkstring(L, 2);

    if (strcmp(componentType, "MeshRenderer") == 0) {
        Component* comp = obj->GetComponent(ComponentType::MESH);
        ComponentMesh* mesh = static_cast<ComponentMesh*>(comp);
        if (!mesh) {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);
        lua_pushlightuserdata(L, mesh);
        lua_pushcclosure(L, Lua_ComponentMesh_SetMesh, 1);
        lua_setfield(L, -2, "SetMesh");

        return 1;
    }

    if (strcmp(componentType, "Material") == 0) {
        Component* comp = obj->GetComponent(ComponentType::MATERIAL);
        ComponentMaterial* mat = static_cast<ComponentMaterial*>(comp);
        if (!mat) {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);
        lua_pushlightuserdata(L, mat);
        lua_pushcclosure(L, Lua_ComponentMaterial_SetTexture, 1);
        lua_setfield(L, -2, "SetTexture");

        return 1;
    }
    if (strcmp(componentType, "Canvas") == 0) {
        Component* comp = obj->GetComponent(ComponentType::CANVAS);
        ComponentCanvas* canvas = static_cast<ComponentCanvas*>(comp);
        if (!canvas) {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);

        // SetOpacity (ya existente)
        lua_pushlightuserdata(L, canvas);
        lua_pushcclosure(L, Lua_ComponentCanvas_SetOpacity, 1);
        lua_setfield(L, -2, "SetOpacity");

        // GetCurrentXAML
        lua_pushlightuserdata(L, canvas);
        lua_pushcclosure(L, [](lua_State* L) -> int {
            ComponentCanvas* canvas = static_cast<ComponentCanvas*>(
                lua_touserdata(L, lua_upvalueindex(1)));
            lua_pushstring(L, canvas->GetCurrentXAML().c_str());
            return 1;
            }, 1);
        lua_setfield(L, -2, "GetCurrentXAML");

        // LoadXAML (nuevo)
        lua_pushlightuserdata(L, canvas);
        lua_pushcclosure(L, [](lua_State* L) -> int {
            ComponentCanvas* canvas = static_cast<ComponentCanvas*>(
                lua_touserdata(L, lua_upvalueindex(1)));
            const char* xamlPath = luaL_checkstring(L, 2); 
            std::string path(xamlPath);
            Application::GetInstance().scripts->EnqueueOperation([canvas, path]() {
                canvas->LoadXAML(path.c_str());
                });
            return 0;
            }, 1);
        lua_setfield(L, -2, "LoadXAML");

        return 1;
    }

    if (strcmp(componentType, "Animation") == 0) {
        Component* comp = obj->GetComponent(ComponentType::ANIMATION);
        ComponentAnimation* anim = static_cast<ComponentAnimation*>(comp);
        if (!anim) {
            lua_pushnil(L);
            return 1;
        }

        ComponentAnimation** udata = static_cast<ComponentAnimation**>(
            lua_newuserdata(L, sizeof(ComponentAnimation*))
        );
        *udata = anim;

        luaL_getmetatable(L, "Animation");
        lua_setmetatable(L, -2);

        return 1;
    }

    if (strcmp(componentType, "Box Collider") == 0 ||
        strcmp(componentType, "Sphere Collider") == 0 ||
        strcmp(componentType, "Capsule Collider") == 0)
    {
        ComponentType ctype = ComponentType::BOX_COLLIDER;
        if (strcmp(componentType, "Sphere Collider") == 0)   ctype = ComponentType::SPHERE_COLLIDER;
        if (strcmp(componentType, "Capsule Collider") == 0)  ctype = ComponentType::CAPSULE_COLLIDER;

        Component* comp = obj->GetComponent(ctype);
        if (!comp) 
        {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);

        lua_pushlightuserdata(L, comp);
        lua_pushcclosure(L, Lua_Collider_Enable, 1);
        lua_setfield(L, -2, "Enable");

        lua_pushlightuserdata(L, comp);
        lua_pushcclosure(L, Lua_Collider_Disable, 1);
        lua_setfield(L, -2, "Disable");

        return 1;
    }

    if (strcmp(componentType, "Rigidbody") == 0) {
        Component* comp = obj->GetComponent(ComponentType::RIGIDBODY);
        Rigidbody* rb = static_cast<Rigidbody*>(comp);
        if (!rb) {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);

        lua_pushlightuserdata(L, rb);
        lua_pushcclosure(L, Lua_Rigidbody_AddForce, 1);
        lua_setfield(L, -2, "AddForce");

        lua_pushlightuserdata(L, rb);
        lua_pushcclosure(L, Lua_Rigidbody_AddTorque, 1);
        lua_setfield(L, -2, "AddTorque");

        lua_pushlightuserdata(L, rb);
        lua_pushcclosure(L, Lua_Rigidbody_GetLinearVelocity, 1);
        lua_setfield(L, -2, "GetLinearVelocity");

        return 1;
    }

    lua_pushnil(L);
    return 1;
}

static int Lua_GameObject_Index(lua_State* L) {
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr) {
        LOG_CONSOLE("[Lua] ERROR: Attempting to access invalid GameObject (null or deleted)");
        lua_pushnil(L);
        return 1;
    }

    GameObject* obj = *objPtr;

    if (obj->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] WARNING: Accessing GameObject marked for deletion: %s", obj->GetName().c_str());
        lua_pushnil(L);
        return 1;
    }

    const char* key = luaL_checkstring(L, 2);

    if (strcmp(key, "name") == 0) {
        lua_pushstring(L, obj->GetName().c_str());
        return 1;
    }

    if (strcmp(key, "transform") == 0) {
        Component* comp = obj->GetComponent(ComponentType::TRANSFORM);
        Transform* t = static_cast<Transform*>(comp);

        if (!t) {
            lua_pushnil(L);
            return 1;
        }

        Transform** udata = static_cast<Transform**>(lua_newuserdata(L, sizeof(Transform*)));
        *udata = t;

        luaL_getmetatable(L, "Transform");
        lua_setmetatable(L, -2);

        return 1;
    }

    if (strcmp(key, "SetActive") == 0) {
        lua_pushcfunction(L, Lua_GameObject_SetActive);
        return 1;
    }

    if (strcmp(key, "IsActive") == 0) {
        lua_pushcfunction(L, Lua_GameObject_IsActive);
        return 1;
    }

    if (strcmp(key, "GetComponent") == 0) {
        lua_pushcfunction(L, Lua_GameObject_GetComponent);
        return 1;
    }

    if (strcmp(key, "AddComponent") == 0) {
        lua_pushcfunction(L, Lua_GameObject_AddComponent);
        return 1;
    }

    if (strcmp(key, "LoadMesh") == 0) {
        lua_pushcfunction(L, Lua_GameObject_LoadMesh);
        return 1;
    }

    if (strcmp(key, "LoadTexture") == 0) {
        lua_pushcfunction(L, Lua_GameObject_LoadTexture);
        return 1;
    }

    if (strcmp(key, "tag") == 0) {
        lua_pushstring(L, obj->GetTag().c_str());
        return 1;
    }

    if (strcmp(key, "SetTag") == 0) {
        lua_pushcfunction(L, +[](lua_State* L) -> int {
            GameObject** objPtr = (GameObject**)luaL_checkudata(L, 1, "GameObject");
            const char* tag = luaL_checkstring(L, 2);
            (*objPtr)->SetTag(tag);
            return 0;
            });
        return 1;
    }

    if (strcmp(key, "CompareTag") == 0) {
        lua_pushcfunction(L, +[](lua_State* L) -> int {
            GameObject** objPtr = (GameObject**)luaL_checkudata(L, 1, "GameObject");
            const char* tag = luaL_checkstring(L, 2);
            lua_pushboolean(L, (*objPtr)->CompareTag(tag));
            return 1;
            });
        return 1;
    }

    return 0;
}

void ScriptManager::RegisterGameObjectAPI() {
    // Create metatable for GameObject
    luaL_newmetatable(L, "GameObject");

    lua_pushcfunction(L, Lua_GameObject_Index);
    lua_setfield(L, -2, "__index");

    lua_pop(L, 1);

    // Create global GameObject table
    lua_newtable(L);

    lua_pushcfunction(L, Lua_GameObject_Create);
    lua_setfield(L, -2, "Create");

    lua_pushcfunction(L, Lua_GameObject_Destroy);
    lua_setfield(L, -2, "Destroy");

    lua_pushcfunction(L, Lua_GameObject_Find);
    lua_setfield(L, -2, "Find");

    lua_setglobal(L, "GameObject");

    LOG_CONSOLE("[ScriptManager] GameObject API registered");
}

// TRANSFORM API

// Helper functions for Transform methods
static int Lua_Transform_SetPosition(lua_State* L) {
    Transform** tPtr = static_cast<Transform**>(luaL_checkudata(L, 1, "Transform"));

    if (!tPtr || !*tPtr) {
        LOG_CONSOLE("[Lua] ERROR: Cannot set position on invalid Transform");
        return 0;
    }

    Transform* t = *tPtr;

    // Verificar si el GameObject propietario está marcado para eliminación
    GameObject* owner = t->GetOwner();
    if (owner && owner->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] WARNING: Attempting to set position on deleted GameObject");
        return 0;
    }

    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));

    // Enqueue position change for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([t, x, y, z]() {
        GameObject* owner = t->GetOwner();
        if (owner && !owner->IsMarkedForDeletion()) {
            t->SetPosition(glm::vec3(x, y, z));
        }
        });

    return 0;
}

static int Lua_Transform_SetRotation(lua_State* L) {
    Transform** tPtr = static_cast<Transform**>(luaL_checkudata(L, 1, "Transform"));

    if (!tPtr || !*tPtr) {
        LOG_CONSOLE("[Lua] ERROR: Cannot set rotation on invalid Transform");
        return 0;
    }

    Transform* t = *tPtr;

    // Verificar si el GameObject propietario está marcado para eliminación
    GameObject* owner = t->GetOwner();
    if (owner && owner->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] WARNING: Attempting to set rotation on deleted GameObject");
        return 0;
    }

    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));

    // Enqueue rotation change for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([t, x, y, z]() {
        GameObject* owner = t->GetOwner();
        if (owner && !owner->IsMarkedForDeletion()) {
            t->SetRotation(glm::vec3(x, y, z));
        }
        });

    return 0;
}

static int Lua_Transform_SetScale(lua_State* L) {
    Transform** tPtr = static_cast<Transform**>(luaL_checkudata(L, 1, "Transform"));

    if (!tPtr || !*tPtr) {
        LOG_CONSOLE("[Lua] ERROR: Cannot set scale on invalid Transform");
        return 0;
    }

    Transform* t = *tPtr;

    // Verificar si el GameObject propietario está marcado para eliminación
    GameObject* owner = t->GetOwner();
    if (owner && owner->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] WARNING: Attempting to set scale on deleted GameObject");
        return 0;
    }

    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));

    // Enqueue scale change for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([t, x, y, z]() {
        GameObject* owner = t->GetOwner();
        if (owner && !owner->IsMarkedForDeletion()) {
            t->SetScale(glm::vec3(x, y, z));
        }
        });

    return 0;
}

static int Lua_Transform_Index(lua_State* L) {
    Transform** tPtr = static_cast<Transform**>(luaL_checkudata(L, 1, "Transform"));

    if (!tPtr || !*tPtr) {
        LOG_CONSOLE("[Lua] ERROR: Accessing invalid Transform");
        lua_pushnil(L);
        return 1;
    }

    Transform* t = *tPtr;

    // Verificar si el GameObject propietario está marcado para eliminación
    GameObject* owner = t->GetOwner();
    if (owner && owner->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] WARNING: Accessing Transform of deleted GameObject");
        lua_pushnil(L);
        return 1;
    }

    const char* key = luaL_checkstring(L, 2);

    // LOCAL POSITION
    if (strcmp(key, "position") == 0) {
        const glm::vec3& pos = t->GetPosition();

        lua_newtable(L);
        lua_pushnumber(L, pos.x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, pos.y);
        lua_setfield(L, -2, "y");
        lua_pushnumber(L, pos.z);
        lua_setfield(L, -2, "z");

        return 1;
    }

    if (strcmp(key, "worldPosition") == 0) {
        try {
            // Intentar obtener la matriz global
            const glm::mat4& worldMatrix = t->GetGlobalMatrix();

            // Extraer posición mundial - GLM matrices son column-major
            // La última columna (índice 3) contiene la posición
            float worldX = worldMatrix[3][0];
            float worldY = worldMatrix[3][1];
            float worldZ = worldMatrix[3][2];


            // Crear tabla Lua
            lua_newtable(L);
            lua_pushnumber(L, worldX);
            lua_setfield(L, -2, "x");
            lua_pushnumber(L, worldY);
            lua_setfield(L, -2, "y");
            lua_pushnumber(L, worldZ);
            lua_setfield(L, -2, "z");

            return 1;
        }
        catch (const std::exception& e) {
            LOG_CONSOLE("[Lua] ERROR getting worldPosition: %s", e.what());
            lua_pushnil(L);
            return 1;
        }
        catch (...) {
            LOG_CONSOLE("[Lua] ERROR: Unknown exception getting worldPosition");
            lua_pushnil(L);
            return 1;
        }
    }

    // ROTATION
    if (strcmp(key, "rotation") == 0) {
        const glm::vec3& rot = t->GetRotation();

        lua_newtable(L);
        lua_pushnumber(L, rot.x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, rot.y);
        lua_setfield(L, -2, "y");
        lua_pushnumber(L, rot.z);
        lua_setfield(L, -2, "z");

        return 1;
    }

    // SCALE
    if (strcmp(key, "scale") == 0) {
        const glm::vec3& scl = t->GetScale();

        lua_newtable(L);
        lua_pushnumber(L, scl.x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, scl.y);
        lua_setfield(L, -2, "y");
        lua_pushnumber(L, scl.z);
        lua_setfield(L, -2, "z");

        return 1;
    }

    // METHODS
    if (strcmp(key, "SetPosition") == 0) {
        lua_pushcfunction(L, Lua_Transform_SetPosition);
        return 1;
    }

    if (strcmp(key, "SetRotation") == 0) {
        lua_pushcfunction(L, Lua_Transform_SetRotation);
        return 1;
    }

    if (strcmp(key, "SetScale") == 0) {
        lua_pushcfunction(L, Lua_Transform_SetScale);
        return 1;
    }

    // Si la clave no se encuentra, retornar nil
    lua_pushnil(L);
    return 1;
}
void ScriptManager::RegisterComponentAPI() {
    // Transform metatable
    luaL_newmetatable(L, "Transform");
    lua_pushcfunction(L, Lua_Transform_Index);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);

    // Animation metatable separada
    luaL_newmetatable(L, "Animation");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, Lua_Animation_Play);
    lua_setfield(L, -2, "Play");
    lua_pushcfunction(L, Lua_Animation_Stop);
    lua_setfield(L, -2, "Stop");
    lua_pushcfunction(L, Lua_Animation_IsPlaying);
    lua_setfield(L, -2, "IsPlaying");
    lua_pushcfunction(L, Lua_Animation_IsPlayingAnimation);
    lua_setfield(L, -2, "IsPlayingAnimation");
    lua_pop(L, 1); 
}

// PREFAB API
// Prefab.Load(name, filepath)
static int Lua_Prefab_Load(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);
    const char* filepath = luaL_checkstring(L, 2);

    bool success = PrefabManager::GetInstance().LoadPrefab(name, filepath);

    lua_pushboolean(L, success);
    return 1;
}

// Prefab.Instantiate(name) - Deferred operation
static int Lua_Prefab_Instantiate(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);

    // Create userdata that will be filled in PostUpdate
    GameObject** udata = static_cast<GameObject**>(lua_newuserdata(L, sizeof(GameObject*)));
    *udata = nullptr;  // Temporarily null

    luaL_getmetatable(L, "GameObject");
    lua_setmetatable(L, -2);

    // Enqueue instantiation for PostUpdate
    auto& app = Application::GetInstance();
    app.scripts->EnqueueOperation([name, udata]() {
        GameObject* instance = nullptr;

        // First check if prefab is already loaded in PrefabManager
        if (PrefabManager::GetInstance().HasPrefab(name)) {
            instance = PrefabManager::GetInstance().InstantiatePrefab(name);
        }
        else {
            // Try to find prefab in resources
            ModuleResources* resources = Application::GetInstance().resources.get();

            // Search for prefab by matching filename in all resources
            UID prefabUID = 0;
            const auto& allResources = resources->GetAllResources();

            for (const auto& pair : allResources) {
                UID uid = pair.first;
                Resource* res = pair.second;

                if (res->GetType() == Resource::PREFAB) {
                    std::string assetPath = res->GetAssetFile();

                    // Extract filename from path
                    size_t lastSlash = assetPath.find_last_of("/\\");
                    std::string filename = (lastSlash != std::string::npos)
                        ? assetPath.substr(lastSlash + 1)
                        : assetPath;

                    // Match either by filename or by exact path
                    if (filename == name || assetPath == name) {
                        prefabUID = uid;
                        break;
                    }
                }
            }

            if (prefabUID != 0) {
                // Request the prefab resource
                Resource* res = resources->RequestResource(prefabUID);
                if (res && res->GetType() == Resource::PREFAB) {
                    ResourcePrefab* prefabRes = static_cast<ResourcePrefab*>(res);
                    instance = prefabRes->Instantiate();

                    if (instance) {
                        // Enable all scripts in the instantiated object and its children
                        std::function<void(GameObject*)> enableScripts = [&](GameObject* obj) {
                            // Get all script components and call their Start()
                            auto components = obj->GetComponents();
                            for (auto* comp : components) {
                                if (comp->GetType() == ComponentType::SCRIPT) {
                                    ComponentScript* script = static_cast<ComponentScript*>(comp);
                                    if (script->IsActive()) {
                                        script->CallStart();
                                    }
                                }
                            }

                            // Recursively enable scripts in children
                            for (GameObject* child : obj->GetChildren()) {
                                enableScripts(child);
                            }
                            };

                        enableScripts(instance);
                    }
                }
            }
        }

        if (instance) {
            *udata = instance;
        }
        else {
            LOG_CONSOLE("[Lua] ERROR: Failed to instantiate prefab: %s", name);
        }
        });

    return 1;
}

void ScriptManager::RegisterPrefabAPI() {
    lua_newtable(L);

    lua_pushcfunction(L, Lua_Prefab_Load);
    lua_setfield(L, -2, "Load");

    lua_pushcfunction(L, Lua_Prefab_Instantiate);
    lua_setfield(L, -2, "Instantiate");

    lua_setglobal(L, "Prefab");

}

static GameWindow* GetGameWindow() {
    #ifndef WAVE_GAME
    GameWindow* window = Application::GetInstance().editor->GetGameWindow();
    return window;
    #endif // !1
}