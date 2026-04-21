#pragma once
#include <vector>
#include "EditorWindow.h"
#include <imgui.h>
#include <ImGuizmo.h>
#include <glm/glm.hpp>
#include <glm/gtc/quaternion.hpp>

class InspectorWindow;
class GameObject; 
struct aiNode; 

class SceneWindow : public EditorWindow
{
public:
    SceneWindow(InspectorWindow* inspector);
    ~SceneWindow() override = default;

    void Draw() override;

    ImVec2 GetViewportPos() const { return sceneViewportPos; }
    ImVec2 GetViewportSize() const { return sceneViewportSize; }

    bool IsGizmoBeingUsed() const { return isGizmoActive; }

    bool snapEnabled = true;
    float positionSnap = 1.0f;
    float rotationSnap = 15.0f;
    float scaleSnap = 0.1f;

    bool pivotEditMode = false;

private:
    void SelectObject();
    void HandleGizmoInput();
    void DrawGizmo();
    void HandleAssetDropTarget();  
    unsigned long long FindTextureForDroppedMesh(unsigned long long meshUID); // Helper 
    void ApplyMeshTransformFromFBX(GameObject* meshObject, unsigned long long meshUID); // Helper 

    InspectorWindow* inspectorWindow;

    ImVec2 sceneViewportPos;
    ImVec2 sceneViewportSize;

    GameObject* GetGameObjectUnderMouse();

    bool isGizmoActive = false;

    //QOL
    bool gizmoSnapshotTaken = false;
    glm::vec3 gizmoSnapshotPos;
    glm::vec3 gizmoSnapshotRot;
    glm::vec3 gizmoSnapshotScale;

    std::vector<glm::vec3> originalScales;
};