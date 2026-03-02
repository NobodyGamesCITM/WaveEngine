#include "HierarchyWindow.h"
#include <imgui.h>
#include <SDL3/SDL.h>
#include "Application.h"
#include "GameObject.h"
#include "SelectionManager.h"
#include "ModuleScene.h"
#include "Log.h"
#include "ResourcePrefab.h"
#include "ReparentCommand.h"
#include "ModuleEditor.h"

HierarchyWindow::HierarchyWindow()
    : EditorWindow("Hierarchy")
{
}

void HierarchyWindow::Draw()
{
    if (!isOpen) return;

    ImGui::Begin(name.c_str(), &isOpen);

    isHovered = (ImGui::IsWindowHovered(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows));

    HandleAutoScroll();

    GameObject* root = Application::GetInstance().scene->GetRoot();

    if (root)
    {
        for (GameObject* child : root->GetChildren())
        {
            if (child != nullptr)
            {
                DrawGameObjectNode(child);

                if (ImGui::BeginDragDropTarget())
                {
                    if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT"))
                    {
                        if (!dragCancelled)
                        {
                            GameObject* draggedObject = *(GameObject**)payload->Data;
                            if (draggedObject != root)
                            {
                                int newIndex = static_cast<int>(root->GetChildren().size());
                                Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                                    std::make_unique<ReparentCommand>(draggedObject, root, newIndex)
                                );
                            }
                        }
                        else
                        {
                            LOG_DEBUG("Drop to root cancelled by user");
                            dragCancelled = false;
                        }
                    }
                    ImGui::EndDragDropTarget();
                }
            }
        }
    }

    // Context menu for creating empty GameObject
    if (ImGui::BeginPopupContextWindow(0, ImGuiPopupFlags_MouseButtonRight | ImGuiPopupFlags_NoOpenOverItems))
    {
        if (ImGui::MenuItem("Create Empty"))
        {
            GameObject* empty = Application::GetInstance().scene->CreateGameObject("GameObject");
            Application::GetInstance().selectionManager->SetSelectedObject(empty);
        }
        ImGui::EndPopup();
    }

    ImGui::End();
}

