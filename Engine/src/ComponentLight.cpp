#include "ComponentLight.h"
#include "Application.h"
#include "Renderer.h"
#include "LightManager.h"
#include "GameObject.h"
#include "Transform.h"
#include <imgui.h>

ComponentLight::ComponentLight(GameObject* owner)
    : Component(owner, ComponentType::LIGHT)
{
    Application::GetInstance().renderer->GetLightManager()->RegisterLight(this);
}

ComponentLight::~ComponentLight()
{
    Application::GetInstance().renderer->GetLightManager()->UnregisterLight(this);
}


//transform sync 
void ComponentLight::UpdateTransformData()
{
    if (!owner || !owner->transform) return;

    glm::vec3 pos = owner->transform->GetGlobalPosition();
    glm::vec3 fwd = owner->transform->GetGlobalRotationQuat() * glm::vec3(0.0f, 0.0f, -1.0f);

    switch (lightType)
    {
    case LightType::DIRECTIONAL:
        directionalData.direction = fwd;
        break;
    case LightType::POINT:
        pointData.position = pos;
        break;
    case LightType::SPOT:
        spotData.position = pos;
        spotData.direction = fwd;
        break;
    }
}

void ComponentLight::Update()
{
}

// editor 

void ComponentLight::OnEditor()
{
    // hay q hacer ifndef y ese mierdonaco
    const char* names[] = { "Directional", "Point", "Spot" };
    int t = (int)lightType;
    if (ImGui::Combo("Type", &t, names, 3))
        lightType = (LightType)t;

    ImGui::Separator();

    switch (lightType)
    {
    case LightType::DIRECTIONAL:
        ImGui::DragFloat3("Direction", &directionalData.direction.x, 0.01f);
        ImGui::ColorEdit3("Ambient", &directionalData.ambient.r);
        ImGui::ColorEdit3("Diffuse", &directionalData.diffuse.r);
        ImGui::ColorEdit3("Specular", &directionalData.specular.r);
        break;

    case LightType::POINT:
        ImGui::ColorEdit3("Ambient", &pointData.ambient.r);
        ImGui::ColorEdit3("Diffuse", &pointData.diffuse.r);
        ImGui::ColorEdit3("Specular", &pointData.specular.r);
        ImGui::DragFloat("Constant", &pointData.constant, 0.001f, 0.001f, 10.0f);
        ImGui::DragFloat("Linear", &pointData.linear, 0.001f, 0.0f, 10.0f);
        ImGui::DragFloat("Quadratic", &pointData.quadratic, 0.001f, 0.0f, 10.0f);
        break;

    case LightType::SPOT:
        ImGui::DragFloat3("Direction", &spotData.direction.x, 0.01f);
        ImGui::ColorEdit3("Ambient", &spotData.ambient.r);
        ImGui::ColorEdit3("Diffuse", &spotData.diffuse.r);
        ImGui::ColorEdit3("Specular", &spotData.specular.r);
        ImGui::SliderFloat("CutOff", &spotData.cutOff, 0.0f, 90.0f, "%.1f deg");
        ImGui::SliderFloat("Outer CutOff", &spotData.outerCutOff, 0.0f, 90.0f, "%.1f deg");
        ImGui::DragFloat("Constant", &spotData.constant, 0.001f, 0.001f, 10.0f);
        ImGui::DragFloat("Linear", &spotData.linear, 0.001f, 0.0f, 10.0f);
        ImGui::DragFloat("Quadratic", &spotData.quadratic, 0.001f, 0.0f, 10.0f);
        break;
    }
}

