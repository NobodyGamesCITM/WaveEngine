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

        parent->InsertChildAt(obj, index);
        Application::GetInstance().scene->MarkOctreeForRebuild();
    }

    UID m_ObjectUID;
    UID m_OldParentUID;
    int m_OldIndex;
    UID m_NewParentUID;
    int m_NewIndex;
};