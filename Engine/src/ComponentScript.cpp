#include "ComponentScript.h"
#include "Application.h"
#include "ScriptManager.h"
#include "ResourceScript.h"
#include "GameObject.h"
#include "Transform.h"
#include <glm/glm.hpp>
#include <filesystem>
#include "Log.h"
#include <sstream>
#include "Rigidbody.h"

ComponentScript::ComponentScript(GameObject* owner)
    : Component(owner, ComponentType::SCRIPT)
{
    name = "Script";
}

ComponentScript::~ComponentScript()
{
    UnloadScript();
}

void ComponentScript::Enable()
{
    if (!HasScript()) return;
    if (!startCalled && active) {
        CallStart();
    }
}

void ComponentScript::Update()
{
    if (!active) return;
    if (!HasScript()) return;

    auto& app = Application::GetInstance();
    bool isPaused = (app.GetPlayState() == Application::PlayState::PAUSED);
    
    // Permitir update si está marcado explícitamente O si es parte de la UI (Canvas)
    bool isPlaying = (app.GetPlayState() == Application::PlayState::PLAYING);
    bool isUIScript = (owner->GetComponentInParent(ComponentType::CANVAS) != nullptr);
    bool canUpdate  = isPlaying || updateWhenPaused || isUIScript;

    if (!canUpdate) return;

    //EN GAME ESTO NO SE HA DE HACER
    if (scriptRes->NeedsReload()) {
        app.resources.get()->ImportFile(scriptRes->GetAssetFile().c_str(), true);
        ReloadScript();
    }

    float deltaTime = app.time->GetDeltaTime();
    
    // Si estamos en pausa, usamos el tiempo real para que la UI siga animada/respondiendo
    if (isPaused) {
        deltaTime = app.time->GetRealDeltaTime();
    }

    CallUpdate(deltaTime);

    if (pendingDestroy) {
        owner->MarkForDeletion();
        pendingDestroy = false;
    }
}

void ComponentScript::Disable()
{
}

void ComponentScript::OnEditor()
{
    // Ya se dibuja desde InspectorWindow
}

void ComponentScript::Serialize(nlohmann::json& componentObj) const
{
    componentObj["scriptUID"] = scriptUID;

    // Guardar variables públicas con sus valores actuales
    if (!publicVariables.empty()) {
        nlohmann::json varsArray = nlohmann::json::array();

        for (const auto& var : publicVariables) {
            nlohmann::json varObj;
            varObj["name"] = var.name;
            varObj["type"] = static_cast<int>(var.type);

            switch (var.type) {
            case ScriptVarType::NUMBER:
                varObj["value"] = std::get<float>(var.value);
                break;

            case ScriptVarType::STRING:
                varObj["value"] = std::get<std::string>(var.value);
                break;

            case ScriptVarType::BOOLEAN:
                varObj["value"] = std::get<bool>(var.value);
                break;

            case ScriptVarType::VEC3: {
                const glm::vec3& vec = std::get<glm::vec3>(var.value);
                varObj["value"] = { vec.x, vec.y, vec.z };
                break;
            }
            case ScriptVarType::SCENE:
                varObj["value"] = std::get<std::string>(var.value);
                break;
            }

            varsArray.push_back(varObj);
        }

        componentObj["publicVariables"] = varsArray;

        LOG_DEBUG("[ComponentScript] Serialized %zu public variables", publicVariables.size());
    }
}

