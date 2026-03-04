#include "Collider.h"
#include "Rigidbody.h"
#include "Application.h"
#include "ModulePhysics.h"
#include "GameObject.h"
#include "Transform.h"
#include "imgui.h"
#include "glm/glm.hpp"

Collider::Collider(GameObject* owner) : Component(owner, ComponentType::COLLIDER)
{
    name = "Collider";
    Application::GetInstance().physics->RegisterCollider(this);
    Rigidbody* rb = (Rigidbody*)owner->GetComponentInParent(ComponentType::RIGIDBODY);
    if (rb) rb->CreateBody();
}

Collider::~Collider()
{
    Application::GetInstance().physics->UnregisterCollider(this);
    if (attachedRigidbody) attachedRigidbody->UnattachCollider(this);
}


void Collider::Enable() 
{
    if (attachedRigidbody) {
        attachedRigidbody->CreateBody();
    }
    else {
        Rigidbody* rb = (Rigidbody*)owner->GetComponentInParent(ComponentType::RIGIDBODY);
        if (rb) rb->CreateBody();
    }
}

void Collider::Disable() 
{
    if (attachedRigidbody) attachedRigidbody->UnattachCollider(this);
}


void Collider::SerializeBase(nlohmann::json& componentObj) const
{
    // Guardamos el centro como un array [x, y, z]
    componentObj["Center"] = { center.x, center.y, center.z };
    componentObj["Trigger"] = isTrigger;
    componentObj["DynamicFriction"] = dynamicFriction;
    componentObj["StaticFriction"] = staticFriction;
    componentObj["Restitution"] = restitution;
}

void Collider::DeserializeBase(const nlohmann::json& componentObj)
{
    if (componentObj.contains("Center")) {
        auto c = componentObj["Center"];
        center = glm::vec3(c[0], c[1], c[2]);
    }

    isTrigger = componentObj.value("Trigger", false);
    dynamicFriction = componentObj.value("DynamicFriction", 0.5f);
    staticFriction = componentObj.value("StaticFriction", 0.5f);
    restitution = componentObj.value("Restitution", 0.0f);
}

void Collider::OnEditorBase()
{
    #ifndef WAVE_GAME
    //ATRIBUTES
    ImGui::PushID(this);

    ImGui::Checkbox("##ShowDebug", &showDebug);
    ImGui::SameLine();
    ImGui::Text("Show Debug");
    ImGui::SameLine();

    static bool showAll = false;
    if (ImGui::Checkbox("##ShowAll", &showAll))
    {
        Application::GetInstance().physics->SetDebugAll(showAll);
    }
    ImGui::SameLine();
    ImGui::Text("Show All");
    ImGui::Separator();

    ImGui::Text("Trigger");
    bool trigger = isTrigger;
    if (ImGui::Checkbox("##Trigger", &trigger))
    {
        SetTrigger(trigger);
    }

    ImGui::Text("Center");
    glm::vec3 center = this->center;
    if (ImGui::InputFloat3("##Center", &center.x))
    {
        SetCenter(center);
    }

    ImGui::Text("Static Friction");
    float sF = staticFriction;
    if (ImGui::InputFloat("##Static Friction", &sF))
    {
        SetStaticFriction(sF);
    }

    ImGui::Text("Dynamic Friction");
    float dF = dynamicFriction;
    if (ImGui::InputFloat("##Dynamic Friction", &dF))
    {
        SetDynamicFriction(dF);
    }

    ImGui::Text("Restitution");
    float restitution = this->restitution;
    if (ImGui::InputFloat("##Restitution", &restitution))
    {
        SetRestitution(restitution);
    }

    ImGui::PopID();
    #endif
}

void Collider::SetCenter(glm::vec3 center)
{
    this->center = center;
    if (attachedRigidbody) attachedRigidbody->UpdateShapeProperties(this);
}

void Collider::SetTrigger(bool trigger)
{
    isTrigger = trigger;
    if (attachedRigidbody) attachedRigidbody->UpdateShapeProperties(this);
}

void Collider::SetStaticFriction(float staticFriction)
{
    this->staticFriction = glm::clamp(staticFriction, 0.0f, INFINITY);
    if (attachedRigidbody) attachedRigidbody->UpdateShapeProperties(this);
}

void Collider::SetDynamicFriction(float dynamicFriction)
{
    this->dynamicFriction = glm::clamp(dynamicFriction, 0.0f, INFINITY);
    if (attachedRigidbody) attachedRigidbody->UpdateShapeProperties(this);
}
void Collider::SetRestitution(float restitution)
{
    this->restitution = glm::clamp(restitution, 0.0f, INFINITY);
    if (attachedRigidbody) attachedRigidbody->UpdateShapeProperties(this);
}

void Collider::OnGameObjectEvent(GameObjectEvent event, Component* component) 
{
    switch (event)
    {
    case GameObjectEvent::HIERARCHY_CHANGED:
        
        Rigidbody* newRB = (Rigidbody*)owner->GetComponentInParent(ComponentType::RIGIDBODY);

        if (newRB != attachedRigidbody)
        {
            if (attachedRigidbody) {
                attachedRigidbody->CreateBody();
            }

            attachedRigidbody = newRB;

            if (attachedRigidbody) {
                attachedRigidbody->CreateBody();
            }
            else {
               
            }
        }
        else if (attachedRigidbody)
        {
            attachedRigidbody->CreateBody();
        }
        break;
    }
}

//void Collider::Serialize(nlohmann::json& componentObj) const
//{
//    componentObj["center"] = { center.x, center.y, center.z };
//    componentObj["isTrigger"] = isTrigger;
//    componentObj["staticFriction"] = staticFriction;
//    componentObj["dynamicFriction"] = dynamicFriction;
//    componentObj["restitution"] = restitution;
//}
//
//void Collider::Deserialize(const nlohmann::json& componentObj)
//{
//    if (componentObj.contains("center")) {
//        const auto& c = componentObj["center"];
//        SetCenter(glm::vec3(c[0].get<float>(), c[1].get<float>(), c[2].get<float>()));
//    }
//    if (componentObj.contains("isTrigger"))
//        SetTrigger(componentObj["isTrigger"].get<bool>());
//    if (componentObj.contains("staticFriction"))
//        SetStaticFriction(componentObj["staticFriction"].get<float>());
//    if (componentObj.contains("dynamicFriction"))
//        SetDynamicFriction(componentObj["dynamicFriction"].get<float>());
//    if (componentObj.contains("restitution"))
//        SetRestitution(componentObj["restitution"].get<float>());
//}

void Collider::SafeDebugDraw()
{
    if (!owner) return;
    if (!Application::GetInstance().scene->FindObject(owner->GetUID())) return;
    if (!owner->transform) return;
    DebugShape();
}