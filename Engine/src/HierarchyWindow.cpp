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
#include "DeleteCommand.h"
#include "CreateCommand.h"
#include "Transform.h"
#include "ComponentCamera.h"
#include "ComponentCanvas.h"
#include "ComponentPostProcessing.h"

HierarchyWindow::HierarchyWindow()
    : EditorWindow("Hierarchy")
{
}

GameObject* HierarchyWindow::CreateAndRegisterGameObject(const std::string& name, GameObject* parent)
{
    GameObject* obj = Application::GetInstance().scene->CreateGameObject(name);

    if (parent)
        obj->SetParent(parent);

    Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
        std::make_unique<CreateCommand>(obj));

    Application::GetInstance().selectionManager->SetSelectedObject(obj);

    return obj;
}

void HierarchyWindow::DrawBackgroundContextMenu()
{
    if (!ImGui::BeginPopupContextWindow(0, ImGuiPopupFlags_MouseButtonRight | ImGuiPopupFlags_NoOpenOverItems))
        return;

    if (ImGui::MenuItem("Create Empty"))
        CreateAndRegisterGameObject("GameObject");

    DrawCreate3DObjectSubmenu();

    if (ImGui::MenuItem("Create Camera"))
    {
        GameObject* camera = CreateAndRegisterGameObject("Camera");
        camera->CreateComponent(ComponentType::CAMERA);
    }

    if (ImGui::MenuItem("Create Canvas"))
    {
        GameObject* canvas = CreateAndRegisterGameObject("Canvas");
        canvas->CreateComponent(ComponentType::CANVAS);
    }

    if (ImGui::MenuItem("Create Post Processing"))
    {
        GameObject* postProcessing = CreateAndRegisterGameObject("PostProcessing");
        postProcessing->CreateComponent(ComponentType::POSTPROCESSING);
    }

    ImGui::EndPopup();
}


void HierarchyWindow::DrawGameObjectContextMenu(GameObject* gameObject)
{
    if (!ImGui::BeginPopupContextItem())
        return;

    // Rename
    if (ImGui::MenuItem("Rename"))
    {
        renamingObject = gameObject;
        strncpy(renameBuffer, gameObject->GetName().c_str(), sizeof(renameBuffer) - 1);
    }

    // Duplicate
    if (ImGui::MenuItem("Duplicate"))
    {
        GameObject* clone = Application::GetInstance().editor->CloneGameObject(gameObject);
        GameObject* parent = gameObject->GetParent()
            ? gameObject->GetParent()
            : Application::GetInstance().scene->GetRoot();
        parent->AddChild(clone);

        Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
            std::make_unique<CreateCommand>(clone));
        Application::GetInstance().selectionManager->SetSelectedObject(clone);
    }

    // Delete
    if (ImGui::MenuItem("Delete"))
    {
        Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
            std::make_unique<DeleteCommand>(gameObject));
    }

    ImGui::Separator();

    // Create Empty child
    if (ImGui::MenuItem("Create Empty"))
        CreateAndRegisterGameObject("GameObject", gameObject);

    // Create Empty Parent
    if (ImGui::MenuItem("Create Empty Parent"))
    {
        GameObject* newParent = Application::GetInstance().scene->CreateGameObject("GameObject");

        // Match position/rotation to child
        auto* childTransform = static_cast<Transform*>(gameObject->GetComponent(ComponentType::TRANSFORM));
        auto* parentTransform = static_cast<Transform*>(newParent->GetComponent(ComponentType::TRANSFORM));
        if (childTransform && parentTransform)
        {
            parentTransform->SetGlobalPosition(childTransform->GetGlobalPosition());
            parentTransform->SetGlobalRotation(childTransform->GetGlobalRotation());
        }

        if (gameObject->GetParent())
            newParent->SetParent(gameObject->GetParent());

        Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
            std::make_unique<CreateCommand>(newParent));
        Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
            std::make_unique<ReparentCommand>(gameObject, newParent, -1));

        Application::GetInstance().selectionManager->SetSelectedObject(newParent);
    }

    ImGui::EndPopup();
}

void HierarchyWindow::DrawCreate3DObjectSubmenu()
{
    if (!ImGui::BeginMenu("3D Object"))
        return;

    if (ImGui::MenuItem("Cube"))   LOG_CONSOLE("Create Cube not implemented");
    if (ImGui::MenuItem("Sphere")) LOG_CONSOLE("Create Sphere not implemented");
    if (ImGui::MenuItem("Plane"))  LOG_CONSOLE("Create Plane not implemented");

    ImGui::EndMenu();
}