void ComponentScript::Deserialize(const nlohmann::json& componentObj)
{
    if (componentObj.contains("scriptUID")) {
        UID uid = componentObj["scriptUID"];

        // Cargar el script primero (esto extrae variables del .lua)
        if (LoadScriptByUID(uid)) {

            // Si hay variables guardadas, restaurarlas
            if (componentObj.contains("publicVariables")) {
                const auto& varsArray = componentObj["publicVariables"];

                std::vector<ScriptVariable> savedVars;

                // Leer variables guardadas
                for (const auto& varObj : varsArray) {
                    std::string varName = varObj["name"];
                    ScriptVarType varType = static_cast<ScriptVarType>(varObj["type"]);

                    switch (varType) {
                    case ScriptVarType::NUMBER: {
                        float value = varObj["value"].get<float>();
                        savedVars.emplace_back(varName, value);
                        break;
                    }

                    case ScriptVarType::STRING: {
                        std::string value = varObj["value"].get<std::string>();
                        savedVars.emplace_back(varName, value);
                        break;
                    }

                    case ScriptVarType::BOOLEAN: {
                        bool value = varObj["value"].get<bool>();
                        savedVars.emplace_back(varName, value);
                        break;
                    }

                    case ScriptVarType::VEC3: {
                        auto vec = varObj["value"];
                        glm::vec3 value(
                            vec[0].get<float>(),
                            vec[1].get<float>(),
                            vec[2].get<float>()
                        );
                        savedVars.emplace_back(varName, value);
                        break;
                    }
                    case ScriptVarType::SCENE: {
                        std::string value = varObj["value"].get<std::string>();
                        savedVars.emplace_back(varName, ScriptVarType::SCENE, value);
                        break;
                    }
                    }
                }

                // Restaurar valores guardados
                RestoreSavedVariableValues(savedVars);

                // Sincronizar a Lua
                SyncPublicVariablesToLua();

                LOG_CONSOLE("[ComponentScript] Restored %zu public variables from save",
                    savedVars.size());
            }
        }
    }
}

bool ComponentScript::LoadScriptByUID(UID uid)
{
    if (uid == 0) {
        return false;
    }

    if (HasScript()) {
        UnloadScript();
    }

    ModuleResources* resources = Application::GetInstance().resources.get();
    Resource* res = resources->RequestResource(uid);

    if (!res || res->GetType() != Resource::SCRIPT) {
        LOG_CONSOLE("[ComponentScript] ERROR: Resource %llu is not a script", uid);
        return false;
    }

    scriptRes = static_cast<ResourceScript*>(res);
    const std::string& scriptContent = scriptRes->GetScriptContent();

    if (scriptContent.empty()) {
        LOG_CONSOLE("[ComponentScript] ERROR: Script content is empty");
        resources->ReleaseResource(uid);
        scriptRes = nullptr;;
        return false;
    }

    scriptUID = uid;
    CreateLuaTable();

    if (!CompileAndExecuteScript(scriptContent)) {
        LOG_CONSOLE("[ComponentScript] ERROR: Failed to compile script");
        UnloadScript();
        return false;
    }

    return true;
}

void ComponentScript::UnloadScript()
{
    if (!HasScript()) return;

    ModuleResources* resources = Application::GetInstance().resources.get();
    resources->ReleaseResource(scriptUID);

    DestroyLuaTable();

    scriptRes = nullptr;
    scriptUID = 0;
    startCalled = false;
    updateWhenPaused = false;
    publicVariables.clear();
    variableOrder.clear();  
}

bool ComponentScript::ReloadScript()
{
    if (!HasScript()) return false;

    // Guardar valores actuales ANTES del reload
    std::vector<ScriptVariable> savedVariables = publicVariables;

    UID uid = scriptUID;
    UnloadScript();

    if (!LoadScriptByUID(uid)) {
        return false;
    }

    // Restaurar valores guardados sobre los nuevos del .lua
    RestoreSavedVariableValues(savedVariables);

    // Sincronizar a Lua
    SyncPublicVariablesToLua();

    LOG_CONSOLE("[ComponentScript] Hot reloaded and preserved variable values");
    return true;
}

