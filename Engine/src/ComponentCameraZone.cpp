#include "ComponentCameraZone.h"
#include "GameObject.h"
#include "Transform.h"
#include "Application.h"
#include "ModuleScene.h"
#include "Renderer.h"
#include <imgui.h>
#include <algorithm>

std::vector<ComponentCameraZone*> ComponentCameraZone::activeZones;

ComponentCameraZone::ComponentCameraZone(GameObject* owner) : Component(owner, ComponentType::CAMERA_ZONE) {
    activeZones.push_back(this);
}

ComponentCameraZone::~ComponentCameraZone() {
    auto it = std::find(activeZones.begin(), activeZones.end(), this);
    if (it != activeZones.end()) {
        activeZones.erase(it);
    }
}

bool ComponentCameraZone::Contains(const glm::vec3& point) const {
    // GetGlobalMatrix and invert
    glm::mat4 globalMat = owner->transform->GetGlobalMatrix();
    glm::mat4 inverseMat = glm::inverse(globalMat);

    // Transform the position of the player to the local space of the box
    glm::vec3 localPoint = glm::vec3(inverseMat * glm::vec4(point, 1.0f));

    // Check if its inside the box
    glm::vec3 halfSize = zoneSize * 0.5f;

    return (localPoint.x >= -halfSize.x && localPoint.x <= halfSize.x &&
        localPoint.y >= -halfSize.y && localPoint.y <= halfSize.y &&
        localPoint.z >= -halfSize.z && localPoint.z <= halfSize.z);
}

void ComponentCameraZone::DrawDebug() {
    if (!showDebug) return;

    glm::vec3 halfSize = zoneSize * 0.5f;

    // Corners box
    glm::vec3 localCorners[8] = {
        {-halfSize.x, -halfSize.y, -halfSize.z}, { halfSize.x, -halfSize.y, -halfSize.z},
        { halfSize.x,  halfSize.y, -halfSize.z}, {-halfSize.x,  halfSize.y, -halfSize.z},
        {-halfSize.x, -halfSize.y,  halfSize.z}, { halfSize.x, -halfSize.y,  halfSize.z},
        { halfSize.x,  halfSize.y,  halfSize.z}, {-halfSize.x,  halfSize.y,  halfSize.z}
    };

    // Transform the corners to the real world using global matrix
    glm::mat4 globalMat = owner->transform->GetGlobalMatrix();
    glm::vec3 worldCorners[8];
    for (int i = 0; i < 8; ++i) {
        worldCorners[i] = glm::vec3(globalMat * glm::vec4(localCorners[i], 1.0f));
    }

    glm::vec4 color(0.0f, 1.0f, 0.0f, 1.0f); // Draw green for the box
    auto* render = Application::GetInstance().renderer.get();

    for (int i = 0; i < 4; ++i) {
        render->DrawLine(worldCorners[i], worldCorners[(i + 1) % 4], color);
        render->DrawLine(worldCorners[i + 4], worldCorners[((i + 1) % 4) + 4], color);
        render->DrawLine(worldCorners[i], worldCorners[i + 4], color);
    }
}

void ComponentCameraZone::DrawAllDebug() {
    for (auto* zone : activeZones) {
        if (zone->owner->IsActive()) {
            zone->DrawDebug();
        }
    }
}

void ComponentCameraZone::OnEditor() {
#ifndef WAVE_GAME
    const char* modeNames[] = { "Offset Tracking", "Fixed Pos + LookAt", "Fixed Pos + Fixed Rot" };
    int currentMode = static_cast<int>(mode);
    if (ImGui::Combo("Camera Mode", &currentMode, modeNames, 3)) {
        mode = static_cast<CameraMode>(currentMode);
    }

    ImGui::DragInt("Priority", &priority);
    ImGui::DragFloat("Blend Time", &blendTime, 0.1f, 0.0f, 10.0f);
    ImGui::Separator();
    ImGui::DragFloat3("Zone Size", &zoneSize.x, 0.1f, 0.1f, 1000.0f);
    ImGui::Separator();

    ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "Camera Location Object (Optional)");

    std::string btnText = cameraLocationObj ? cameraLocationObj->GetName() : "None (Drag GameObject Here)";
    ImGui::Button(btnText.c_str(), ImVec2(ImGui::GetContentRegionAvail().x - 50, 20));

    if (ImGui::BeginDragDropTarget()) {
        if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT")) {
            GameObject* draggedObject = *(GameObject**)payload->Data;
            cameraLocationObj = draggedObject;
        }
        ImGui::EndDragDropTarget();
    }

    ImGui::SameLine();
    if (ImGui::Button("Clear")) {
        cameraLocationObj = nullptr;
    }

    if (!cameraLocationObj) {
        ImGui::TextDisabled("Using manual offsets below:");
        ImGui::DragFloat3("Camera Offset", &cameraOffset.x, 0.1f);
        ImGui::DragFloat3("Camera Rotation", &cameraEulerAngles.x, 1.0f);
    }

    ImGui::Separator();
    ImGui::DragFloat("FOV", &fov, 0.5f, 10.0f, 120.0f);
    ImGui::Checkbox("Show Debug Box", &showDebug);
#endif
}

void ComponentCameraZone::Serialize(nlohmann::json& obj) const {
    obj["cameraMode"] = static_cast<int>(mode);
    obj["priority"] = priority;
    obj["blendTime"] = blendTime;
    obj["zoneSize"] = { zoneSize.x, zoneSize.y, zoneSize.z };
    obj["cameraOffset"] = { cameraOffset.x, cameraOffset.y, cameraOffset.z };
    obj["cameraEulerAngles"] = { cameraEulerAngles.x, cameraEulerAngles.y, cameraEulerAngles.z };
    obj["fov"] = fov;
    obj["showDebug"] = showDebug;

    obj["cameraLocationUID"] = cameraLocationObj ? cameraLocationObj->GetUID() : 0;
}

void ComponentCameraZone::Deserialize(const nlohmann::json& obj) {
    mode = static_cast<CameraMode>(obj.value("cameraMode", 0));
    priority = obj.value("priority", 0);
    blendTime = obj.value("blendTime", 1.5f);
    if (obj.contains("zoneSize")) { auto& s = obj["zoneSize"]; zoneSize = glm::vec3(s[0], s[1], s[2]); }
    if (obj.contains("cameraOffset")) { auto& o = obj["cameraOffset"]; cameraOffset = glm::vec3(o[0], o[1], o[2]); }
    if (obj.contains("cameraEulerAngles")) { auto& e = obj["cameraEulerAngles"]; cameraEulerAngles = glm::vec3(e[0], e[1], e[2]); }
    fov = obj.value("fov", 45.0f);
    showDebug = obj.value("showDebug", true);

    cameraLocationUID = obj.value("cameraLocationUID", 0ULL);
}

void ComponentCameraZone::SolveReferences() {
    if (cameraLocationUID != 0) {
        cameraLocationObj = Application::GetInstance().scene->FindObject(cameraLocationUID);
    }
}