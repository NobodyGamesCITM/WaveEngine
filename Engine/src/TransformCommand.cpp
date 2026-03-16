#include "TransformCommand.h"
#include "GameObject.h"
#include "Transform.h"
#include "Application.h"
#include "ModuleScene.h"

TransformCommand::TransformCommand(GameObject* object,
    const glm::vec3& oldPos, const glm::vec3& oldRot, const glm::vec3& oldScale,
    const glm::vec3& newPos, const glm::vec3& newRot, const glm::vec3& newScale)
    : m_ObjectUID(object->GetUID())
    , m_OldPosition(oldPos), m_OldRotation(oldRot), m_OldScale(oldScale)
    , m_NewPosition(newPos), m_NewRotation(newRot), m_NewScale(newScale)
{
}

void TransformCommand::Execute()
{
    ApplyTransform(m_NewPosition, m_NewRotation, m_NewScale);
}

void TransformCommand::Undo()
{
    ApplyTransform(m_OldPosition, m_OldRotation, m_OldScale);
}

void TransformCommand::ApplyTransform(const glm::vec3& pos, const glm::vec3& rot, const glm::vec3& scl)
{
    // Buscar por UID: si el objeto fue borrado devuelve nullptr y no crashea
    GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
    if (!obj || !obj->transform) return;

    obj->transform->SetPosition(pos);
    obj->transform->SetRotation(rot);
    obj->transform->SetScale(scl);

    
}