#pragma once

#include "EditorCommand.h"
#include "Globals.h"
#include <memory>
#include <nlohmann/json.hpp>

class GameObject;

class CreateCommand : public EditorCommand
{
public:
    CreateCommand(GameObject* object);
    void Execute() override;
    void Undo() override;

private:
    UID            m_ObjectUID = 0;
    UID            m_ParentUID = 0;
    int            m_ChildIndex = -1;
    nlohmann::json m_SerializedObject;
};