void ComponentScript::CallStart()
{
    if (!HasScript() || startCalled) return;

    SyncPublicVariablesToLua();

    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) return;

    lua_getglobal(L, luaTableName.c_str());

    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }

    GameObject** udata = (GameObject**)lua_newuserdata(L, sizeof(GameObject*));
    *udata = Component::owner;
    luaL_getmetatable(L, "GameObject");
    lua_setmetatable(L, -2);
    lua_setfield(L, -2, "gameObject");

    lua_getfield(L, -1, "Start");

    if (lua_isfunction(L, -1)) {
        lua_pushvalue(L, -2);

        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            const char* error = lua_tostring(L, -1);
            LOG_CONSOLE("[ComponentScript] ERROR in Start(): %s", error);
            lua_pop(L, 1);
        }
        else {
            startCalled = true;
        }
    }
    else {
        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

void ComponentScript::CallUpdate(float deltaTime)
{
    if (!active || !HasScript()) return;
    if (!owner || owner->IsMarkedForDeletion()) return;

    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) {
        LOG_CONSOLE("[ComponentScript] ERROR: Lua state is null");
        return;
    }

    lua_getglobal(L, luaTableName.c_str());

    if (!lua_istable(L, -1)) {
        LOG_CONSOLE("[ComponentScript] ERROR: Script table not found: %s", luaTableName.c_str());
        lua_pop(L, 1);
        return;
    }

    lua_getfield(L, -1, "Update");

    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return;
    }

    lua_pushvalue(L, -2);
    lua_pushnumber(L, deltaTime);

    if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
        const char* error = lua_tostring(L, -1);
        LOG_CONSOLE("[ComponentScript] ERROR in Update(): %s", error);
        lua_pop(L, 1);
    }

    lua_pop(L, 1);

    if (pendingDestroy) {
        owner->MarkForDeletion();
        pendingDestroy = false;
    }
}

void ComponentScript::CreateLuaTable()
{
    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) return;

    std::stringstream ss;
    ss << "Script_" << owner->GetName() << "_" << scriptUID << "_" << (uintptr_t)this;
    luaTableName = ss.str();

    lua_newtable(L);
    lua_setglobal(L, luaTableName.c_str());

}

void ComponentScript::DestroyLuaTable()
{
    if (luaTableName.empty()) return;

    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) return;

    lua_pushnil(L);
    lua_setglobal(L, luaTableName.c_str());

    luaTableName.clear();
}

bool ComponentScript::CompileAndExecuteScript(const std::string& scriptContent)
{
    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) return false;

    std::string cleanContent = scriptContent;
    if (cleanContent.size() >= 3 &&
        (unsigned char)cleanContent[0] == 0xEF &&
        (unsigned char)cleanContent[1] == 0xBB &&
        (unsigned char)cleanContent[2] == 0xBF) {
        cleanContent = cleanContent.substr(3);
    }

    int loadResult = luaL_loadstring(L, cleanContent.c_str());

    if (loadResult != LUA_OK) {
        const char* error = lua_tostring(L, -1);
        LOG_CONSOLE("[ComponentScript] ERROR compiling script: %s", error);
        lua_pop(L, 1);
        return false;
    }

    if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
        const char* error = lua_tostring(L, -1);
        LOG_CONSOLE("[ComponentScript] ERROR executing script: %s", error);
        lua_pop(L, 1);
        return false;
    }

    lua_getglobal(L, luaTableName.c_str());

    if (lua_istable(L, -1)) {
        // Mover la funcion Start del scope global a la tabla de la instancia
        lua_getglobal(L, "Start");
        if (lua_isfunction(L, -1)) {
            lua_setfield(L, -2, "Start");
        } else {
            lua_pop(L, 1);
        }
        lua_pushnil(L); // Limpiar Start global
        lua_setglobal(L, "Start");

        // Mover la funcion Update del scope global a la tabla de la instancia
        lua_getglobal(L, "Update");
        if (lua_isfunction(L, -1)) {
            lua_setfield(L, -2, "Update");
        } else {
            lua_pop(L, 1);
        }
        lua_pushnil(L); // Limpiar Update global
        lua_setglobal(L, "Update");

        // Mover la tabla public del scope global a la tabla de la instancia
        lua_getglobal(L, "public");
        if (lua_istable(L, -1)) {
            lua_setfield(L, -2, "public");
        } else {
            lua_pop(L, 1);
        }
        lua_pushnil(L); // Limpiar public global
        lua_setglobal(L, "public");

        SetupScriptEnvironment(L);
    }

    lua_pop(L, 1);

    ExtractPublicVariables();

    for (const auto& var : publicVariables) {
        if (var.name == "updateWhenPaused" && var.type == ScriptVarType::BOOLEAN) {
            this->updateWhenPaused = std::get<bool>(var.value);
            break;
        }
    }

    return true;
}

