#include "DeleteCommand.h"
#include "GameObject.h"
#include "Application.h"
#include "SelectionManager.h"
#include "ModuleScene.h"

DeleteCommand::DeleteCommand(GameObject* object)
    : m_Object(object)
{
    m_Parent = object->GetParent();
    m_ChildIndex = m_Parent ? m_Parent->GetChildIndex(object) : -1;
}

void DeleteCommand::Execute()
{
    if (!m_Object || !m_Parent) return;

    Application::GetInstance().selectionManager->RemoveFromSelection(m_Object);

    m_Parent->RemoveChild(m_Object);
    m_OwnedObject.reset(m_Object);

    Application::GetInstance().selectionManager->ClearSelection();
    Application::GetInstance().scene->MarkOctreeForRebuild();
}

void DeleteCommand::Undo()
{
    if (!m_OwnedObject || !m_Parent) return;

    m_Parent->InsertChildAt(m_OwnedObject.get(), m_ChildIndex);
    m_OwnedObject.release();

    Application::GetInstance().selectionManager->ClearSelection();
    Application::GetInstance().scene->MarkOctreeForRebuild();
}