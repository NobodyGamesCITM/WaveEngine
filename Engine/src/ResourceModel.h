#pragma once

#include "ModuleResources.h"
#include <nlohmann/json.hpp>

struct Model {

    nlohmann::json modelJson;

    Model() = default;

    bool IsValid() const {
        return !modelJson.is_null() && !modelJson.empty();
    }
};

class ResourceModel : public Resource {
public:

    ResourceModel(UID uid);
    virtual ~ResourceModel();

    bool LoadInMemory() override;
    void UnloadFromMemory() override;

    nlohmann::json GetModelHierarchy() {
        return model.IsValid() ? model.modelJson : nlohmann::json();
    }

private:
    
    Model model;
};