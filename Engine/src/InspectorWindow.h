#pragma once
#include "EditorWindow.h"
#include "EventListener.h"
#include "ModuleLoader.h"

#include <imgui.h>  
#include <ImGuizmo.h>
#include "LightManager.h"
#include <vector>
#include "AudioSystem.h"
#include <unordered_map>
#include <nlohmann/json.hpp>

class GameObject;

class InspectorWindow : public EditorWindow, public EventListener
{
public:

    InspectorWindow();
    ~InspectorWindow() override;

    void Draw() override;

    ImGuizmo::OPERATION GetCurrentGizmoOperation() const { return currentGizmoOperation; }
    ImGuizmo::MODE GetCurrentGizmoMode() const { return currentGizmoMode; }
    void SetGizmoOperation(ImGuizmo::OPERATION op) { currentGizmoOperation = op; }
    void SetGizmoMode(ImGuizmo::MODE mode) { currentGizmoMode = mode; }
    bool ShouldShowVertexNormals() const { return showVertexNormals; }
    bool ShouldShowFaceNormals() const { return showFaceNormals; }
    void OnEvent(const Event& event);

    LightManager* lightManager;

private:
    void DrawComponentContextMenu(Component* component, bool canRemove);
    bool DrawGameObjectSection(GameObject* selectedObject);
    void DrawGizmoSettings();
    void DrawAddComponentButton(GameObject* selectedObject);
    void DrawPostProcessingComponent(Component* component);
    // Draw component functions
    void DrawTransformComponent(Component* component);
    void DrawCameraComponent(Component* component);
    void DrawMeshComponent(Component* component);
    void DrawSkinnedMeshComponent(Component* component);
    void DrawMaterialComponent(Component* component);
    void DrawRotateComponent(Component* component);
    void DrawScriptComponent(Component* component);
    void DrawParticleComponent(Component* component);
    void DrawRigidodyComponent(Component* component);
    void DrawBoxColliderComponent(Component* component);
    void DrawSphereColliderComponent(Component* component);
    void DrawCapsuleColliderComponent(Component* component);
    void DrawPlaneColliderComponent(Component* component);
    void DrawInfinitePlaneColliderComponent(Component* component);
    void DrawMeshColliderComponent(Component* component);
    void DrawConvexColliderComponent(Component* component);
    void DrawHingeJointComponent(Component* component);
    void DrawDistanceJointComponent(Component* component);
    void DrawFixedJointComponent(Component* component);
    void DrawD6JointComponent(Component* component);
    void DrawPrismaticJointComponent(Component* component);
    void DrawSphericalJointComponent(Component* component);
    void DrawAudioSourceComponent(Component* component);
    void DrawCanvasComponent(Component* selectedObject);
    void DrawAudioListenerComponent(Component* component);
    void DrawReverbZoneComponent(Component* component);
    void DrawAnimationComponent(Component* component);
    void DrawNavigationComponent(Component* component);
    void DrawLightComponent(Component* component);

    void GetAllGameObjects(GameObject* root, std::vector<GameObject*>& outObjects);
    bool IsDescendantOf(GameObject* potentialDescendant, GameObject* potentialAncestor);

    bool IsPendingRemoval(Component* comp) const;

    void DrawPrefabInstanceSection(GameObject* selectedObject);

    void UpdatePrefabInstancesExcept(UID prefabUID, GameObject* exclude);

    AudioSystem* audioSystem;

    bool m_WasAnyItemActive = false;
    std::unordered_map<Component*, nlohmann::json> m_ComponentSnapshots;
    std::vector<Component*> m_PendingRemoval;

    ImGuizmo::OPERATION currentGizmoOperation = ImGuizmo::TRANSLATE;
    ImGuizmo::MODE currentGizmoMode = ImGuizmo::WORLD;

    bool showVertexNormals = false;
    bool showFaceNormals = false;

    bool inspectorLocked = false;
    GameObject* lockedObject;
};