void ComponentScript::SetupScriptEnvironment(lua_State* L)
{
    LOG_CONSOLE("[ComponentScript] SetupScriptEnvironment - Owner: %s", owner->GetName().c_str());

    GameObject** goUserdata = (GameObject**)lua_newuserdata(L, sizeof(GameObject*));
    *goUserdata = owner;

    luaL_getmetatable(L, "GameObject");
    lua_setmetatable(L, -2);

    lua_setfield(L, -2, "gameObject");


    ComponentScript** scriptUserdata = (ComponentScript**)lua_newuserdata(L, sizeof(ComponentScript*));
    *scriptUserdata = this;
    lua_setfield(L, -2, "__componentScript");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_getfield(L, 1, "__componentScript");
        if (!lua_isuserdata(L, -1)) {
            LOG_CONSOLE("[Lua] ERROR: __componentScript is not valid");
            return 0;
        }
        ComponentScript* script = *(ComponentScript**)lua_touserdata(L, -1);
        script->MarkGameObjectForDestroy();
        return 0;
        });
    lua_setfield(L, -2, "Destroy");

    Transform* transform = static_cast<Transform*>(owner->GetComponent(ComponentType::TRANSFORM));
    if (transform) {
        CreateTransformUserdata(L, transform);
        lua_setfield(L, -2, "transform");
    }
}

void ComponentScript::CreateTransformUserdata(lua_State* L, Transform* transform)
{
    Transform** udata = (Transform**)lua_newuserdata(L, sizeof(Transform*));
    *udata = transform;

    luaL_newmetatable(L, "Transform");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        Transform* t = *(Transform**)lua_touserdata(L, 1);
        const char* key = luaL_checkstring(L, 2);

        if (strcmp(key, "position") == 0) {
            const glm::vec3& pos = t->GetPosition();
            lua_newtable(L);
            lua_pushnumber(L, pos.x); lua_setfield(L, -2, "x");
            lua_pushnumber(L, pos.y); lua_setfield(L, -2, "y");
            lua_pushnumber(L, pos.z); lua_setfield(L, -2, "z");
            return 1;
        }

        if (strcmp(key, "worldPosition") == 0) {
            const glm::mat4& globalMatrix = t->GetGlobalMatrix();
            lua_newtable(L);
            lua_pushnumber(L, globalMatrix[3][0]); lua_setfield(L, -2, "x");
            lua_pushnumber(L, globalMatrix[3][1]); lua_setfield(L, -2, "y");
            lua_pushnumber(L, globalMatrix[3][2]); lua_setfield(L, -2, "z");
            return 1;
        }

        if (strcmp(key, "rotation") == 0) {
            const glm::vec3& rot = t->GetRotation();
            lua_newtable(L);
            lua_pushnumber(L, rot.x); lua_setfield(L, -2, "x");
            lua_pushnumber(L, rot.y); lua_setfield(L, -2, "y");
            lua_pushnumber(L, rot.z); lua_setfield(L, -2, "z");
            return 1;
        }

        if (strcmp(key, "scale") == 0) {
            const glm::vec3& scl = t->GetScale();
            lua_newtable(L);
            lua_pushnumber(L, scl.x); lua_setfield(L, -2, "x");
            lua_pushnumber(L, scl.y); lua_setfield(L, -2, "y");
            lua_pushnumber(L, scl.z); lua_setfield(L, -2, "z");
            return 1;
        }

        if (strcmp(key, "SetPosition") == 0) {
            lua_pushcfunction(L, [](lua_State* L) -> int {
                Transform* t = *(Transform**)lua_touserdata(L, 1);
                float x = (float)luaL_checknumber(L, 2);
                float y = (float)luaL_checknumber(L, 3);
                float z = (float)luaL_checknumber(L, 4);
                t->SetPosition(glm::vec3(x, y, z));
                return 0;
                });
            return 1;
        }

        if (strcmp(key, "SetRotation") == 0) {
            lua_pushcfunction(L, [](lua_State* L) -> int {
                Transform* t = *(Transform**)lua_touserdata(L, 1);
                float x = (float)luaL_checknumber(L, 2);
                float y = (float)luaL_checknumber(L, 3);
                float z = (float)luaL_checknumber(L, 4);
                t->SetRotation(glm::vec3(x, y, z));
                return 0;
                });
            return 1;
        }

        if (strcmp(key, "SetScale") == 0) {
            lua_pushcfunction(L, [](lua_State* L) -> int {
                Transform* t = *(Transform**)lua_touserdata(L, 1);
                float x = (float)luaL_checknumber(L, 2);
                float y = (float)luaL_checknumber(L, 3);
                float z = (float)luaL_checknumber(L, 4);
                t->SetScale(glm::vec3(x, y, z));
                return 0;
                });
            return 1;
        }

        return 0;
        });
    lua_setfield(L, -2, "__index");

    lua_setmetatable(L, -2);
}

