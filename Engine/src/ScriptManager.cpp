#include "ScriptManager.h"
#include "Application.h"
#include "Input.h"
#include "Time.h"
#include "Log.h"
#include "Transform.h"
#include "GameObject.h"
#include "Component.h"
#include "AudioListener.h"
#include "ModuleScene.h"
#include "ModuleLoader.h"
#include "ComponentMesh.h"
#include "ComponentMaterial.h"
#include "ComponentScript.h"
#include "NavMeshManager.h"
#include "ComponentNavigation.h"
#include "ModuleResources.h"
#include "PrefabManager.h"
#include "ResourcePrefab.h"
#include "ComponentCanvas.h"
#include "ComponentCamera.h" 
#include "Rigidbody.h"
#include "Window.h"        
#include "ModuleCamera.h"  
#include "ModuleAudio.h"
#include "FileSystem.h"
#include <SDL3/SDL_scancode.h>
#include "GameWindow.h"
#ifndef WAVE_GAME
#include "EditorWindow.h"
#include "ModuleEditor.h"
#endif
#include "ConsoleWindow.h"
#include "Application.h"
#include "ComponentAnimation.h"
#include "ComponentParticleSystem.h"
#include "UIManager.h"
#include "LibraryManager.h"
#include "ResourceScript.h"

#include <algorithm>
#include <filesystem>
#include <cmath>

static int LuaCustomRequire(lua_State* L) {
    const char* moduleName = luaL_checkstring(L, 1);
    std::string fileName = std::string(moduleName) + ".lua";

    // replace the dots for / because in lua is inverse
    std::replace(fileName.begin(), fileName.end(), '.', '/');

    auto& resources = Application::GetInstance().resources->GetAllResources();
    UID foundUID = 0;

    for (const auto& pair : resources) {
        if (pair.second->GetType() == Resource::SCRIPT) {
            std::string path = pair.second->GetAssetFile();
            // Check path of the resource ends with the filename
            if (path.length() >= fileName.length() &&
                path.compare(path.length() - fileName.length(), fileName.length(), fileName) == 0)
            {
                foundUID = pair.first;
                break;
            }
        }
    }

    if (foundUID != 0) {
        // RequestResource loads and unlocks the script with the ScriptImporter
        ResourceScript* scriptRes = (ResourceScript*)Application::GetInstance().resources->RequestResource(foundUID);
        if (scriptRes) {
            const std::string& content = scriptRes->GetScriptContent();

            // Compile the text of the script
            if (luaL_loadbuffer(L, content.c_str(), content.size(), moduleName) != LUA_OK) {
                LOG_CONSOLE("[Lua] ERROR compiling module '%s': %s", moduleName, lua_tostring(L, -1));
                return 1;
            }
            return 1; // Sucess then return the chunk compiled
        }
    }

    // Not found
    std::string err = "\n\tcouldn't find the script in Assets: '" + fileName + "'";
    lua_pushstring(L, err.c_str());
    return 1;
}

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

    // Custom require Lua
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "searchers");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, -1, "loaders");
    }
    if (lua_istable(L, -1)) {
        lua_pushcfunction(L, LuaCustomRequire);
        lua_rawseti(L, -2, 2);
    }
    lua_pop(L, 2);

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

    if (!pendingSceneLoad.empty()) {
        std::string path = pendingSceneLoad;
        pendingSceneLoad.clear();
       
        Application::GetInstance().loader->LoadScene(path);
        
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
    {"R", SDL_SCANCODE_R}, {"F", SDL_SCANCODE_F}, {"G", SDL_SCANCODE_G},
    {"Z", SDL_SCANCODE_Z}, {"X", SDL_SCANCODE_X}, {"C", SDL_SCANCODE_C},
    {"V", SDL_SCANCODE_V}, {"B", SDL_SCANCODE_B}, {"N", SDL_SCANCODE_N},
    {"M", SDL_SCANCODE_M}, {"J", SDL_SCANCODE_J}, {"K", SDL_SCANCODE_K}, 
    {"L", SDL_SCANCODE_L}, {"U", SDL_SCANCODE_U}, {"I", SDL_SCANCODE_I},
    {"O", SDL_SCANCODE_O}, {"P", SDL_SCANCODE_P}, {"Y", SDL_SCANCODE_Y},
    {"H", SDL_SCANCODE_H}, {"T", SDL_SCANCODE_T},
    {"Space", SDL_SCANCODE_SPACE}, {"Escape", SDL_SCANCODE_ESCAPE},
    {"LeftShift", SDL_SCANCODE_LSHIFT}, {"RightShift", SDL_SCANCODE_RSHIFT},
    {"LeftCtrl", SDL_SCANCODE_LCTRL}, {"RightCtrl", SDL_SCANCODE_RCTRL},
    {"G", SDL_SCANCODE_G},
    {"1", SDL_SCANCODE_1}, {"2", SDL_SCANCODE_2}, {"3", SDL_SCANCODE_3},
    {"4", SDL_SCANCODE_4}, {"5", SDL_SCANCODE_5}, {"6", SDL_SCANCODE_6},
    {"7", SDL_SCANCODE_7}, {"8", SDL_SCANCODE_8}, {"9", SDL_SCANCODE_9},
	{"0", SDL_SCANCODE_0}, {"P", SDL_SCANCODE_P}, {"F1", SDL_SCANCODE_F1},
	{"F2", SDL_SCANCODE_F2}, {"F3", SDL_SCANCODE_F3}, {"F4", SDL_SCANCODE_F4},
	{"F5", SDL_SCANCODE_F5}, {"F6", SDL_SCANCODE_F6}, {"F7", SDL_SCANCODE_F7},
	{"F8", SDL_SCANCODE_F8}, {"F9", SDL_SCANCODE_F9}, {"F10", SDL_SCANCODE_F10},
	{"F11", SDL_SCANCODE_F11}, {"F12", SDL_SCANCODE_F12}
};

