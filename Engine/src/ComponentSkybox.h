#pragma once
#include "Component.h"
#include "Globals.h"

class ResourceTexture;

enum class SkyboxFace {
    RIGHT = 0,
    LEFT,
    TOP,
    BOTTOM,
    FRONT,
    BACK,
    NUM_FACES
};

class ComponentSkybox : public Component
{
public:
    ComponentSkybox(GameObject* owner);
    ~ComponentSkybox();

    bool IsType(ComponentType type) override { return type == ComponentType::SKYBOX; };
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::SKYBOX; };
  
    void CleanUp() override;

    void SetFaceTexture(SkyboxFace face, UID textureUID);
    void SetActive(bool b);
    ResourceTexture* GetFaceTexture(SkyboxFace face) const;

    unsigned int GetCubemapID() const { return cubemapID; }
    unsigned int GetVAO() const { return skyboxVAO; }

    void OnEditor() override;

    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

private:
    bool active = false;
    unsigned int cubemapID = 0;
    unsigned int skyboxVAO = 0;
    unsigned int skyboxVBO = 0;

    ResourceTexture* faces[6] = { nullptr };
    UID facesResourcesUID[6] = { 0,0,0,0,0,0 };

    void SetupCubeMesh();
    void BuildCubemapFromResources();

};