void ComponentScript::ExtractPublicVariables()
{
    bool isFirstExtraction = publicVariables.empty();

    std::vector<ScriptVariable> newVariables;

    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) return;

    // Intentar obtener tabla 'public' global
    lua_getglobal(L, "public");
    bool foundPublic = false;

    if (lua_istable(L, -1)) {
        foundPublic = true;
    }
    else {
        // Si no existe global, buscar en la tabla del script
        lua_pop(L, 1);
        lua_getglobal(L, luaTableName.c_str());

        if (lua_istable(L, -1)) {
            lua_getfield(L, -1, "public");

            if (lua_istable(L, -1)) {
                foundPublic = true;
                LOG_DEBUG("[ComponentScript] Found 'public' table inside script table");
                lua_remove(L, -2);  // Quitar tabla del script, dejar 'public' en top
            }
            else {
                lua_pop(L, 2);
            }
        }
        else {
            lua_pop(L, 1);
        }
    }

    if (!foundPublic) {
        return;
    }

    // Ahora tenemos la tabla "public" en el top del stack
    lua_pushnil(L);

    while (lua_next(L, -2) != 0) {
        if (lua_isstring(L, -2)) {
            const char* varName = lua_tostring(L, -2);

            if (lua_isnumber(L, -1)) {
                float value = (float)lua_tonumber(L, -1);
                newVariables.emplace_back(varName, value);
            }
            else if (lua_isstring(L, -1)) {
                const char* value = lua_tostring(L, -1);
                newVariables.emplace_back(varName, std::string(value));
            }
            else if (lua_isboolean(L, -1)) {
                bool value = lua_toboolean(L, -1);
                newVariables.emplace_back(varName, value);
            }
            else if (lua_istable(L, -1)) {
                lua_getfield(L, -1, "type");
                lua_getfield(L, -2, "value");

                bool handled = false;
                if (lua_isstring(L, -2)) {
                    std::string typeStr = lua_tostring(L, -2);
                    if (typeStr == "Scene") {
                        std::string val = lua_isstring(L, -1) ? lua_tostring(L, -1) : "";
                        newVariables.emplace_back(varName, ScriptVarType::SCENE, val);
                        handled = true;
                    }
                }
                lua_pop(L, 2); // pop type y value

                if (!handled) {
                    lua_getfield(L, -1, "x");
                    lua_getfield(L, -2, "y");
                    lua_getfield(L, -3, "z");

                    if (lua_isnumber(L, -3) && lua_isnumber(L, -2) && lua_isnumber(L, -1)) {
                        float x = (float)lua_tonumber(L, -3);
                        float y = (float)lua_tonumber(L, -2);
                        float z = (float)lua_tonumber(L, -1);
                        newVariables.emplace_back(varName, glm::vec3(x, y, z));
                    }
                    lua_pop(L, 3);
                }
            }

            if (isFirstExtraction) {
                variableOrder.push_back(varName);
            }
        }

        lua_pop(L, 1);
    }

    lua_pop(L, 1);  // Pop tabla "public"

    if (!isFirstExtraction && !variableOrder.empty()) {
        std::vector<ScriptVariable> orderedVariables;

        // Primero, añadir variables en el orden guardado
        for (const auto& orderedName : variableOrder) {
            for (const auto& newVar : newVariables) {
                if (newVar.name == orderedName) {
                    orderedVariables.push_back(newVar);
                    break;
                }
            }
        }

        // Luego, añadir variables nuevas que no estaban antes (al final)
        for (const auto& newVar : newVariables) {
            bool found = false;
            for (const auto& orderedName : variableOrder) {
                if (newVar.name == orderedName) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                orderedVariables.push_back(newVar);
                variableOrder.push_back(newVar.name);  // Añadir al orden
            }
        }

        publicVariables = orderedVariables;
    }
    else {
        publicVariables = newVariables;
    }
}

