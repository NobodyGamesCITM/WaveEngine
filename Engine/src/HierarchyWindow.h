#pragma once

#include "EditorWindow.h"

class GameObject;
struct ImVec2;

enum class DropPosition {
    NONE,
    BEFORE,
    ON,
    AFTER
};

class HierarchyWindow : public EditorWindow
{
public:
    HierarchyWindow();
    ~HierarchyWindow() override = default;
    GameObject* CreateAndRegisterGameObject(const std::string& name, GameObject* parent = nullptr);

    void DrawBackgroundContextMenu();

    void DrawGameObjectContextMenu(GameObject* gameObject);

    void DrawCreate3DObjectSubmenu();

    void Draw() override;

private:
    void DrawGameObjectNode(GameObject* gameObject, int childIndex = 0);
    void SelectGameObjectAndChildren(GameObject* gameObject);
    bool IsDescendantOf(GameObject* potentialDescendant, GameObject* potentialAncestor);
    DropPosition GetDropPosition(GameObject* draggedObject, GameObject* targetObject);
    void DrawInsertionLine(const ImVec2& start, const ImVec2& end);
    void HandleAutoScroll();

    std::vector<GameObject*> visibleObjects;
    GameObject* pendingShiftSelection = nullptr;

    // Renaming functionality
    GameObject* renamingObject = nullptr;
    char renameBuffer[256] = "";

    // Dragdrop
    bool dragCancelled = false;

    // Autoscroll
    const float AUTO_SCROLL_MARGIN = 30.0f;
    const float AUTO_SCROLL_SPEED = 5.0f;
};