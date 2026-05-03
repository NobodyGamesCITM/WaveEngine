#pragma once
#include "Component.h"

class ResourceTexture;

enum class SkyboxFace {
    RIGHT = 0,
    LEFT,
    TOP,
    BOTTOM,
    FRONT,
    BACK
};

class ComponentSkybox : public Component
{
public:
    ComponentSkybox(GameObject* owner);
    ~ComponentSkybox();

    bool IsType(ComponentType type) override { return type == ComponentType::SKYBOX; };
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::SKYBOX; };

    void Enable() override;
    void Disable() override;

    void SetFaceTexture(SkyboxFace face, ResourceTexture* texture);
    ResourceTexture* GetFaceTexture(SkyboxFace face) const;

    unsigned int GetCubemapID() const { return cubemapID; }
    unsigned int GetVAO() const { return skyboxVAO; }

private:
    unsigned int cubemapID = 0;
    unsigned int skyboxVAO = 0;
    unsigned int skyboxVBO = 0;

    ResourceTexture* faces[6] = { nullptr };

    void SetupCubeMesh();
    void BuildCubemapFromResources();
    void CleanUp();
};