void ComponentScript::RestoreSavedVariableValues(const std::vector<ScriptVariable>& savedVars)
{
    for (const auto& savedVar : savedVars) {
        // Buscar la variable por nombre en las actuales
        for (auto& currentVar : publicVariables) {
            if (currentVar.name == savedVar.name && currentVar.type == savedVar.type) {
                // Sobrescribir con el valor guardado
                currentVar.value = savedVar.value;
                break;
            }
        }
    }
}

void ComponentScript::SyncPublicVariablesToLua()
{
    if (!HasScript() || publicVariables.empty()) return;

    ScriptManager* scriptManager = Application::GetInstance().scripts.get();
    lua_State* L = scriptManager->GetState();

    if (!L) return;

    // Sincronizar en la tabla global "public" si existe
    lua_getglobal(L, "public");
    bool hasGlobalPublic = lua_istable(L, -1);

    if (hasGlobalPublic) {
        for (const auto& var : publicVariables) {
            PushVariableToLua(L, var);
            lua_setfield(L, -2, var.name.c_str());
        }
    }
    lua_pop(L, 1);

    // Sincronizar en la tabla del script
    lua_getglobal(L, luaTableName.c_str());

    if (lua_istable(L, -1)) {
        lua_getfield(L, -1, "public");

        if (!lua_istable(L, -1)) {
            lua_pop(L, 1);
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_setfield(L, -3, "public");
        }

        for (const auto& var : publicVariables) {
            PushVariableToLua(L, var);
            lua_setfield(L, -2, var.name.c_str());
        }

        lua_pop(L, 1);  // Pop tabla "public"
    }

    lua_pop(L, 1);  // Pop tabla del script
}

void ComponentScript::PushVariableToLua(lua_State* L, const ScriptVariable& var)
{
    switch (var.type) {
    case ScriptVarType::NUMBER:
        lua_pushnumber(L, std::get<float>(var.value));
        break;

    case ScriptVarType::STRING:
        lua_pushstring(L, std::get<std::string>(var.value).c_str());
        break;

    case ScriptVarType::BOOLEAN:
        lua_pushboolean(L, std::get<bool>(var.value));
        break;

    case ScriptVarType::VEC3: {
        const glm::vec3& vec = std::get<glm::vec3>(var.value);
        lua_newtable(L);
        lua_pushnumber(L, vec.x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, vec.y);
        lua_setfield(L, -2, "y");
        lua_pushnumber(L, vec.z);
        lua_setfield(L, -2, "z");
        break;
    }
    case ScriptVarType::SCENE:
        lua_pushstring(L, std::get<std::string>(var.value).c_str());
        break;
    }
}

void ComponentScript::UpdatePublicVariable(size_t index, const ScriptVariable& var)
{
    if (index >= publicVariables.size()) return;

    publicVariables[index] = var;
    SyncPublicVariablesToLua();
}

void ComponentScript::CallPhysicsEvent(const char* funcName, Rigidbody* other)
{
    if (!HasScript()) return;
    lua_State* L = Application::GetInstance().scripts->GetState();

    lua_getglobal(L, luaTableName.c_str());
    if (!lua_istable(L, -1)) { lua_pop(L, 1); return; }

    lua_getfield(L, -1, funcName);

    if (!lua_isfunction(L, -1))
    {
        lua_pop(L, 1);
        lua_getglobal(L, funcName);
    }

    if (!lua_isfunction(L, -1)) { lua_pop(L, 2); return; }

    lua_pushvalue(L, -2);
    GameObject** goUserdata = (GameObject**)lua_newuserdata(L, sizeof(GameObject*));
    *goUserdata = other->owner;
    luaL_getmetatable(L, "GameObject");
    lua_setmetatable(L, -2);

    if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
        LOG_CONSOLE("[ComponentScript] ERROR in %s: %s", funcName, lua_tostring(L, -1));
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
}