void ComponentLight::Serialize(nlohmann::json& obj) const
{
    obj["lightType"] = (int)lightType;

    obj["dir"]["direction"] = { directionalData.direction.x, directionalData.direction.y, directionalData.direction.z };
    obj["dir"]["ambient"] = { directionalData.ambient.r,   directionalData.ambient.g,   directionalData.ambient.b };
    obj["dir"]["diffuse"] = { directionalData.diffuse.r,   directionalData.diffuse.g,   directionalData.diffuse.b };
    obj["dir"]["specular"] = { directionalData.specular.r,  directionalData.specular.g,  directionalData.specular.b };

    obj["point"]["position"] = { pointData.position.x, pointData.position.y, pointData.position.z };
    obj["point"]["ambient"] = { pointData.ambient.r,  pointData.ambient.g,  pointData.ambient.b };
    obj["point"]["diffuse"] = { pointData.diffuse.r,  pointData.diffuse.g,  pointData.diffuse.b };
    obj["point"]["specular"] = { pointData.specular.r, pointData.specular.g, pointData.specular.b };
    obj["point"]["constant"] = pointData.constant;
    obj["point"]["linear"] = pointData.linear;
    obj["point"]["quadratic"] = pointData.quadratic;

    obj["spot"]["position"] = { spotData.position.x,  spotData.position.y,  spotData.position.z };
    obj["spot"]["direction"] = { spotData.direction.x, spotData.direction.y, spotData.direction.z };
    obj["spot"]["ambient"] = { spotData.ambient.r,   spotData.ambient.g,   spotData.ambient.b };
    obj["spot"]["diffuse"] = { spotData.diffuse.r,   spotData.diffuse.g,   spotData.diffuse.b };
    obj["spot"]["specular"] = { spotData.specular.r,  spotData.specular.g,  spotData.specular.b };
    obj["spot"]["cutOff"] = spotData.cutOff;
    obj["spot"]["outerCutOff"] = spotData.outerCutOff;
    obj["spot"]["constant"] = spotData.constant;
    obj["spot"]["linear"] = spotData.linear;
    obj["spot"]["quadratic"] = spotData.quadratic;
}

void ComponentLight::Deserialize(const nlohmann::json& obj)
{
    lightType = (LightType)obj.value("lightType", 0);

    if (obj.contains("dir")) {
        auto& d = obj["dir"];
        directionalData.direction = { d["direction"][0], d["direction"][1], d["direction"][2] };
        directionalData.ambient = { d["ambient"][0],   d["ambient"][1],   d["ambient"][2] };
        directionalData.diffuse = { d["diffuse"][0],   d["diffuse"][1],   d["diffuse"][2] };
        directionalData.specular = { d["specular"][0],  d["specular"][1],  d["specular"][2] };
    }
    if (obj.contains("point")) {
        auto& p = obj["point"];
        pointData.position = { p["position"][0], p["position"][1], p["position"][2] };
        pointData.ambient = { p["ambient"][0],  p["ambient"][1],  p["ambient"][2] };
        pointData.diffuse = { p["diffuse"][0],  p["diffuse"][1],  p["diffuse"][2] };
        pointData.specular = { p["specular"][0], p["specular"][1], p["specular"][2] };
        pointData.constant = p.value("constant", 1.0f);
        pointData.linear = p.value("linear", 0.09f);
        pointData.quadratic = p.value("quadratic", 0.032f);
    }
    if (obj.contains("spot")) {
        auto& s = obj["spot"];
        spotData.position = { s["position"][0],  s["position"][1],  s["position"][2] };
        spotData.direction = { s["direction"][0], s["direction"][1], s["direction"][2] };
        spotData.ambient = { s["ambient"][0],   s["ambient"][1],   s["ambient"][2] };
        spotData.diffuse = { s["diffuse"][0],   s["diffuse"][1],   s["diffuse"][2] };
        spotData.specular = { s["specular"][0],  s["specular"][1],  s["specular"][2] };
        spotData.cutOff = s.value("cutOff", 12.5f);
        spotData.outerCutOff = s.value("outerCutOff", 17.5f);
        spotData.constant = s.value("constant", 1.0f);
        spotData.linear = s.value("linear", 0.09f);
        spotData.quadratic = s.value("quadratic", 0.032f);
    }
}