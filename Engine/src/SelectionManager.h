#pragma once
#include <vector>
#include "EventListener.h"
#include <algorithm>
#include <unordered_set>

class GameObject;

class SelectionManager : public EventListener
{
public:
	SelectionManager() = default;
	~SelectionManager() = default;

	// Single selection (replaces current selection)
	void SetSelectedObject(GameObject* obj);

	// Multi-selection operations
	void AddToSelection(GameObject* obj);
	void RemoveFromSelection(GameObject* obj);
	void ToggleSelection(GameObject* obj);

	// Clear all selections
	void ClearSelection();

	// Query methods
	GameObject* GetSelectedObject() const;
	std::vector<GameObject*> GetFilteredObjects();

	GameObject* GetSelectionAnchor() const { return selectionAnchor; }
	void SetSelectionAnchor(GameObject* obj) { selectionAnchor = obj; }

	const std::vector<GameObject*>& GetSelectedObjects() const { return selectedObjects; }
	bool IsSelected(GameObject* obj) const;
	bool HasSelection() const { return !selectedObjects.empty(); }
	int GetSelectionCount() const { return static_cast<int>(selectedObjects.size()); }
	void SelectRange(GameObject* start, GameObject* end, const std::vector<GameObject*>& allObjects);

	void OnEvent(const Event& event);

private:
	std::vector<GameObject*> selectedObjects;
	GameObject* selectionAnchor = nullptr;

};