void HierarchyWindow::DrawGameObjectNode(GameObject* gameObject, int childIndex)
{
    if (gameObject == nullptr)
        return;

    const std::vector<GameObject*>& children = gameObject->GetChildren();
    bool hasChildren = !children.empty();

    ImGuiTreeNodeFlags nodeFlags = ImGuiTreeNodeFlags_OpenOnArrow;

    SelectionManager* selectionManager = Application::GetInstance().selectionManager;
    if (selectionManager->IsSelected(gameObject))
    {
        nodeFlags |= ImGuiTreeNodeFlags_Selected;
    }

    if (!hasChildren)
    {
        nodeFlags |= ImGuiTreeNodeFlags_Leaf | ImGuiTreeNodeFlags_NoTreePushOnOpen;
    }

    bool isRenaming = (renamingObject == gameObject);

    if (isRenaming)
    {
        ImGui::SetNextItemWidth(-1);
        if (ImGui::InputText("##", renameBuffer, sizeof(renameBuffer),
            ImGuiInputTextFlags_EnterReturnsTrue | ImGuiInputTextFlags_AutoSelectAll))
        {
            if (strlen(renameBuffer) > 0)
            {
                gameObject->SetName(renameBuffer);
                LOG_DEBUG("GameObject renamed to: %s", renameBuffer);
            }
            renamingObject = nullptr;
        }

        if (!ImGui::IsItemActive() && (ImGui::IsMouseClicked(0) || ImGui::IsKeyPressed(ImGuiKey_Escape)))
        {
            renamingObject = nullptr;
        }
    }
    else
    {
        // Checkbox for active state
        bool isActive = gameObject->IsActive();
        ImGui::PushID(gameObject);
        if (ImGui::Checkbox("##active", &isActive))
        {
            gameObject->SetActive(isActive);
        }
        ImGui::PopID();

        ImGui::SameLine();

        // Display the node
        bool nodeOpen = ImGui::TreeNodeEx(gameObject, nodeFlags, "%s", gameObject->GetName().c_str());

        // Handle selection
        if (ImGui::IsItemClicked())
        {
            const bool* keys = SDL_GetKeyboardState(NULL);
            bool shiftPressed = keys[SDL_SCANCODE_LSHIFT] || keys[SDL_SCANCODE_RSHIFT];

            if (shiftPressed)
            {
                selectionManager->ToggleSelection(gameObject);
            }
            else
            {
                if (hasChildren)
                {
                    selectionManager->ClearSelection();
                    SelectGameObjectAndChildren(gameObject);
                }
                else
                {
                    selectionManager->SetSelectedObject(gameObject);
                }
            }
        }

        // Handle renaming on double click
        if (ImGui::IsItemHovered() && ImGui::IsMouseDoubleClicked(0))
        {
            renamingObject = gameObject;
            strncpy(renameBuffer, gameObject->GetName().c_str(), sizeof(renameBuffer) - 1);
        }

        // Drag 
        if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None))
        {
            static bool dragStarted = false;
            if (!dragStarted)
            {
                dragCancelled = false;
                dragStarted = true;
            }

            // Cancel drag
            if (ImGui::IsKeyPressed(ImGuiKey_Escape))
            {
                dragCancelled = true;
            }

            ImGui::SetDragDropPayload("HIERARCHY_GAMEOBJECT", &gameObject, sizeof(GameObject*));
            if (dragCancelled)
            {
                ImGui::Text("Moving: %s", gameObject->GetName().c_str());
                ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.0f, 1.0f), "CANCELLED - Release mouse to finish");
            }
            else
            {
                ImGui::Text("Moving: %s", gameObject->GetName().c_str());
                ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(Press ESC to cancel)");
            }
            ImGui::EndDragDropSource();

            if (!ImGui::IsMouseDragging(ImGuiMouseButton_Left))
            {
                dragStarted = false;
            }
        }

        // Drop 
        if (ImGui::BeginDragDropTarget())
        {
            const ImGuiPayload* payload = ImGui::GetDragDropPayload();
            if (payload && payload->IsDataType("HIERARCHY_GAMEOBJECT"))
            {
                GameObject* draggedObject = *(GameObject**)payload->Data;
                DropPosition dropPos = GetDropPosition(draggedObject, gameObject);

                // Visual feedback
                if (dropPos != DropPosition::NONE)
                {
                    ImVec2 itemMin = ImGui::GetItemRectMin();
                    ImVec2 itemMax = ImGui::GetItemRectMax();

                    if (dropPos == DropPosition::BEFORE)
                    {
                        // Line above item
                        DrawInsertionLine(ImVec2(itemMin.x, itemMin.y), ImVec2(itemMax.x, itemMin.y));
                    }
                    else if (dropPos == DropPosition::AFTER)
                    {
                        // Line below item
                        DrawInsertionLine(ImVec2(itemMin.x, itemMax.y), ImVec2(itemMax.x, itemMax.y));
                    }
                    else if (dropPos == DropPosition::ON)
                    {
                        // Rectangle around item
                        ImDrawList* drawList = ImGui::GetWindowDrawList();
                        drawList->AddRect(itemMin, itemMax, IM_COL32(0, 255, 0, 180), 0.0f, 0, 2.0f);
                    }
                }
            }

            // Check for cancellation
            if (const ImGuiPayload* acceptPayload = ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT"))
            {
                GameObject* draggedObject = *(GameObject**)acceptPayload->Data;

                if (dragCancelled)
                {
                    LOG_DEBUG("Drop cancelled by user");
                    dragCancelled = false;
                    ImGui::EndDragDropTarget();
                    return;
                }

                DropPosition dropPos = GetDropPosition(draggedObject, gameObject);

                if (dropPos == DropPosition::BEFORE)
                {
                    GameObject* parent = gameObject->GetParent();
                    if (parent)
                    {
                        Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                            std::make_unique<ReparentCommand>(draggedObject, parent, childIndex)
                        );
                    }
                }
                else if (dropPos == DropPosition::AFTER)
                {
                    GameObject* parent = gameObject->GetParent();
                    if (parent)
                    {
                        Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                            std::make_unique<ReparentCommand>(draggedObject, parent, childIndex + 1)
                        );
                    }
                }
                else if (dropPos == DropPosition::ON)
                {
                    int newIndex = static_cast<int>(gameObject->GetChildren().size());
                    Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                        std::make_unique<ReparentCommand>(draggedObject, gameObject, newIndex)
                    );
                }
                else
                {
                    LOG_DEBUG("Invalid drop position");
                }
            }
            ImGui::EndDragDropTarget();
        }

        // Recursively draw children
        if (nodeOpen && hasChildren)
        {
            for (int i = 0; i < static_cast<int>(children.size()); ++i)
            {
                DrawGameObjectNode(children[i], i);
            }
            ImGui::TreePop();
        }
    }
}

