#pragma once

#include "EditorCommand.h"
#include "Component.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleScene.h"
#include <nlohmann/json.hpp>

class ComponentStateCommand : public EditorCommand
{
public:
    ComponentStateCommand(Component* comp, nlohmann::json before, nlohmann::json after)
        : m_Before(std::move(before))
        , m_After(std::move(after))
    {
        if (comp && comp->owner)
        {
            m_OwnerUID = comp->owner->GetUID();
            m_CompIndex = comp->owner->GetComponentIndex(comp);
        }
    }

    void Execute() override
    {
        Component* comp = FindComponent();
        if (comp) comp->Deserialize(m_After);
    }

    void Undo() override
    {
        Component* comp = FindComponent();
        if (comp) comp->Deserialize(m_Before);
    }

private:
    Component* FindComponent() const
    {
        GameObject* owner = Application::GetInstance().scene->FindObject(m_OwnerUID);
        if (!owner) return nullptr;
        const auto& comps = owner->GetComponents();
        if (m_CompIndex < 0 || m_CompIndex >= (int)comps.size()) return nullptr;
        return comps[m_CompIndex];
    }

    UID            m_OwnerUID = 0;
    int            m_CompIndex = -1;
    nlohmann::json m_Before;
    nlohmann::json m_After;
};