#include "CreateCommand.h"
#include "GameObject.h"
#include "Application.h"
#include "SelectionManager.h"
#include "ModuleScene.h"

CreateCommand::CreateCommand(GameObject* object)
{
    m_ObjectUID = object->GetUID();
    m_ChildIndex = -1;

    GameObject* parent = object->GetParent();
    if (parent)
    {
        m_ParentUID = parent->GetUID();
        m_ChildIndex = parent->GetChildIndex(object);
    }

    nlohmann::json arr = nlohmann::json::array();
    object->Serialize(arr);
    m_SerializedObject = arr[0];
}

void CreateCommand::Execute()
{
    GameObject* existing = Application::GetInstance().scene->FindObject(m_ObjectUID);
    if (existing) return;

    GameObject* parent = Application::GetInstance().scene->FindObject(m_ParentUID);
    if (!parent) parent = Application::GetInstance().scene->GetRoot();

    GameObject* restored = GameObject::Deserialize(m_SerializedObject, nullptr);
    if (!restored) return;

    restored->SolveReferences();
    int childCount = (int)parent->GetChildren().size();
    int safeIndex = (m_ChildIndex >= 0 && m_ChildIndex <= childCount) ? m_ChildIndex : childCount;
    parent->InsertChildAt(restored, safeIndex);
    m_ObjectUID = restored->GetUID();

    Application::GetInstance().selectionManager->ClearSelection();
    Application::GetInstance().selectionManager->SetSelectedObject(restored);
    Application::GetInstance().scene->MarkOctreeForRebuild();
}

void CreateCommand::Undo()
{
    GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
    if (!obj) return;

    Application::GetInstance().selectionManager->RemoveFromSelection(obj);
    Application::GetInstance().selectionManager->ClearSelection();

    GameObject* parent = obj->GetParent();
    if (parent) parent->RemoveChild(obj);
    delete obj;

    Application::GetInstance().scene->MarkOctreeForRebuild();
}