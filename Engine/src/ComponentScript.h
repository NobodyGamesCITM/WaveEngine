#pragma once

#include "Component.h"
#include "ModuleResources.h"
#include "GameObject.h"
#include "PhysicsEventsListener.h"
#include <string>
#include <vector>
#include <variant>
#include "glm/glm.hpp"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

class Transform;
class ResourceScript;

//class GameObject;


enum class ScriptVarType {
    NUMBER,
    STRING,
    BOOLEAN,
    VEC3,
    GAMEOBJECT,
    SCENE,
    PREFAB
};

struct ScriptVariable {
    std::string name;
    ScriptVarType type;
    std::variant<float, std::string, bool, glm::vec3, GameObject*> value;

    ScriptVariable(const std::string& n, float v)
        : name(n), type(ScriptVarType::NUMBER), value(v) {
    }

    ScriptVariable(const std::string& n, const std::string& v)
        : name(n), type(ScriptVarType::STRING), value(v) {
    }

    ScriptVariable(const std::string& n, bool v)
        : name(n), type(ScriptVarType::BOOLEAN), value(v) {
    }

    ScriptVariable(const std::string& n, const glm::vec3& v)
        : name(n), type(ScriptVarType::VEC3), value(v) {
    }

    ScriptVariable(const std::string& n, GameObject* v)
        : name(n), type(ScriptVarType::GAMEOBJECT), value(v) {
    }
    
    ScriptVariable(const std::string& n, ScriptVarType t, const std::string& v)
        : name(n), type(t), value(v) {
    }
};

class ComponentScript : public Component, public PhysicsEventsListener {
public:
    ComponentScript(GameObject* owner);
    ~ComponentScript() override;

    bool IsType(ComponentType type) override { return type == ComponentType::SCRIPT; };
    bool IsIncompatible(ComponentType type) override { return false; };

    void Enable() override;
    void Update() override;
    void Disable() override;
    void OnEditor() override;

    // Serialization
    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    // Script management
    bool LoadScriptByUID(UID scriptUID);
    void UnloadScript();
    bool ReloadScript();

    // Lua lifecycle
    void CallStart();
    void CallUpdate(float deltaTime);

    // Getters
    UID GetScriptUID() const { return scriptUID; }
    bool HasScript() const { return scriptUID != 0; }
    const std::string& GetLuaTableName() const { return luaTableName; }

    // Variables públicas
    const std::vector<ScriptVariable>& GetPublicVariables() const { return publicVariables; }
    void UpdatePublicVariable(size_t index, const ScriptVariable& var);

    void MarkGameObjectForDestroy() { pendingDestroy = true; }
    bool IsPendingDestroy() const { return pendingDestroy; }

    bool updateWhenPaused = false;

private:
    void CreateLuaTable();
    void DestroyLuaTable();
    bool CompileAndExecuteScript(const std::string& scriptContent);

    void SetupScriptEnvironment(lua_State* L);
    void CreateTransformUserdata(lua_State* L, Transform* transform);

    // Sistema de variables públicas
    void ExtractPublicVariables();
    void SyncPublicVariablesToLua();
    void PushVariableToLua(lua_State* L, const ScriptVariable& var);

    void RestoreSavedVariableValues(const std::vector<ScriptVariable>& savedVars);

    UID scriptUID = 0;
    ResourceScript* scriptRes = nullptr;

    std::string luaTableName;
    bool startCalled = false;

    std::vector<ScriptVariable> publicVariables;
    std::vector<std::string> variableOrder;  

    std::variant<float, std::string, bool, glm::vec3, GameObject*> value;

    bool pendingDestroy = false;

    void CallPhysicsEvent(const char* funcName, Rigidbody* other);

    void ComponentScript::OnTriggerEnter(Rigidbody* other) { CallPhysicsEvent("OnTriggerEnter", other); }
    void ComponentScript::OnTriggerStay(Rigidbody* other) { CallPhysicsEvent("OnTriggerStay", other); }
    void ComponentScript::OnTriggerExit(Rigidbody* other) { CallPhysicsEvent("OnTriggerExit", other); }
    void ComponentScript::OnCollisionEnter(Rigidbody* other) { CallPhysicsEvent("OnCollisionEnter", other); }
    void ComponentScript::OnCollisionStay(Rigidbody* other) { CallPhysicsEvent("OnCollisionStay", other); }
    void ComponentScript::OnCollisionExit(Rigidbody* other) { CallPhysicsEvent("OnCollisionExit", other); }
};