void HierarchyWindow::SelectGameObjectAndChildren(GameObject* gameObject)
{
    if (gameObject == nullptr)
        return;

    SelectionManager* selectionManager = Application::GetInstance().selectionManager;
    selectionManager->AddToSelection(gameObject);

    const std::vector<GameObject*>& children = gameObject->GetChildren();
    for (GameObject* child : children)
    {
        SelectGameObjectAndChildren(child);
    }
}

bool HierarchyWindow::IsDescendantOf(GameObject* potentialDescendant, GameObject* potentialAncestor)
{
    if (potentialDescendant == nullptr || potentialAncestor == nullptr)
        return false;

    GameObject* current = potentialDescendant->GetParent();
    while (current != nullptr)
    {
        if (current == potentialAncestor)
            return true;
        current = current->GetParent();
    }

    return false;
}

DropPosition HierarchyWindow::GetDropPosition(GameObject* draggedObject, GameObject* targetObject)
{
    if (draggedObject == nullptr || targetObject == nullptr)
        return DropPosition::NONE;

    if (draggedObject == targetObject)
        return DropPosition::NONE;

    if (IsDescendantOf(targetObject, draggedObject))
        return DropPosition::NONE;

    // Mouse position relative to item
    ImVec2 itemMin = ImGui::GetItemRectMin();
    ImVec2 itemMax = ImGui::GetItemRectMax();
    ImVec2 mousePos = ImGui::GetMousePos();

    float itemHeight = itemMax.y - itemMin.y;
    float relativeY = mousePos.y - itemMin.y;

    // Top 25% = BEFORE, middle 50% = ON, bottom 25% = AFTER
    if (relativeY < itemHeight * 0.25f)
    {
        return DropPosition::BEFORE;
    }
    else if (relativeY > itemHeight * 0.75f)
    {
        return DropPosition::AFTER;
    }
    else
    {
        return DropPosition::ON;
    }
}

void HierarchyWindow::DrawInsertionLine(const ImVec2& start, const ImVec2& end)
{
    ImDrawList* drawList = ImGui::GetWindowDrawList();
    drawList->AddLine(start, end, IM_COL32(255, 200, 0, 255), 2.0f);
}

void HierarchyWindow::HandleAutoScroll()
{
    if (!ImGui::IsMouseDragging(ImGuiMouseButton_Left))
        return;

    ImVec2 mousePos = ImGui::GetMousePos();
    ImVec2 windowPos = ImGui::GetWindowPos();
    ImVec2 windowSize = ImGui::GetWindowSize();

    float scrollY = ImGui::GetScrollY();
    float maxScrollY = ImGui::GetScrollMaxY();

    // Scroll up if near top
    if (mousePos.y < windowPos.y + AUTO_SCROLL_MARGIN)
    {
        if (scrollY > 0)
        {
            ImGui::SetScrollY(scrollY - AUTO_SCROLL_SPEED);
        }
    }
    // Scroll down if near bottom
    else if (mousePos.y > windowPos.y + windowSize.y - AUTO_SCROLL_MARGIN)
    {
        if (scrollY < maxScrollY)
        {
            ImGui::SetScrollY(scrollY + AUTO_SCROLL_SPEED);
        }
    }
}