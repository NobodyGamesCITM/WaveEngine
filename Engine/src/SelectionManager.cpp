#include "SelectionManager.h"
#include "ModuleEvents.h"
#include "GameObject.h"
#include "Log.h"

void SelectionManager::SetSelectedObject(GameObject* obj)
{
	for (GameObject* oldObj : selectedObjects)
	{
		if (oldObj) oldObj->SetSelected(false);
	}
	selectedObjects.clear();

	if (obj != nullptr)
	{
		selectedObjects.push_back(obj);
		obj->SetSelected(true);
		selectionAnchor = obj;
		LOG_DEBUG("Selected object: %s", obj->GetName().c_str());
	}
}

void SelectionManager::AddToSelection(GameObject* obj)
{
	if (obj == nullptr) return;

	if (!obj->IsSelected())
	{
		obj->SetSelected(true);
		selectedObjects.push_back(obj);
		LOG_DEBUG("Added to selection: %s (total: %d)", obj->GetName().c_str(), static_cast<int>(selectedObjects.size()));
	}
}

void SelectionManager::RemoveFromSelection(GameObject* obj)
{
	if (obj == nullptr) return;

	auto it = std::find(selectedObjects.begin(), selectedObjects.end(), obj);
	if (it != selectedObjects.end())
	{
		obj->SetSelected(false);
		selectedObjects.erase(it);
		LOG_DEBUG("Removed from selection: %s", obj->GetName().c_str());
	}
}

void SelectionManager::ToggleSelection(GameObject* obj)
{
	if (obj == nullptr) return;

	if (obj->IsSelected())
	{
		RemoveFromSelection(obj);
	}
	else
	{
		AddToSelection(obj);
	}
	selectionAnchor = obj;
}

void SelectionManager::ClearSelection()
{
	if (!selectedObjects.empty())
	{
		for (GameObject* obj : selectedObjects)
		{
			if (obj) obj->SetSelected(false);
		}
		selectedObjects.clear();
		LOG_DEBUG("Selection cleared");
	}
}

GameObject* SelectionManager::GetSelectedObject() const
{
	return selectedObjects.empty() ? nullptr : selectedObjects[0];
}
std::vector<GameObject*> SelectionManager::GetFilteredObjects()
{
	std::vector<GameObject*> filtered;

	std::unordered_set<GameObject*> selectedSet(
		selectedObjects.begin(),
		selectedObjects.end()
	);

	for (GameObject* obj : selectedObjects)
	{
		GameObject* current = obj->GetParent();
		bool skip = false;

		while (current != nullptr)
		{
			if (selectedSet.find(current) != selectedSet.end())
			{
				skip = true;
				break;
			}
			current = current->GetParent();
		}

		if (!skip)
			filtered.push_back(obj);
	}
	return filtered;
}
bool SelectionManager::IsSelected(GameObject* obj) const
{
	if (obj) return obj->IsSelected();
	return false;
}

void SelectionManager::SelectRange(GameObject* start, GameObject* end, const std::vector<GameObject*>& allObjects)
{
	if (!start || !end || allObjects.empty()) return;

	auto itStart = std::find(allObjects.begin(), allObjects.end(), start);
	auto itEnd = std::find(allObjects.begin(), allObjects.end(), end);

	if (itStart == allObjects.end() || itEnd == allObjects.end()) return;

	ClearSelection();

	auto first = std::min(itStart, itEnd);
	auto last = std::max(itStart, itEnd);

	for (auto it = first; it != std::next(last); ++it)
	{
		AddToSelection(*it);
	}

	selectionAnchor = end;
}

void SelectionManager::OnEvent(const Event& event)
{
	switch (event.type)
	{
	case Event::Type::GameObjectDestroyed:
	{
		GameObject* deletedObject = event.data.gameObject.gameObject;

		RemoveFromSelection(deletedObject);
		break;
	}

	default:
		break;
	}
}