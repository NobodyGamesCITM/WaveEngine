#pragma once

#include "EditorCommand.h"
#include "Globals.h"
#include <nlohmann/json.hpp>

class GameObject;

class DeleteCommand : public EditorCommand
{
public:
    DeleteCommand(GameObject* object);
    void Execute() override;
    void Undo() override;

private:
    GameObject* m_Object = nullptr;
    nlohmann::json m_SerializedObject;
    GameObject* m_Parent = nullptr;
    UID m_ObjectUID = 0;
    UID m_ParentUID = 0;
    int m_ChildIndex = -1;
};