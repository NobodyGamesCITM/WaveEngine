#include "DeleteCommand.h"
#include "GameObject.h"
#include "Application.h"
#include "SelectionManager.h"
#include "ModuleScene.h"

DeleteCommand::DeleteCommand(GameObject* object)
    : m_Object(object)
{
    m_ObjectUID = object->GetUID();
    m_Parent = object->GetParent();
    m_ParentUID = m_Parent ? m_Parent->GetUID() : 0;
    m_ChildIndex = m_Parent ? m_Parent->GetChildIndex(object) : -1;

    nlohmann::json arr = nlohmann::json::array();
    object->Serialize(arr);
    m_SerializedObject = arr[0];
}

void DeleteCommand::Execute()
{
    GameObject* obj = Application::GetInstance().scene->FindObject(m_ObjectUID);
    GameObject* parent = Application::GetInstance().scene->FindObject(m_ParentUID);

    if (!obj || !parent) return;
    obj->MarkForDeletion();
    std::vector<Component*> objComps= obj->GetComponents();

	for (auto& comp : objComps) {
		if (comp->GetType() == ComponentType::D6_JOINT || comp->GetType() == ComponentType::JOINT || comp->GetType() == ComponentType::DISTANCE_JOINT
			|| comp->GetType() == ComponentType::FIXED_JOINT || comp->GetType() == ComponentType::HINGE_JOINT || comp->GetType() == ComponentType::PRISMATIC_JOINT
			|| comp->GetType() == ComponentType::SPHERICAL_JOINT) {
			comp->CleanUp();
		}
	}
    Application::GetInstance().selectionManager->RemoveFromSelection(obj);
    Application::GetInstance().selectionManager->ClearSelection();

    //parent->RemoveChild(obj);
    m_Object = nullptr;

    Application::GetInstance().scene->MarkOctreeForRebuild();
}

void DeleteCommand::Undo()
{
    GameObject* parent = Application::GetInstance().scene->FindObject(m_ParentUID);
    if (!parent) return;

    GameObject* restored = GameObject::Deserialize(m_SerializedObject, nullptr);
    if (!restored) return;

    parent->InsertChildAt(restored, m_ChildIndex);
    restored->SolveReferences();
    m_Object = restored;
    m_ObjectUID = restored->GetUID();
    m_Parent = parent;

    Application::GetInstance().selectionManager->ClearSelection();
    Application::GetInstance().selectionManager->SetSelectedObject(restored);
    Application::GetInstance().scene->MarkOctreeForRebuild();
}