#pragma once

#include "ModuleResources.h"
#include <nlohmann/json.hpp>

struct Prefab {

    nlohmann::json prefabJson;

    Prefab() = default;

    bool IsValid() const {
        return !prefabJson.is_null() && !prefabJson.empty();
    }
};


class ResourcePrefab : public Resource {
public:
    ResourcePrefab(UID uid);
    ~ResourcePrefab();

    bool LoadInMemory() override;
    void UnloadFromMemory() override;

    nlohmann::json GetPrefabHierarchy() {
        return prefab.IsValid() ? prefab.prefabJson : nlohmann::json();
    }


private:
    Prefab prefab;
};