static int Lua_Input_GetKey(lua_State* L) {
    const char* keyName = luaL_checkstring(L, 1);
    auto it = keyMap.find(keyName);
    bool pressed = (it != keyMap.end()) &&
        Application::GetInstance().input->GetKey(it->second) == KEY_REPEAT;
    lua_pushboolean(L, pressed);
    return 1;
}

static int Lua_Engine_LoadScene(lua_State* L) {
    const char* scenesPath = luaL_checkstring(L, 1);
    const char* relativePath = luaL_checkstring(L, 2);
    std::string normalizedPath = relativePath;
    
    std::replace(normalizedPath.begin(), normalizedPath.end(), '/', '\\');
  

    //while (normalizedPath.rfind("../", 0) == 0)
    //    normalizedPath.erase(0, 2);

    //std::replace(normalizedPath.begin(), normalizedPath.end(), '/', '\\');

    std::string absolutePath = std::string(scenesPath).append(normalizedPath);

    
    Application::GetInstance().scripts->pendingSceneLoad = absolutePath;
    return 0;
}

static int Lua_Engine_GetScenesPath(lua_State* L) {
    std::string path = (std::filesystem::path(FileSystem::GetAssetsRoot()) / "Scenes\\" ).string();
    lua_pushstring(L, path.c_str());
    return 1;
}

static int Lua_Engine_GetCurrentScene(lua_State* L) {

    std::string sceneName = Application::GetInstance().scene.get()->name;
    lua_pushstring(L, sceneName.c_str());
    return 1;
}

