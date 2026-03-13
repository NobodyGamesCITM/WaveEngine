// ScriptManager.h
#pragma once

#include "Module.h"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <string>
#include <unordered_map>
#include <vector>
#include <functional>

class GameObject;
class Transform;

class ScriptManager : public Module {
private:
    lua_State* L;
    std::unordered_map<std::string, bool> loadedScripts;
    std::vector<std::function<void()>> pendingOperations;

public:
    ScriptManager();
    ~ScriptManager();

    bool Awake() override;
    bool Start() override;
    bool Update() override;
    bool PostUpdate() override;
    bool CleanUp() override;

    bool LoadScript(const std::string& filepath);
    bool ReloadScript(const std::string& filepath);

    void CallGlobalStart();
    void CallGlobalUpdate(float deltaTime);

    lua_State* GetState() { return L; }

    void RegisterEngineFunctions();
    bool HasGlobalFunction(const std::string& functionName);

    // Deferred operation queue
    void EnqueueOperation(std::function<void()> operation);

    std::string pendingSceneLoad;

    // APIs de Lua
    void RegisterGameObjectAPI();
    void RegisterComponentAPI();
    void RegisterPrefabAPI();
};