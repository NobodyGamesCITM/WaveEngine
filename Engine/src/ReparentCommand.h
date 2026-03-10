#pragma once

#include "EditorCommand.h"
#include "Globals.h"
#include "Application.h"
#include "ModuleScene.h"

class ReparentCommand : public EditorCommand
{
public:
    ReparentCommand(GameObject* object, GameObject* newParent, int newIndex)
        : m_ObjectUID(object->GetUID())
        , m_OldParentUID(object->GetParent() ? object->GetParent()->GetUID() : 0)
        , m_OldIndex(object->GetParent() ? object->GetParent()->GetChildIndex(object) : -1)
        , m_NewParentUID(newParent->GetUID())
        , m_NewIndex(newIndex)
    {
    }

    void Execute() override { Apply(m_NewParentUID, m_NewIndex); }
    void Undo()    override { Apply(m_OldParentUID, m_OldIndex); }

private:
    void Apply(UID parentUID, int index)
    {
        GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
        GameObject* parent = Application::GetInstance().scene->FindObject(parentUID);
        if (!obj || !parent) return;

        GameObject* oldParent = obj->GetParent();

        int adjustedIndex = index;
        if (oldParent == parent)
        {
            int oldIdx = parent->GetChildIndex(obj);
            if (oldIdx >= 0 && oldIdx < index)
                --adjustedIndex;
        }

        adjustedIndex = std::max(0, std::min(adjustedIndex,
            static_cast<int>(parent->GetChildren().size())));

        parent->InsertChildAt(obj, adjustedIndex);
    }

    UID m_ObjectUID;
    UID m_OldParentUID;
    int m_OldIndex;
    UID m_NewParentUID;
    int m_NewIndex;
};