static int Lua_Engine_GetAssetsPath(lua_State* L) {
    std::string path = (std::filesystem::path(FileSystem::GetAssetsRoot())).string();
    lua_pushstring(L, path.c_str());
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

static int Lua_Navigation_GetRandomPoint(lua_State* L)
{
    ComponentNavigation** navPtr =
        static_cast<ComponentNavigation**>(luaL_checkudata(L, 1, "Navigation"));
    ComponentNavigation* nav = *navPtr;

    glm::vec3 point;
    bool ok = false;

    if (nav && nav->linkedSurface)
        ok = Application::GetInstance().navMesh->GetRandomPoint(nav->linkedSurface, point);

    if (ok)
    {
        lua_pushnumber(L, point.x);
        lua_pushnumber(L, point.y);
        lua_pushnumber(L, point.z);
        return 3;
    }

    lua_pushnil(L);
    return 1;
}

static int Lua_Time_GetDeltaTime(lua_State* L) {
    lua_pushnumber(L, Time::GetDeltaTimeStatic());
    return 1;
}

static int Lua_Navigation_SetDestination(lua_State* L)
{

    ComponentNavigation** navPtr =
        static_cast<ComponentNavigation**>(luaL_checkudata(L, 1, "Navigation"));

    ComponentNavigation* nav = *navPtr;

    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float z = (float)luaL_checknumber(L, 4);

    bool ok = nav->SetDestination(glm::vec3(x, y, z));

    lua_pushboolean(L, ok);
    return 1;

}

static int Lua_Navigation_StopMovement(lua_State* L)
{
    ComponentNavigation** navPtr = static_cast<ComponentNavigation**>(
        luaL_checkudata(L, 1, "Navigation")
        );

    ComponentNavigation* nav = *navPtr;

    nav->StopMovement();

    return 0;

}

static int Lua_Navigation_IsMoving(lua_State* L)
{
    ComponentNavigation* nav = *static_cast<ComponentNavigation**>(lua_touserdata(L, 1));
    lua_pushboolean(L, nav ? nav->IsMoving() : false);
    return 1;
}

static int Lua_Navigation_Update(lua_State* L)
{
    ComponentNavigation* nav = *static_cast<ComponentNavigation**>(lua_touserdata(L, 1));
    float dt = static_cast<float>(luaL_checknumber(L, 2));
    if (nav) nav->Update(dt);
    return 0;
}

static int Lua_Navigation_GetCurrentWaypoint(lua_State* L)
{
    ComponentNavigation* nav = *static_cast<ComponentNavigation**>(lua_touserdata(L, 1));
    if (!nav || nav->path.empty() || nav->pathIndex >= (int)nav->path.size())
    {
        lua_pushnil(L);
        return 1;
    }
    const glm::vec3& wp = nav->path[nav->pathIndex];
    lua_pushnumber(L, wp.x);
    lua_pushnumber(L, wp.y);
    lua_pushnumber(L, wp.z);
    return 3;
}

static int Lua_Navigation_AdvanceWaypoint(lua_State* L)
{
    ComponentNavigation* nav = *static_cast<ComponentNavigation**>(lua_touserdata(L, 1));
    float posX = static_cast<float>(luaL_checknumber(L, 2));
    float posZ = static_cast<float>(luaL_checknumber(L, 3));
    float threshold = static_cast<float>(luaL_optnumber(L, 4, 0.25));

    if (!nav || nav->path.empty() || nav->pathIndex >= (int)nav->path.size())
    {
        lua_pushboolean(L, false);
        return 1;
    }

    const glm::vec3& wp = nav->path[nav->pathIndex];
    float dx = posX - wp.x;
    float dz = posZ - wp.z;
    float dist = std::sqrt(dx * dx + dz * dz);

    if (dist <= threshold)
    {
        nav->pathIndex++;
        if (nav->pathIndex >= (int)nav->path.size())
        {
            nav->moving = false;
            nav->path.clear();
            nav->pathIndex = 0;
            lua_pushboolean(L, false);
            return 1;
        }
    }

    lua_pushboolean(L, true);
    return 1;
}

static int Lua_Navigation_GetMoveDirection(lua_State* L)
{
    ComponentNavigation** navPtr =
        static_cast<ComponentNavigation**>(luaL_checkudata(L, 1, "Navigation"));

    ComponentNavigation* nav = *navPtr;

    float threshold = (float)luaL_optnumber(L, 2, 0.3f);

    float dx = 0.0f;
    float dz = 0.0f;

    nav->GetMoveDirection(threshold, dx, dz);

    lua_pushnumber(L, dx);
    lua_pushnumber(L, dz);
    return 2;

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


//Audio
//BGM Transitions
static int Lua_Audio_SetMusicState(lua_State* L) {
    const char* stateName = luaL_checkstring(L, 1);
    const char* stateGroupName = "BGM_State";
    /*stateName = std::toupper(stateName.c_str());*/
    
    Application::GetInstance().audio.get()->audioSystem->SetState(stateGroupName, stateName);
    AK::SoundEngine::RenderAudio();
    return 0;
}

//Audio Switches
static int Lua_Audio_SetSwitch(lua_State* L) {
    
    const char* switchGroupName = luaL_checkstring(L, 1);
    const char* switchStateName = luaL_checkstring(L, 2);
    lua_getfield(L, 3, "ptr");                             // slot 3: the table (component)
    AudioSource* source = *static_cast<AudioSource**>(lua_touserdata(L, -1));

    Application::GetInstance().audio.get()->audioSystem->SetSwitch(switchGroupName, switchStateName, source->goID);
    AK::SoundEngine::RenderAudio();
    return 0;
}

static int Lua_Audio_PlayAudioEvent(lua_State* L) {
    lua_getfield(L, 1, "ptr");  // get "ptr" from the table (slot 1)
    AudioSource* source = *static_cast<AudioSource**>(lua_touserdata(L, -1));

    std::wstring wEventName(source->eventName.begin(), source->eventName.end());

    Application::GetInstance().audio.get()->audioSystem->PlayEvent(wEventName.c_str(), source->goID);
    AK::SoundEngine::RenderAudio();
    return 0;
}

static int Lua_Audio_SelectPlayAudioEvent(lua_State* L) {
    lua_getfield(L, 1, "ptr");  // get "ptr" from the table (slot 1)
    AudioSource* source = *static_cast<AudioSource**>(lua_touserdata(L, -1));
    std::string eventName(luaL_checkstring(L, 2));
    std::wstring wEventName(eventName.begin(), eventName.end());

    Application::GetInstance().audio.get()->audioSystem->PlayEvent(wEventName.c_str(), source->goID);
    AK::SoundEngine::RenderAudio();

    source->eventName = eventName;
    return 0;
}


static int  Lua_Audio_StopAudioEvent(lua_State* L) {
    lua_getfield(L, 1, "ptr");  // get "ptr" from the table (slot 1)
    AudioSource* source = *static_cast<AudioSource**>(lua_touserdata(L, -1));

    std::wstring wEventName(source->eventName.begin(), source->eventName.end());
    Application::GetInstance().audio.get()->audioSystem->StopEvent(wEventName.c_str(), source->goID);
    return 0;
}

static int Lua_Audio_SetSourceVolume(lua_State* L) {
    lua_getfield(L, 1, "ptr");  
    float volume = luaL_checknumber(L, 2);
    AudioSource* source = *static_cast<AudioSource**>(lua_touserdata(L, -1));
    Application::GetInstance().audio.get()->audioSystem->SetAudioSourceVolume(volume, source->goID);

    AK::SoundEngine::RenderAudio();
    return 0;
}

static int Lua_Audio_SetGlobalVolume(lua_State* L) {
    //lua_getfield(L, 1, "ptr");  
    float volume = static_cast<float>(luaL_checknumber(L, 1));
    //AudioSource* source = *static_cast<AudioSource**>(lua_touserdata(L, -1));
    Application::GetInstance().audio.get()->audioSystem->SetGlobalVolume(volume);

    AK::SoundEngine::RenderAudio();
    return 0;
}

static int Lua_Audio_SetAsDefaultListener(lua_State* L) {
    lua_getfield(L, 1, "ptr");  
    AudioListener* listener = *static_cast<AudioListener**>(lua_touserdata(L, -1));
    if (listener) {
        listener->SetAsDefaultListener();
    }
    return 0;
}

// UI
// UI.WasClicked("ButtonName") → bool
static int Lua_UI_WasClicked(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);
    lua_pushboolean(L, UIManager::GetInstance().WasButtonJustClicked(name));
    return 1;
}

// UI
// UI.WasFocused("ButtonName") → bool
static int Lua_UI_WasFocused(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);
    lua_pushboolean(L, UIManager::GetInstance().WasButtonJustFocused(name));
    return 1;
}

