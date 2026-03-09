#include "ReverbZone.h"
#include "Transform.h"
#include "Application.h"
#include "AudioSystem.h"
#include "Log.h"
#ifndef WAVE_GAME
    #include <imgui.h>
#endif 

#include <glm/gtc/matrix_inverse.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <algorithm>

const std::vector<ReverbPresetData> reverbPresets = {

    { AK::AUX_BUSSES::REVERB_ABSORPTION,     "Absorption" },  // Index 0
    { AK::AUX_BUSSES::REVERB_CATHEDRAL,         "Cathedral" },       // Index 1 (default)
    { AK::AUX_BUSSES::REVERB_INSIDEMYHEAD, "Inside My Head" },  // Index 2
    { AK::AUX_BUSSES::REVERB_LARGEPLATE,     "Large Plate" },     // Index 3
    { AK::AUX_BUSSES::REVERB_LONGDARKHALL,   "Long Dark Hall" },  // Index 4
    { AK::AUX_BUSSES::REVERB_ALUMINUMTANK,      "Metal Tank" },      // Index 5
    { AK::AUX_BUSSES::REVERB_OUTSIDE,        "Outside" },         // Index 6
    { AK::AUX_BUSSES::REVERB_ROBOTIC,       "Robotic" }           // Index 7
};


ReverbZone::ReverbZone(GameObject* owner)
    : Component(owner, ComponentType::REVERBZONE)
{
    name = "Reverb Zone";
    // Register with audio system
    if (Application::GetInstance().audio && Application::GetInstance().audio->audioSystem) {
        Application::GetInstance().audio->audioSystem->RegisterReverbZone(this);
    }
}

ReverbZone::~ReverbZone()
{
    if (Application::GetInstance().audio && Application::GetInstance().audio->audioSystem) {
        Application::GetInstance().audio->audioSystem->UnregisterReverbZone(this);
    }
}

void ReverbZone::Update()
{
    DrawDebug();
}


bool ReverbZone::ContainsPoint(const glm::vec3& worldPoint) const
{
    if (!enabled) return false;

    Transform* t = static_cast<Transform*>(owner->GetComponent(ComponentType::TRANSFORM));
    if (!t) return false;

    glm::mat4 worldMat = t->GetWorldMatrixRecursive();
    glm::vec3 zonePos = glm::vec3(worldMat[3]);

    if (shape == Shape::SPHERE) {
        float actualRadius = radius;

        //Transform centerOffset from local to world space using rotation only (no scale)

        glm::mat4 rotationMat = glm::mat4(
            glm::vec4(glm::normalize(glm::vec3(worldMat[0])), 0.0f),
            glm::vec4(glm::normalize(glm::vec3(worldMat[1])), 0.0f),
            glm::vec4(glm::normalize(glm::vec3(worldMat[2])), 0.0f),
            glm::vec4(0.0f, 0.0f, 0.0f, 1.0f)
        );

        glm::vec3 worldOffset = glm::vec3(rotationMat * glm::vec4(centerOffset, 0.0f));
        float distance = glm::distance(worldPoint, zonePos + worldOffset);

        return distance <= actualRadius;
    }
    
    else { 
        
        // Extract rotation only (strip scale via normalization)
        glm::mat3 rotOnly = glm::mat3(
            glm::normalize(glm::vec3(worldMat[0])),
            glm::normalize(glm::vec3(worldMat[1])),
            glm::normalize(glm::vec3(worldMat[2]))
        );

        glm::mat4 noScaleWorldMat = glm::mat4(rotOnly);
        noScaleWorldMat[3] = glm::vec4(zonePos, 1.0f); // set translation

        glm::vec3 local = glm::vec3(glm::inverse(noScaleWorldMat) * glm::vec4(worldPoint, 1.0f));
        // centerOffset check is missing for BOX too — add it:
        local -= centerOffset; // apply offset in local space, or transform offset first
        glm::vec3 absLocal = glm::abs(local);
        return (absLocal.x <= extents.x) && (absLocal.y <= extents.y) && (absLocal.z <= extents.z);
    }
    
}

std::string ReverbZone::GetBusNameFromID(AkUniqueID id) const 
{
    for (const auto& preset : reverbPresets) {
        if (preset.busID == id) {
            std::string name = preset.name;

            // remove all white spaces
            name.erase(std::remove(name.begin(), name.end(), ' '), name.end());
            return "Reverb_" + name;
        }

    }
    return "Unknown_Bus";
}

