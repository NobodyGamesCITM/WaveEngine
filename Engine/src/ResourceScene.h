#pragma once

#include "ModuleResources.h"
#include <nlohmann/json.hpp>

struct Scene {

    nlohmann::json sceneJson;

    Scene() = default;

    bool IsValid() const {
        return !sceneJson.is_null() && !sceneJson.empty();
    }
};

class ResourceScene : public Resource {
public:

    ResourceScene(UID uid);
    virtual ~ResourceScene();

    bool LoadInMemory() override;
    void UnloadFromMemory() override;

    nlohmann::json GetSceneHierarchy() {
        return scene.IsValid() ? scene.sceneJson : nlohmann::json();
    }

private:
    
    Scene scene;
};