static int Lua_UI_GetCanvasButtons(lua_State* L) {
    
    std::unordered_set<std::string> allButtons = UIManager::GetInstance().GetCanvasButtons();

    LOG_CONSOLE("[UI] GetCanvasButtons called, count: %d", (int)allButtons.size());
    lua_newtable(L);
    int index = 1;
    for (const auto& name : allButtons) {
        lua_pushstring(L, name.c_str());
        lua_rawseti(L, -2, index++);
    }
    return 1;
}

// UI.SetElementHeight("GridName", 42.0)
static int Lua_UI_SetElementHeight(lua_State* L) {
    std::string name(luaL_checkstring(L, 1));
    float height = static_cast<float>(luaL_checknumber(L, 2));
    UIManager::GetInstance().SetElementHeight(name, height);
    return 0;
}

// UI.SetElementWidth("GridName", 42.0)
static int Lua_UI_SetElementWidth(lua_State* L) {
    std::string name(luaL_checkstring(L, 1));
    float width = static_cast<float>(luaL_checknumber(L, 2));
    UIManager::GetInstance().SetElementWidth(name, width);
    return 0;
}

// UI.SetElementText("TextBlockName", "Hello")
static int Lua_UI_SetElementText(lua_State* L) {
    std::string name(luaL_checkstring(L, 1));
    std::string text(luaL_checkstring(L, 2));
    Application::GetInstance().scripts->EnqueueOperation([name, text]() {
        UIManager::GetInstance().SetElementText(name, text);
        });
    return 0;
}

// UI.SetElementVisibility("ImageName", true/false)
static int Lua_UI_SetElementVisibility(lua_State* L) {
    std::string name(luaL_checkstring(L, 1));
    bool visible = lua_toboolean(L, 2) != 0;
    Application::GetInstance().scripts->EnqueueOperation([name, visible]() {
        UIManager::GetInstance().SetElementVisibility(name, visible);
        });
    return 0;
}

// Game API
static int Lua_Game_Exit(lua_State* L) {
    Application::GetInstance().RequestExit();
    return 0;
}

static int Lua_Game_Pause(lua_State* L) {
    Application::GetInstance().PauseGameOnly();
    return 0;
}

static int Lua_Game_Resume(lua_State* L) {
    Application::GetInstance().Play();
    return 0;
}


// Forward declarations
static int Lua_Rigidbody_SetLinearVelocity(lua_State* L);
static int Lua_Rigidbody_GetLinearVelocity(lua_State* L);
static int Lua_Rigidbody_AddForce(lua_State* L);

void ScriptManager::RegisterEngineFunctions() {
    if (!L) {
        LOG_CONSOLE("[ScriptManager] ERROR: Cannot register functions, Lua state is null");
        return;
    }

    LOG_CONSOLE("[ScriptManager] Registering engine functions...");

    // Engine
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Engine_Log);
    lua_setfield(L, -2, "Log");
    lua_pushcfunction(L, Lua_Engine_LoadScene);
    lua_setfield(L, -2, "LoadScene");
    lua_pushcfunction(L, Lua_Engine_GetScenesPath);
    lua_setfield(L, -2, "GetScenesPath");
    lua_pushcfunction(L, Lua_Engine_GetAssetsPath);
    lua_setfield(L, -2, "GetAssetsPath");
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


    //Audio
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Audio_SetMusicState);
    lua_setfield(L, -2, "SetMusicState");
    lua_pushcfunction(L, Lua_Audio_PlayAudioEvent);
    lua_setfield(L, -2, "PlayAudioEvent");
    lua_pushcfunction(L, Lua_Audio_SelectPlayAudioEvent);
    lua_setfield(L, -2, "SelectPlayAudioEvent");
    lua_pushcfunction(L, Lua_Audio_StopAudioEvent);
    lua_setfield(L, -2, "StopAudioEvent");
    lua_pushcfunction(L, Lua_Audio_SetSwitch);
    lua_setfield(L, -2, "SetSwitch");
    lua_pushcfunction(L, Lua_Audio_SetSourceVolume);
    lua_setfield(L, -2, "SetSourceVolume");
    lua_pushcfunction(L, Lua_Audio_SetGlobalVolume);
    lua_setfield(L, -2, "SetGlobalVolume");
    lua_setglobal(L, "Audio");

    
    //Navigation

    luaL_newmetatable(L, "Navigation");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, Lua_Navigation_SetDestination);
    lua_setfield(L, -2, "SetDestination");
    lua_pushcfunction(L, Lua_Navigation_StopMovement);
    lua_setfield(L, -2, "StopMovement");
    lua_pushcfunction(L, Lua_Navigation_IsMoving);
    lua_setfield(L, -2, "IsMoving");
    lua_pushcfunction(L, Lua_Navigation_Update);
    lua_setfield(L, -2, "Update");
    lua_pushcfunction(L, Lua_Navigation_GetCurrentWaypoint);
    lua_setfield(L, -2, "GetCurrentWaypoint");
    lua_pushcfunction(L, Lua_Navigation_AdvanceWaypoint);
    lua_setfield(L, -2, "AdvanceWaypoint");
    lua_pushcfunction(L, Lua_Navigation_GetMoveDirection);
    lua_setfield(L, -2, "GetMoveDirection");

    lua_pushcfunction(L, Lua_Navigation_GetRandomPoint);
    lua_setfield(L, -2, "GetRandomPoint");



    lua_pop(L, 1);

    //UI
    lua_newtable(L);
    lua_pushcfunction(L, Lua_UI_WasClicked);            lua_setfield(L, -2, "WasClicked");
    lua_pushcfunction(L, Lua_UI_WasFocused);            lua_setfield(L, -2, "WasFocused");
    lua_pushcfunction(L, Lua_UI_GetCanvasButtons);      lua_setfield(L, -2, "GetCanvasButtons");
    lua_pushcfunction(L, Lua_UI_SetElementHeight);      lua_setfield(L, -2, "SetElementHeight");
    lua_pushcfunction(L, Lua_UI_SetElementWidth);       lua_setfield(L, -2, "SetElementWidth");
    lua_pushcfunction(L, Lua_UI_SetElementText);        lua_setfield(L, -2, "SetElementText");
    lua_pushcfunction(L, Lua_UI_SetElementVisibility);  lua_setfield(L, -2, "SetElementVisibility");
    lua_setglobal(L, "UI");


    // GAMEOBJECT API
    // Game
    lua_newtable(L);
    lua_pushcfunction(L, Lua_Game_Pause);
    lua_setfield(L, -2, "Pause");
    lua_pushcfunction(L, Lua_Game_Resume);
    lua_setfield(L, -2, "Resume");

    //time scale
    lua_pushcfunction(L, +[](lua_State* L) -> int {
        float scale = (float)luaL_checknumber(L, 1);
        Application::GetInstance().time->SetTimeScale(scale);
        return 0;
        });
    lua_setfield(L, -2, "SetTimeScale");

    lua_pushcfunction(L, +[](lua_State* L) -> int {
        lua_pushnumber(L, Application::GetInstance().time->GetTimeScale());
        return 1;
        });
    lua_setfield(L, -2, "GetTimeScale");

    lua_pushcfunction(L, Lua_Game_Exit);
    lua_setfield(L, -2, "Exit");
    lua_setglobal(L, "Game");

    LOG_CONSOLE("[ScriptManager] Engine functions registered: Engine, Input, Time, Camera, Audio, Navigation, UI, Game");
}

