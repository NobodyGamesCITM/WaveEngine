#pragma once

#include "Component.h"
#include <string>
#include <glm/glm.hpp>
#include "Wwise_IDs.h"

struct ReverbPresetData {
    AkUniqueID busID;
    std::string name;
};



extern const std::vector<ReverbPresetData> reverbPresets;

class ReverbZone : public Component {
public:
    enum class Shape {
        SPHERE = 0,
        BOX = 1
    };   

    ReverbZone(GameObject* owner);
    virtual ~ReverbZone();

    void Update() override;

    std::string GetBusNameFromID(AkUniqueID id) const;
   
    AkUniqueID GetIDFromBusName(const std::string& name) const;
   
    bool IsType(ComponentType type) override { return type == ComponentType::REVERBZONE; };
    bool IsIncompatible(ComponentType type) override { return false; };

    // point test in world space
    bool ContainsPoint(const glm::vec3& worldPoint) const;



    // Component overrides
    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;
    void OnEditor() override;

    void DrawDebug();

public:
    Shape shape = Shape::SPHERE;
    int presetIndex = 1;
    float radius = 1.0f;
    glm::vec3 extents = glm::vec3(0.5f);
    glm::vec3 centerOffset = glm::vec3(0.0f);

    std::string auxBusName = "Reverb_Cathedral";
    AkUniqueID auxBusID = AK::AUX_BUSSES::REVERB_CATHEDRAL;
    
    float wetLevel = 1.0f;
    int priority = 0;
    bool enabled = true;
};