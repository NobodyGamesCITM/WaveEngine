#pragma once

#include "EditorCommand.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleEditor.h"
#include "ModuleScene.h"
#include "Globals.h"
#include <memory>

class RemoveComponentCommand : public EditorCommand
{
public:
    RemoveComponentCommand(GameObject* object, Component* component)
        : m_ObjectUID(object->GetUID())
        , m_Component(component)
        , m_Index(object->GetComponentIndex(component))
    {
    }

    void Execute() override
    {
        GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
        if (!obj || !m_Component) return;
        m_Owned = obj->ExtractComponent(m_Component);
    }

    void Undo() override
    {
        GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
        if (!obj || !m_Owned) return;
        int safeIndex = glm::clamp(m_Index, 0, (int)obj->GetComponents().size());
        obj->ReinsertComponentAt(std::move(m_Owned), safeIndex);
        m_Component = obj->GetComponents()[safeIndex];
    }

private:
    UID m_ObjectUID;
    Component* m_Component;
    int m_Index;
    std::unique_ptr<Component> m_Owned;
};

class AddComponentCommand : public EditorCommand
{
public:
    AddComponentCommand(GameObject* object, Component* component)
        : m_ObjectUID(object->GetUID())
        , m_Component(component)
        , m_Index(object->GetComponentIndex(component))
    {
    }

    void Undo() override
    {
        GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
        if (!obj || !m_Component) return;
        m_Owned = obj->ExtractComponent(m_Component);
        ComponentType compType = m_Component->GetType();
        if (compType == ComponentType::D6_JOINT || compType == ComponentType::JOINT || compType == ComponentType::DISTANCE_JOINT
            || compType == ComponentType::FIXED_JOINT || compType == ComponentType::HINGE_JOINT || compType == ComponentType::PRISMATIC_JOINT
            || compType == ComponentType::SPHERICAL_JOINT)
        {
            m_Component->CleanUp();
        }
    }

    void Execute() override
    {
        GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
        if (!obj || !m_Owned) return;
        int safeIndex = glm::clamp(m_Index, 0, (int)obj->GetComponents().size());
        obj->ReinsertComponentAt(std::move(m_Owned), safeIndex);
        m_Component = obj->GetComponents()[safeIndex];
    }

private:
    UID m_ObjectUID;
    Component* m_Component;
    int m_Index;
    std::unique_ptr<Component> m_Owned;
};