// -------------------------- GAMEOBJECT API -------------------------------------

// Rigidbody

static int Lua_Rigidbody_SetLinearVelocity(lua_State* L) {
    Rigidbody* rb = *static_cast<Rigidbody**>(luaL_checkudata(L, 1, "Rigidbody"));
    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));
    if (rb) rb->SetLinearVelocity(glm::vec3(x, y, z));
    return 0;
}

static int Lua_Rigidbody_GetLinearVelocity(lua_State* L) {
    Rigidbody* rb = *static_cast<Rigidbody**>(luaL_checkudata(L, 1, "Rigidbody"));
    glm::vec3 vel(0.0f);
    if (rb) vel = rb->GetLinearVelocity();
    lua_newtable(L);
    lua_pushnumber(L, vel.x); lua_setfield(L, -2, "x");
    lua_pushnumber(L, vel.y); lua_setfield(L, -2, "y");
    lua_pushnumber(L, vel.z); lua_setfield(L, -2, "z");
    return 1;
}

static int Lua_Rigidbody_AddForce(lua_State* L) {
    Rigidbody* rb = *static_cast<Rigidbody**>(luaL_checkudata(L, 1, "Rigidbody"));
    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));
    // modes: 1=FORCE(default), 2=IMPULSE, 3=VELOCITY_CHANGE, 4=ACCELERATION
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

static int Lua_Rigidbody_MovePosition(lua_State* L) {
    Rigidbody* rb = *static_cast<Rigidbody**>(luaL_checkudata(L, 1, "Rigidbody"));
    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));
    if (rb) rb->MovePosition(glm::vec3(x, y, z));
    return 0;
}

static int Lua_Rigidbody_SetRotation(lua_State* L) {
    Rigidbody* rb = *static_cast<Rigidbody**>(luaL_checkudata(L, 1, "Rigidbody"));
    float x = static_cast<float>(luaL_checknumber(L, 2));
    float y = static_cast<float>(luaL_checknumber(L, 3));
    float z = static_cast<float>(luaL_checknumber(L, 4));
    if (rb) rb->SetRotation(glm::vec3(x, y, z));
    return 0;
}

static int Lua_Rigidbody_SetUseGravity(lua_State* L) {
    Rigidbody* rb = *static_cast<Rigidbody**>(luaL_checkudata(L, 1, "Rigidbody"));
    bool useGravity = lua_toboolean(L, 2);
    if (rb) rb->SetUseGravity(useGravity);
    return 0;
}

// Animation

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

static int Lua_Animation_SetAnimSpeed(lua_State* L) {
    ComponentAnimation* anim = *static_cast<ComponentAnimation**>(lua_touserdata(L, 1));
    std::string animName = luaL_checkstring(L, 2);
    float newSpeed = luaL_checknumber(L, 3);
    

    if (anim) {
        anim->SetAnimationSpeed(animName, newSpeed);
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

static int Lua_GameObject_GetScript(lua_State* L) {
    GameObject* go = *static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));
    if (go) {
        // Buscamos el componente script en el objeto
        ComponentScript* scriptComp = (ComponentScript*)go->GetComponent(ComponentType::SCRIPT);
        if (scriptComp) {
            // Como usas tablas con nombres únicos en el global scope:
            std::string tableName = scriptComp->GetLuaTableName(); // Necesitas este getter en ComponentScript
            lua_getglobal(L, tableName.c_str());
            if (lua_istable(L, -1)) {
                return 1; // Devolvemos la tabla del script
            }
            lua_pop(L, 1);
        }
    }
    lua_pushnil(L);
    return 1;
}