AkUniqueID ReverbZone::GetIDFromBusName(const std::string& name) const
{
    for (const auto& preset : reverbPresets) {
       
        std::string fullName = "Reverb_" + std::string(preset.name);

        // check both the prefixed name and the raw name for maximum safety
        if (fullName == name || std::string(preset.name) == name) {
            return preset.busID;
        }
    }

    // fallback: if name is not found, return the cathedral default
    return AK::AUX_BUSSES::REVERB_CATHEDRAL;
}

void ReverbZone::Serialize(nlohmann::json& componentObj) const
{
    componentObj["shape"] = static_cast<int>(shape);
    componentObj["radius"] = radius;
    componentObj["extents"] = { extents.x, extents.y, extents.z };
    componentObj["centerOffset"] = { centerOffset.x, centerOffset.y, centerOffset.z };
    componentObj["auxBusID"] = auxBusID;
    componentObj["auxBusName"] = GetBusNameFromID(auxBusID);
    componentObj["presetIndex"] = presetIndex;
    componentObj["wetLevel"] = wetLevel;
    componentObj["priority"] = priority;
    componentObj["enabled"] = enabled;
}

void ReverbZone::Deserialize(const nlohmann::json& componentObj)
{
    if (componentObj.contains("shape")) shape = static_cast<Shape>(componentObj["shape"].get<int>());
    if (componentObj.contains("radius")) radius = componentObj["radius"].get<float>();
    if (componentObj.contains("extents")) {
        auto e = componentObj["extents"];
        extents = glm::vec3(e[0].get<float>(), e[1].get<float>(), e[2].get<float>());
    }
    if (componentObj.contains("centerOffset")) {
        auto c = componentObj["centerOffset"];
        centerOffset = glm::vec3(c[0].get<float>(), c[1].get<float>(), c[2].get<float>());
    }
    if (componentObj.contains("auxBusName")) auxBusName = componentObj["auxBusName"].get<std::string>();
    if (componentObj.contains("auxBusID")) auxBusID = GetIDFromBusName(auxBusName);
    if (componentObj.contains("presetIndex")) {
        presetIndex = componentObj["presetIndex"].get<int>();
        if (presetIndex >= 0 && presetIndex < (int)reverbPresets.size()) {
            auxBusID = reverbPresets[presetIndex].busID;
            auxBusName = GetBusNameFromID(auxBusID);
        }
        
    }

    if (componentObj.contains("wetLevel")) wetLevel = componentObj["wetLevel"].get<float>();
    if (componentObj.contains("priority")) priority = componentObj["priority"].get<int>();
    if (componentObj.contains("enabled")) enabled = componentObj["enabled"].get<bool>();
}

void ReverbZone::DrawDebug()
{

    
}

void ReverbZone::OnEditor()
{
#ifndef WAVE_GAME

    const char* shapeNames[] = { "Sphere", "Box" };
    int shapeIndex = static_cast<int>(shape);

  
    if (ImGui::Combo("Shape", &shapeIndex, shapeNames, IM_ARRAYSIZE(shapeNames))) {
        shape = static_cast<Shape>(shapeIndex);
    }

    if (shape == Shape::SPHERE) {
        ImGui::DragFloat("Radius", &radius, 0.1f, 0.0f, 10000.0f);
        if (ImGui::IsItemHovered()) ImGui::SetTooltip("Sphere radius in world units");
    }
    else {
        ImGui::DragFloat3("Half Extents", &extents[0], 0.1f, 0.0f, 10000.0f);
        if (ImGui::IsItemHovered()) ImGui::SetTooltip("Half extents (local space) for box shape");

        
    }

    ImGui::DragFloat3("Center Offset", &centerOffset[0], 0.1f, -10000.0f, 10000.0f);
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Reverb zone center relative to the object's center");

    static std::vector<const char*> presetLabels;

    // only populate it the very first time this function runs
    if (presetLabels.empty()) {
        for (const auto& preset : reverbPresets) {
            // use the persistent name from your struct
            presetLabels.push_back(preset.name.c_str());
        }
    }

    if (ImGui::Combo("Reverb Preset", &presetIndex, presetLabels.data(), static_cast<int>(presetLabels.size()))) {

        auxBusID = reverbPresets[presetIndex].busID;
    }

    char buf[256];
    strncpy(buf, auxBusName.c_str(), sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    ImGui::LabelText("Aux Bus Name", "%s", GetBusNameFromID(auxBusID).c_str());
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Name of the Wwise Aux Bus to send to (case-sensitive, read-only)");

    ImGui::SliderFloat("Wet Level", &wetLevel, 0.0f, 1.0f);
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Amount of aux send applied to listener while inside (0..1)");

    ImGui::DragInt("Priority", &priority, 1, -10000, 10000);
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Higher priority wins when multiple zones overlap");

    ImGui::Checkbox("Enabled", &enabled);


#endif 
}