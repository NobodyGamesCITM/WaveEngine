#pragma once
#include <nlohmann/json.hpp>
#include "Globals.h"

struct PrefabInstance {
    UID prefabUID = 0;
    nlohmann::json overrides;
};