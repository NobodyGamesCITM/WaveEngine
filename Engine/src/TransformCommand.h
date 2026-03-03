#pragma once

#include "EditorCommand.h"
#include "Globals.h"
#include <glm/glm.hpp>

class GameObject;

class TransformCommand : public EditorCommand
{
public:
    TransformCommand(GameObject* object,
        const glm::vec3& oldPos, const glm::vec3& oldRot, const glm::vec3& oldScale,
        const glm::vec3& newPos, const glm::vec3& newRot, const glm::vec3& newScale);

    void Execute() override;
    void Undo() override;

private:
    void ApplyTransform(const glm::vec3& pos, const glm::vec3& rot, const glm::vec3& scl);

    UID m_ObjectUID = 0;

    glm::vec3 m_OldPosition, m_OldRotation, m_OldScale;
    glm::vec3 m_NewPosition, m_NewRotation, m_NewScale;
};