static int Lua_GameObject_SetPersistency(lua_State* L)
{
    GameObject** udata = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));
    bool isPersistent = (bool)luaL_checkinteger(L, 2);

    if (!udata || !*udata) {
        LOG_CONSOLE("[Lua] ERROR: Invalid GameObject in SetPersistency()");
        return 0;
    }

    GameObject* obj = *udata;
    //obj->SetPersistency(isPersistent);

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

// go = GameObject.FindInChildren(parentGOname, targetGOname)
static int Lua_GameObject_FindInChildren(lua_State* L) {
    
    GameObject** objPtr = static_cast<GameObject**>(luaL_checkudata(L, 1, "GameObject"));

    if (!objPtr || !*objPtr || (*objPtr)->IsMarkedForDeletion()) {
        LOG_CONSOLE("[Lua] ERROR: Cannot FindInChildren on invalid/deleted GameObject");
        return 0;
    }

    GameObject* obj = *objPtr;

    const char* name = luaL_checkstring(L, 2);

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

    GameObject* found = findByName(obj, name);

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

static int Lua_GameObject_FindByTag(lua_State* L) {
    const char* tag = luaL_checkstring(L, 1);

    GameObject* root = Application::GetInstance().scene->GetRoot();
    if (!root) {
        lua_pushnil(L);
        return 1;
    }
    std::vector<GameObject*> results;

    std::function<void (GameObject*, const std::string&)> findByTag;
    findByTag = [&](GameObject* node, const std::string& targetTag) {
        if (node->GetTag() == targetTag) {
            results.push_back(node);
        }
        for (GameObject* child : node->GetChildren()) {
            findByTag(child, targetTag);
        }
     };

    findByTag(root, tag);

    if (results.empty()) {
        lua_pushnil(L);
        return 1;
    }

    // Crear tabla Lua
    lua_newtable(L);

    int index = 1;
    for (GameObject* obj : results) {
        GameObject** udata = static_cast<GameObject**>(lua_newuserdata(L, sizeof(GameObject*)));
        *udata = obj;

        luaL_getmetatable(L, "GameObject");
        lua_setmetatable(L, -2);

        lua_rawseti(L, -2, index++);
    }

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
    //FIXMAT
    //auto& app = Application::GetInstance();
    //app.scripts->EnqueueOperation([mat, textureUID]() {
    //    mat->LoadTextureByUID(textureUID);
    //    });

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
    //FIXMAT
    //auto& app = Application::GetInstance();
    //app.scripts->EnqueueOperation([mat, textureUID]() {
    //    mat->LoadTextureByUID(textureUID);
    //    });

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
// Particle system Lua Universal Bindings
// All functions follow the same pattern used by Animation:
// local ps = self.gameObject:GetComponent("ParticleSystem")
// ps:Play() - start of restart emission
// ps:Stop() - stop emission and let particles die
// ps:Burst(50) - fire x particles instantly
// ps:SetEmissionRate(30) - Change emission rate
// ps:SetLooping(false) - change to finite duration mode
// ps:SetDuration(0.3) - emit for 0.X s and stop
// ps:SetOneShotMode(true, 20) - burst of X on Play()
// local alive   = ps:IsAlive() - bool to check
// local playing = ps:IsPlaying() - bool to check if particles exists on world
static int Lua_ParticleSystem_Play(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    if (ps) ps->Play();
    return 0;
}

static int Lua_ParticleSystem_Stop(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    if (ps) ps->Stop();
    return 0;
}

// ps:Burst(count) fires count particles
static int Lua_ParticleSystem_Burst(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    int count = static_cast<int>(luaL_optinteger(L, 2, 30));
    if (ps) ps->ScriptBurst(count);
    return 0;
}

// ps:SetEmissionRate(rate) 0 = pause, changing and calling this number will modify by script the emissionrate
static int Lua_ParticleSystem_SetEmissionRate(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    float rate = static_cast<float>(luaL_checknumber(L, 2));
    if (ps) ps->SetEmissionRate(rate);
    return 0;
}

// ps:IsPlaying() is a bool to check
static int Lua_ParticleSystem_IsPlaying(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    lua_pushboolean(L, ps ? ps->IsPlaying() : false);
    return 1;
}

// ps:IsAlive() bool to check if there is any particle left on the world
// Example: while ps:IsAlive() do whatever
static int Lua_ParticleSystem_IsAlive(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    lua_pushboolean(L, ps ? ps->IsAlive() : false);
    return 1;
}

// ps:SetLooping(bool)
static int Lua_ParticleSystem_SetLooping(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    bool looping = lua_toboolean(L, 2) != 0;
    if (ps) ps->SetLooping(looping);
    return 0;
}

// ps:SetDuration(seconds) in seconds to emit when looping=false
static int Lua_ParticleSystem_SetDuration(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    float seconds = static_cast<float>(luaL_checknumber(L, 2));
    if (ps) ps->SetDuration(seconds);
    return 0;
}

// ps->SetOneShotMode(enabled, count) fires exactly count particles and stops, created for sword slash or impacts
static int Lua_ParticleSystem_SetOneShotMode(lua_State* L) {
    ComponentParticleSystem* ps =
        *static_cast<ComponentParticleSystem**>(lua_touserdata(L, 1));
    bool enabled = lua_toboolean(L, 2) != 0;
    int count = static_cast<int>(luaL_optinteger(L, 3, 30));
    if (ps) ps->SetOneShotMode(enabled, count);
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
   
    if (strcmp(componentType, "Rigidbody") == 0)
    {
        Component* comp = obj->GetComponent(ComponentType::RIGIDBODY);
        Rigidbody* rb = static_cast<Rigidbody*>(comp);
        if (!rb) { lua_pushnil(L); return 1; }

        Rigidbody** udata = static_cast<Rigidbody**>(
            lua_newuserdata(L, sizeof(Rigidbody*))
            );
        *udata = rb;

        luaL_getmetatable(L, "Rigidbody");
        lua_setmetatable(L, -2);
        return 1;
    }

    if (strcmp(componentType, "ParticleSystem") == 0) {
        Component* comp = obj->GetComponent(ComponentType::PARTICLE);
        ComponentParticleSystem* ps = static_cast<ComponentParticleSystem*>(comp);
        if (!ps) {
            lua_pushnil(L);
            return 1;
        }

        ComponentParticleSystem** udata = static_cast<ComponentParticleSystem**>(
            lua_newuserdata(L, sizeof(ComponentParticleSystem*))
            );
        *udata = ps;

        luaL_getmetatable(L, "ParticleSystem");
        lua_setmetatable(L, -2);

        return 1;
    }

    if (strcmp(componentType, "Box Collider") == 0 ||
        strcmp(componentType, "Sphere Collider") == 0 ||
        strcmp(componentType, "Capsule Collider") == 0 ||
        strcmp(componentType, "Convex Collider") == 0)
    {
        ComponentType ctype = ComponentType::BOX_COLLIDER;
        if (strcmp(componentType, "Sphere Collider") == 0)   ctype = ComponentType::SPHERE_COLLIDER;
        if (strcmp(componentType, "Capsule Collider") == 0)  ctype = ComponentType::CAPSULE_COLLIDER;
        if (strcmp(componentType, "Convex Collider") == 0)   ctype = ComponentType::CONVEX_COLLIDER;

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

    if (strcmp(componentType, "Navigation") == 0)
    {
        ComponentNavigation* nav = (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);

        if (nav) {
            ComponentNavigation** udata = (ComponentNavigation**)lua_newuserdata(L, sizeof(ComponentNavigation*));
            *udata = nav;
            luaL_getmetatable(L, "Navigation");
            lua_setmetatable(L, -2);
            return 1;
        }


    }
    
    if (strcmp(componentType, "Audio Source") == 0) {
        Component* comp = obj->GetComponent(ComponentType::AUDIOSOURCE);
        AudioSource* source = static_cast<AudioSource*>(comp);
        if (!source) {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);

        AudioSource** ud = (AudioSource**)lua_newuserdata(L, sizeof(AudioSource*));
        *ud = source;
        lua_setfield(L, -2, "ptr");  // store userdata in table as "ptr"

        lua_pushcfunction(L, Lua_Audio_PlayAudioEvent);  
        lua_setfield(L, -2, "PlayAudioEvent");

        lua_pushcfunction(L, Lua_Audio_SelectPlayAudioEvent);
        lua_setfield(L, -2, "SelectPlayAudioEvent");

        lua_pushcfunction(L, Lua_Audio_StopAudioEvent);
        lua_setfield(L, -2, "StopAudioEvent");

        lua_pushcfunction(L, Lua_Audio_SetSourceVolume);
        lua_setfield(L, -2, "SetSourceVolume");

        return 1;
    }

    if (strcmp(componentType, "Audio Listener") == 0) {
        Component* comp = obj->GetComponent(ComponentType::LISTENER);
        AudioListener* listener = static_cast<AudioListener*>(comp);
        if (!listener) {
            lua_pushnil(L);
            return 1;
        }

        lua_newtable(L);

        AudioListener** ud = (AudioListener**)lua_newuserdata(L, sizeof(AudioListener*));
        *ud = listener;
        lua_setfield(L, -2, "ptr");

        lua_pushcfunction(L, Lua_Audio_SetAsDefaultListener);
        lua_setfield(L, -2, "SetAsDefaultListener");

        return 1;
    }

    if (strcmp(componentType, "Script") == 0) {
        Component* comp = obj->GetComponent(ComponentType::SCRIPT);
        ComponentScript* scriptComp = static_cast<ComponentScript*>(comp);

        if (!scriptComp || !scriptComp->HasScript()) {
            lua_pushnil(L);
            return 1;
        }

        const std::string& tableName = scriptComp->GetLuaTableName();

        lua_getglobal(L, tableName.c_str());

        if (lua_istable(L, -1)) {
            return 1;
        }
        else {
            lua_pop(L, 1);
            lua_pushnil(L);
            return 1;
        }
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

    if (strcmp(key, "SetPersistency") == 0) {
        lua_pushcfunction(L, Lua_GameObject_SetPersistency);
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

    lua_pushcfunction(L, Lua_GameObject_GetScript);
    lua_setfield(L, -2, "GetScript");

    lua_pushcfunction(L, Lua_GameObject_SetPersistency);
    lua_setfield(L, -2, "SetPersistency");

    lua_pushcfunction(L, Lua_GameObject_Find);
    lua_setfield(L, -2, "Find");

    lua_pushcfunction(L, Lua_GameObject_FindInChildren);
    lua_setfield(L, -2, "FindInChildren");

    lua_pushcfunction(L, Lua_GameObject_FindByTag);
    lua_setfield(L, -2, "FindByTag");

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

    // Rigidbody metatable
    luaL_newmetatable(L, "Rigidbody");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, Lua_Rigidbody_SetLinearVelocity);
    lua_setfield(L, -2, "SetLinearVelocity");
    lua_pushcfunction(L, Lua_Rigidbody_GetLinearVelocity);
    lua_setfield(L, -2, "GetLinearVelocity");
    lua_pushcfunction(L, Lua_Rigidbody_AddForce);
    lua_setfield(L, -2, "AddForce");
    lua_pushcfunction(L, Lua_Rigidbody_MovePosition);
    lua_setfield(L, -2, "MovePosition");
    lua_pushcfunction(L, Lua_Rigidbody_SetRotation);
    lua_setfield(L, -2, "SetRotation");
    lua_pushcfunction(L, Lua_Rigidbody_SetUseGravity);
    lua_setfield(L, -2, "SetUseGravity");
    lua_pop(L, 1);

    // Animation metatable separada
    luaL_newmetatable(L, "Animation");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, Lua_Animation_Play);
    lua_setfield(L, -2, "Play");
    lua_pushcfunction(L, Lua_Animation_SetAnimSpeed);
    lua_setfield(L, -2, "SetSpeed");
    lua_pushcfunction(L, Lua_Animation_Stop);
    lua_setfield(L, -2, "Stop");
    lua_pushcfunction(L, Lua_Animation_IsPlaying);
    lua_setfield(L, -2, "IsPlaying");
    lua_pushcfunction(L, Lua_Animation_IsPlayingAnimation);
    lua_setfield(L, -2, "IsPlayingAnimation");
    lua_pop(L, 1); 

    luaL_newmetatable(L, "ParticleSystem");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, Lua_ParticleSystem_Play);
    lua_setfield(L, -2, "Play");
    lua_pushcfunction(L, Lua_ParticleSystem_Stop);
    lua_setfield(L, -2, "Stop");
    lua_pushcfunction(L, Lua_ParticleSystem_Burst);
    lua_setfield(L, -2, "Burst");
    lua_pushcfunction(L, Lua_ParticleSystem_SetEmissionRate);
    lua_setfield(L, -2, "SetEmissionRate");
    lua_pushcfunction(L, Lua_ParticleSystem_IsPlaying);
    lua_setfield(L, -2, "IsPlaying");
    lua_pushcfunction(L, Lua_ParticleSystem_IsAlive);
    lua_setfield(L, -2, "IsAlive");
    lua_pushcfunction(L, Lua_ParticleSystem_SetLooping);
    lua_setfield(L, -2, "SetLooping");
    lua_pushcfunction(L, Lua_ParticleSystem_SetDuration);
    lua_setfield(L, -2, "SetDuration");
    lua_pushcfunction(L, Lua_ParticleSystem_SetOneShotMode);
    lua_setfield(L, -2, "SetOneShotMode");
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

                    // Normalise slashes
                    std::string normalizedAsset = assetPath;
                    std::replace(normalizedAsset.begin(), normalizedAsset.end(), '\\', '/');
                    std::string normalizedName = name;
                    std::replace(normalizedName.begin(), normalizedName.end(), '\\', '/');

                    // Retrieve the filename of the asset 
                    size_t lastSlash = normalizedAsset.find_last_of("/");
                    std::string filename = (lastSlash != std::string::npos)
                        ? normalizedAsset.substr(lastSlash + 1)
                        : normalizedAsset;

                    // Extract the filename from the search term
                    size_t nameLastSlash = normalizedName.find_last_of("/");
                    std::string nameFilename = (nameLastSlash != std::string::npos)
                        ? normalizedName.substr(nameLastSlash + 1)
                        : normalizedName;


                    bool matchExact = normalizedAsset == normalizedName;
                    bool matchSuffix = normalizedAsset.size() >= normalizedName.size() &&
                        normalizedAsset.substr(normalizedAsset.size() - normalizedName.size()) == normalizedName;
                    bool matchFilename = filename == nameFilename;

                    if (matchExact || matchSuffix || matchFilename) {
                        prefabUID = uid;
                        break;
                    }
                }
            }

            if (prefabUID != 0) {
                Resource* res = resources->RequestResource(prefabUID);
                if (res && res->GetType() == Resource::PREFAB) {
                    ResourcePrefab* prefabRes = static_cast<ResourcePrefab*>(res);

                    if (!prefabRes->IsLoadedToMemory()) {
                        prefabRes->LoadInMemory();
                    }

                    nlohmann::json hierarchy = prefabRes->GetPrefabHierarchy();

                    if (!hierarchy.is_null() && !hierarchy.empty()) {
                        ModuleScene* scene = Application::GetInstance().scene.get();

                        if (hierarchy.is_array()) {
                            instance = GameObject::Deserialize(hierarchy[0], scene->GetRoot());
                        }
                        else {
                            instance = GameObject::Deserialize(hierarchy, scene->GetRoot());
                        }

                        if (instance) {
                            instance->SolveReferences();

                            std::function<void(GameObject*)> enableScripts = [&](GameObject* obj) {
                                for (auto* comp : obj->GetComponents()) {
                                    if (comp->GetType() == ComponentType::SCRIPT) {
                                        ComponentScript* script = static_cast<ComponentScript*>(comp);
                                        if (script->IsActive()) {
                                            script->CallStart();
                                        }
                                    }
                                }
                                for (GameObject* child : obj->GetChildren()) {
                                    enableScripts(child);
                                }
                                };
                            enableScripts(instance);
                        }
                    }
                }
            }
            else {
                LOG_CONSOLE("[Lua] ERROR: Prefab no encontrado en recursos: %s", name);
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