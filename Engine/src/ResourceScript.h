#pragma once

#include "ModuleResources.h"
#include <string>


struct Script {

    std::string scriptContent;

    Script() = default;

    bool IsValid() const {
        return !scriptContent.empty();
    }
};

class ResourceScript : public Resource {
public:
    ResourceScript(UID uid);
    ~ResourceScript();

    bool LoadInMemory() override;
    void UnloadFromMemory() override;

    const std::string& GetScriptContent() const {
        return script.scriptContent;
    }
    bool Reload();

    long long GetLastLoadTime() const { return lastLoadTime; }
    bool NeedsReload() const;

private:
    Script script;
    long long lastLoadTime;
};