void HierarchyWindow::Draw()
{
    if (!isOpen) return;

    ImGui::Begin(name.c_str(), &isOpen);

    isHovered = ImGui::IsWindowHovered(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows);

    HandleAutoScroll();

    GameObject* root = Application::GetInstance().scene->GetRoot();

    if (root)
    {
        for (GameObject* child : root->GetChildren())
        {
            if (child == nullptr) continue;

            DrawGameObjectNode(child);

            // Drop onto root level
            if (ImGui::BeginDragDropTarget())
            {
                if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT"))
                {
                    if (!dragCancelled)
                    {
                        GameObject* dragged = *(GameObject**)payload->Data;
                        if (dragged != root)
                        {
                            int newIndex = static_cast<int>(root->GetChildren().size());
                            Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                                std::make_unique<ReparentCommand>(dragged, root, newIndex));
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

    DrawBackgroundContextMenu();

    ImGui::End();
}

void HierarchyWindow::DrawGameObjectNode(GameObject* gameObject, int childIndex)
{
    if (gameObject == nullptr) return;

    const std::vector<GameObject*>& children = gameObject->GetChildren();
    bool hasChildren = !children.empty();

    ImGuiTreeNodeFlags nodeFlags = ImGuiTreeNodeFlags_OpenOnArrow;

    SelectionManager* selectionManager = Application::GetInstance().selectionManager;
    if (selectionManager->IsSelected(gameObject))
        nodeFlags |= ImGuiTreeNodeFlags_Selected;

    if (!hasChildren)
        nodeFlags |= ImGuiTreeNodeFlags_Leaf | ImGuiTreeNodeFlags_NoTreePushOnOpen;

    if (renamingObject == gameObject)
    {
        ImGui::SetNextItemWidth(-1);
        if (ImGui::InputText("##rename", renameBuffer, sizeof(renameBuffer),
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
            renamingObject = nullptr;

        return;
    }

    // Active checkbox
    bool isActive = gameObject->IsActive();
    ImGui::PushID(gameObject);
    if (ImGui::Checkbox("##active", &isActive))
        gameObject->SetActive(isActive);
    ImGui::PopID();

    ImGui::SameLine();

    bool nodeOpen = ImGui::TreeNodeEx(gameObject, nodeFlags, "%s", gameObject->GetName().c_str());

    // Selection on click
  /*  if (ImGui::IsItemClicked())
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
    }*/

    if (ImGui::IsItemHovered())
    {
        // Detect click release
        if (ImGui::IsMouseReleased(ImGuiMouseButton_Left))
        {
            // If it was NOT a drag
            if (!ImGui::IsMouseDragging(ImGuiMouseButton_Left))
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
        }
    }
    // Right-click → select before opening menu
    if (ImGui::IsItemClicked(ImGuiMouseButton_Right))
        selectionManager->SetSelectedObject(gameObject);

    DrawGameObjectContextMenu(gameObject);

    // Double-click → rename
    if (ImGui::IsItemHovered() && ImGui::IsMouseDoubleClicked(0))
    {
        renamingObject = gameObject;
        strncpy(renameBuffer, gameObject->GetName().c_str(), sizeof(renameBuffer) - 1);
    }

    if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None))
    {
        static bool dragStarted = false;
        if (!dragStarted) { dragCancelled = false; dragStarted = true; }

        if (ImGui::IsKeyPressed(ImGuiKey_Escape))
            dragCancelled = true;

        ImGui::SetDragDropPayload("HIERARCHY_GAMEOBJECT", &gameObject, sizeof(GameObject*));
        ImGui::Text("Moving: %s", gameObject->GetName().c_str());

        if (dragCancelled)
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.0f, 1.0f), "CANCELLED - Release to finish");
        else
            ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(Press ESC to cancel)");

        ImGui::EndDragDropSource();

        if (!ImGui::IsMouseDragging(ImGuiMouseButton_Left))
            dragStarted = false;
    }

    if (ImGui::BeginDragDropTarget())
    {
        const ImGuiPayload* payload = ImGui::GetDragDropPayload();
        if (payload && payload->IsDataType("HIERARCHY_GAMEOBJECT"))
        {
            GameObject* dragged = *(GameObject**)payload->Data;
            DropPosition dropPos = GetDropPosition(dragged, gameObject);

            // Visual feedback
            ImVec2 itemMin = ImGui::GetItemRectMin();
            ImVec2 itemMax = ImGui::GetItemRectMax();

            if (dropPos == DropPosition::BEFORE)
                DrawInsertionLine({ itemMin.x, itemMin.y }, { itemMax.x, itemMin.y });
            else if (dropPos == DropPosition::AFTER)
                DrawInsertionLine({ itemMin.x, itemMax.y }, { itemMax.x, itemMax.y });
            else if (dropPos == DropPosition::ON)
                ImGui::GetWindowDrawList()->AddRect(itemMin, itemMax, IM_COL32(0, 255, 0, 180), 0.0f, 0, 2.0f);
        }

        if (const ImGuiPayload* accepted = ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT"))
        {
            if (dragCancelled)
            {
                LOG_DEBUG("Drop cancelled by user");
                dragCancelled = false;
                ImGui::EndDragDropTarget();
                return;
            }

            GameObject* dragged = *(GameObject**)accepted->Data;
            DropPosition dropPos = GetDropPosition(dragged, gameObject);
            GameObject* parent = gameObject->GetParent();

            if (dropPos == DropPosition::BEFORE && parent)
            {
                int realIndex = parent->GetChildIndex(gameObject);
                if (realIndex < 0) realIndex = 0;
                Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                    std::make_unique<ReparentCommand>(dragged, parent, realIndex));
            }
            else if (dropPos == DropPosition::AFTER && parent)
            {
                int realIndex = parent->GetChildIndex(gameObject);
                Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
					std::make_unique<ReparentCommand>(dragged, parent, realIndex + 1));
            }
            else if (dropPos == DropPosition::ON)
            {
                const auto& ch = gameObject->GetChildren();
                int newIndex = static_cast<int>(ch.size());
                if (dragged->GetParent() == gameObject) --newIndex;
                newIndex = std::max(0, newIndex);
                Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                    std::make_unique<ReparentCommand>(dragged, gameObject, newIndex));
            }
        }

        ImGui::EndDragDropTarget();
    }

    if (nodeOpen && hasChildren)
    {
        for (int i = 0; i < static_cast<int>(children.size()); ++i)
            DrawGameObjectNode(children[i], i);
        ImGui::TreePop();
    }
}

void HierarchyWindow::SelectGameObjectAndChildren(GameObject* gameObject)
{
    if (gameObject == nullptr) return;

    Application::GetInstance().selectionManager->AddToSelection(gameObject);
    for (GameObject* child : gameObject->GetChildren())
        SelectGameObjectAndChildren(child);
}

bool HierarchyWindow::IsDescendantOf(GameObject* potentialDescendant, GameObject* potentialAncestor)
{
    if (!potentialDescendant || !potentialAncestor) return false;

    GameObject* current = potentialDescendant->GetParent();
    while (current)
    {
        if (current == potentialAncestor) return true;
        current = current->GetParent();
    }
    return false;
}

DropPosition HierarchyWindow::GetDropPosition(GameObject* draggedObject, GameObject* targetObject)
{
    if (!draggedObject || !targetObject)          return DropPosition::NONE;
    if (draggedObject == targetObject)            return DropPosition::NONE;
    if (IsDescendantOf(targetObject, draggedObject)) return DropPosition::NONE;

    ImVec2 itemMin = ImGui::GetItemRectMin();
    ImVec2 itemMax = ImGui::GetItemRectMax();
    float  relativeY = ImGui::GetMousePos().y - itemMin.y;
    float  height = itemMax.y - itemMin.y;

    if (relativeY < height * 0.25f) return DropPosition::BEFORE;
    if (relativeY > height * 0.75f) return DropPosition::AFTER;
    return DropPosition::ON;
}

void HierarchyWindow::DrawInsertionLine(const ImVec2& start, const ImVec2& end)
{
    ImGui::GetWindowDrawList()->AddLine(start, end, IM_COL32(255, 200, 0, 255), 2.0f);
}

void HierarchyWindow::HandleAutoScroll()
{
    if (!ImGui::IsMouseDragging(ImGuiMouseButton_Left)) return;

    ImVec2 mousePos = ImGui::GetMousePos();
    ImVec2 windowPos = ImGui::GetWindowPos();
    ImVec2 windowSize = ImGui::GetWindowSize();
    float  scrollY = ImGui::GetScrollY();
    float  maxScrollY = ImGui::GetScrollMaxY();

    if (mousePos.y < windowPos.y + AUTO_SCROLL_MARGIN && scrollY > 0)
        ImGui::SetScrollY(scrollY - AUTO_SCROLL_SPEED);
    else if (mousePos.y > windowPos.y + windowSize.y - AUTO_SCROLL_MARGIN && scrollY < maxScrollY)
        ImGui::SetScrollY(scrollY + AUTO_SCROLL_SPEED);
}