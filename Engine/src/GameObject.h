#pragma once
#include <vector>
#include <string>
#include <memory>
#include <nlohmann/json.hpp>
#include "Globals.h"
#include "PrefabInstance.h"

class Component;
class Transform;
enum class ComponentType;

enum class GameObjectEvent {
    TRANSFORM_CHANGED,
    TRANSFORM_SCALED,
    COMPONENT_ADDED,
    COMPONENT_REMOVED,
    OBJECT_DESTROYED,
    HIERARCHY_CHANGED,
    MESH_CHANGED
};


class GameObject {
public:
    GameObject(const std::string& name = "GameObject");
    ~GameObject();

    const UID GetUID() { return objectUID; };

    std::optional<PrefabInstance> prefabInstance;

    Component* CreateComponent(ComponentType type);
    void RemoveComponent(Component* comp);

    //QOL
    std::unique_ptr<Component> ExtractComponent(Component* comp);
    void ReinsertComponentAt(std::unique_ptr<Component> comp, int index);
    int GetComponentIndex(Component* comp) const;

    Component* GetComponent(ComponentType type) const;
    std::vector<Component*> GetComponentsOfType(ComponentType type) const;
    Component* GetComponentInChildren(ComponentType type);
    void GetComponentsInChildren(ComponentType type, std::vector<Component*>& outlist);
    Component* GetComponentInParent(ComponentType type);
    void GetComponentsInParent(ComponentType type, std::vector<Component*>& outlist);

    void AddChild(GameObject* child);
    void RemoveChild(GameObject* child);
    void SetParent(GameObject* newParent);
    void InsertChildAt(GameObject* child, int index);
    int GetChildIndex(GameObject* child) const;

    void Update();
    void FixedUpdate();

    const std::string& GetName() const { return name; }
    void SetName(const std::string& newName) { name = newName; }
    bool IsActive() const { return active; }
    void SetActive(bool state) { active = state; }
    GameObject* GetParent() const { return parent; }
    const std::vector<GameObject*>& GetChildren() const { return children; }
    const std::vector<Component*>& GetComponents() const { return components; }
    GameObject* FindChild(const std::string& findName);
    GameObject* FindChild(const UID uid);

    void SetSelected(bool b) { isSelected = b; };
    bool IsSelected() { return isSelected; };

    void MarkForDeletion();
    bool IsMarkedForDeletion() const { return markedForDeletion; }
    void MarkCleaning() { isCleaning = true; };
    bool IsCleaning() { return isCleaning; };

    // Serialization
    void Serialize(nlohmann::json& gameObjectArray) const;
    static GameObject* Deserialize(const nlohmann::json& gameObjectObj, GameObject* parent = nullptr);
    void SolveReferences();

    //INTERNAL EVENTS
    void PublishGameObjectEvent(GameObjectEvent event, Component* component = nullptr);

    void SetParentDirect(GameObject* p) { parent = p; }

public:
    UID objectUID;
    std::string name;
    bool active = true;
    Transform* transform = nullptr;

    //tags
    std::string tag = "";

    const std::string& GetTag() const { return tag; }
    void SetTag(const std::string& newTag) { tag = newTag; }
    bool CompareTag(const std::string& t) const { return tag == t; }
    void SetPersistency(bool persistent) {
        isPersistent = persistent;
    }
    bool IsPersistent() { return isPersistent; }

private:
    GameObject* parent = nullptr;
    std::vector<GameObject*> children;
    std::vector<std::unique_ptr<Component>> componentOwners;
    std::vector<Component*> components;

    bool markedForDeletion = false;
    bool isCleaning = false;
    bool isSelected = false;
    bool isPersistent = false;

};