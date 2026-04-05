#pragma once

#include "NavMeshManager.h"
#include "ComponentNavigation.h"
#include "Application.h"
#include "imgui.h"
#include "GameObject.h"

ComponentNavigation::ComponentNavigation(GameObject* owner)
    : Component(owner, ComponentType::NAVIGATION)
{
}

void ComponentNavigation::OnEditor()
{

    ImGui::Checkbox("Navigation Static", &isStatic);

    //Select Type
    const char* items[] = { "Surface", "Agent", "Obstacle" };

    int currentType = static_cast<int>(type);
    if (ImGui::Combo("Nav Type", &currentType, items, IM_ARRAYSIZE(items)))
    {
        type = static_cast<NavType>(currentType);
    }

    ImGui::Spacing();

    if (type == NavType::SURFACE)
    {
        ImGui::Text("Surface Settings");
        ImGui::SliderFloat("Max Slope Angle", &maxSlopeAngle, 0.0f, 90.0f);

        ImGui::Separator();
        ImGui::Text("--- TEST NAVMESH ---");

        static float testStart[3] = { 0.0f, 0.0f,  0.0f };
        static float testEnd[3] = { 10.0f, 0.0f, 10.0f };

        ImGui::DragFloat3("Start", testStart, 0.1f);
        ImGui::DragFloat3("End", testEnd, 0.1f);

        if (ImGui::Button("Test FindPath", ImVec2(-1, 25)))
        {
            glm::vec3 start = { testStart[0], testStart[1], testStart[2] };
            glm::vec3 end = { testEnd[0],   testEnd[1],   testEnd[2] };

            std::vector<glm::vec3> path;
            bool found = Application::GetInstance().navMesh->FindPath(owner, start, end, path);

            if (found)
            {
                LOG_CONSOLE("Camino encontrado! Waypoints: %d", (int)path.size());
                for (int i = 0; i < (int)path.size(); ++i)
                    LOG_CONSOLE("  [%d] (%.2f, %.2f, %.2f)", i, path[i].x, path[i].y, path[i].z);
            }
            else
            {
                LOG_CONSOLE("No se encontro camino. Comprueba que los puntos esten dentro del navmesh.");
            }
        }
    }

    if (type == NavType::AGENT)
    {
        ImGui::Text("Agent Settings");
        ImGui::Separator();

        // Recoger todos los GameObjects de la escena con NavType::SURFACE
        std::vector<GameObject*> surfaces;
        std::function<void(GameObject*)> collectSurfaces = [&](GameObject* obj)
            {
                if (!obj) return;
                ComponentNavigation* nav =
                    (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);
                if (nav && nav->type == NavType::SURFACE)
                    surfaces.push_back(obj);
                for (GameObject* child : obj->GetChildren())
                    collectSurfaces(child);
            };
        collectSurfaces(Application::GetInstance().scene->GetRoot());

        // Construir lista de nombres para el Combo
        std::vector<std::string> surfaceNames;
        surfaceNames.push_back("None");
        for (GameObject* s : surfaces)
            surfaceNames.push_back(s->GetName());

        // Índice actual
        int currentIndex = 0; // "None"
        for (int i = 0; i < (int)surfaces.size(); ++i)
        {
            if (surfaces[i] == linkedSurface)
            {
                currentIndex = i + 1; // +1 por el "None"
                break;
            }
        }

        // Convertir a array de const char* para ImGui
        std::vector<const char*> namePtrs;
        for (const auto& n : surfaceNames)
            namePtrs.push_back(n.c_str());

        ImGui::Text("NavMesh Surface:");
        if (ImGui::Combo("##NavSurface", &currentIndex, namePtrs.data(), (int)namePtrs.size()))
        {
            if (currentIndex == 0)
            {
                linkedSurface = nullptr;
                tempSurfaceUID = 0;
            }
            else
            {
                linkedSurface = surfaces[currentIndex - 1];
                tempSurfaceUID = linkedSurface->GetUID();
                LOG_CONSOLE("Agent linked to surface: %s", linkedSurface->GetName().c_str());
            }
        }
    }
    ImGui::Spacing();

    if (type != NavType::AGENT) {
        if (ImGui::Button("Bake NavMesh", ImVec2(-1, 30)))
        {
            Application::GetInstance().navMesh->Bake(this->owner);

        }

        ImGui::Spacing();

        if (ImGui::Button("Clear NavMesh", ImVec2(-1, 30)))
        {

            if (Application::GetInstance().navMesh)
            {
                Application::GetInstance().navMesh->RemoveNavMesh(owner);
            }


        }

    }
}


bool ComponentNavigation::SetDestination(const glm::vec3& target)
{
    if (!linkedSurface) { LOG_CONSOLE("Sin superficie enlazada"); return false; }

    Transform* t = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
    glm::vec3 start = t->GetGlobalPosition();

    std::vector<glm::vec3> newPath;
    bool found = false;

    if (linkedSurface &&
        Application::GetInstance().navMesh->FindPath(linkedSurface, start, target, newPath))
    {
        found = true;
    }
    else
    {
        std::function<void(GameObject*)> collect = [&](GameObject* obj)
            {
                if (!obj || found) return;

                ComponentNavigation* nav =
                    (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);

                if (nav && nav->type == NavType::SURFACE && obj != linkedSurface)
                {
                    if (Application::GetInstance().navMesh->FindPath(obj, start, target, newPath))
                    {
                        linkedSurface = obj;
                        found = true;
                        return;
                    }
                }

                for (GameObject* child : obj->GetChildren())
                    collect(child);
            };
        collect(Application::GetInstance().scene->GetRoot());
    }

    if (!found) return false;

    auto* navData = Application::GetInstance().navMesh->GetNavMeshData(linkedSurface);
    if (navData && navData->navQuery)
    {
        dtQueryFilter filter;
        filter.setIncludeFlags(0xFFFF);
        float extents[3] = { 5.f, 1.5f, 5.f }; // Y reducido para no coger polys de otro suelo
        float startF[3] = { start.x, start.y, start.z };
        float nearPt[3];
        navData->navQuery->findNearestPoly(startF, extents, &filter, &currentPolyRef, nearPt);
    }

    path = std::move(newPath);
    pathIndex = 0;
    moving = true;
    return true;
}

bool ComponentNavigation::SnapPositionToNavMesh(glm::vec3& position)
{
    if (!linkedSurface) return false;

    auto* navData = Application::GetInstance().navMesh->GetNavMeshData(linkedSurface);
    if (!navData || !navData->navQuery) return false;

    dtQueryFilter filter;
    filter.setIncludeFlags(0xFFFF);

    float extents[3] = { 2.f, 1.5f, 2.f };
    float posF[3] = { position.x, position.y, position.z };

    dtPolyRef nearestRef;
    float nearestPt[3];
    dtStatus status = navData->navQuery->findNearestPoly(posF, extents, &filter, &nearestRef, nearestPt);

    if (dtStatusFailed(status) || nearestRef == 0) return false;

    // Snap solo la Y para no corregir X/Z bruscamente
    position.y = nearestPt[1];
    return true;
}


// 3. En Update � reemplazar el bloque de movimiento libre por moveAlongSurface
void ComponentNavigation::Update(float dt)
{

}

// 2. En StopMovement � resetear el poly ref

void ComponentNavigation::StopMovement()
{
    moving = false;
    path.clear();
    pathIndex = 0;
    currentPolyRef = 0;
}

void ComponentNavigation::Serialize(nlohmann::json& componentObj) const {
    componentObj["NavType"] = static_cast<int>(type);
    componentObj["IsStatic"] = isStatic;
    componentObj["MaxSlope"] = maxSlopeAngle;
    componentObj["MoveSpeed"] = moveSpeed;
    componentObj["ArrivalThreshold"] = arrivalThreshold;

    if (linkedSurface) {
        componentObj["LinkedSurfaceUID"] = linkedSurface->GetUID();
    }
}

void ComponentNavigation::Deserialize(const nlohmann::json& componentObj) {
    if (componentObj.contains("NavType"))
        type = static_cast<NavType>(componentObj["NavType"]);

    if (componentObj.contains("IsStatic"))
        isStatic = componentObj["IsStatic"];

    if (componentObj.contains("MaxSlope"))
        maxSlopeAngle = componentObj["MaxSlope"];

    if (componentObj.contains("MoveSpeed"))
        moveSpeed = componentObj["MoveSpeed"];

    if (componentObj.contains("ArrivalThreshold"))
        arrivalThreshold = componentObj["ArrivalThreshold"];

    if (componentObj.contains("LinkedSurfaceUID")) {
        this->tempSurfaceUID = componentObj["LinkedSurfaceUID"];
    }
}

void ComponentNavigation::SolveReferences() {
    if (tempSurfaceUID != 0) {
        this->linkedSurface = Application::GetInstance().scene->FindObject(this->tempSurfaceUID);
        this->tempSurfaceUID = 0;
    }
}

void ComponentNavigation::GetMoveDirection(float threshold, float& dx, float& dz)
{
    dx = 0.0f;
    dz = 0.0f;

    if (type != NavType::AGENT) return;
    if (!moving) return;
    if (path.empty()) return;

    Transform* t = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
    glm::vec3 currentPos = t->GetGlobalPosition();

    glm::vec3 target = path[pathIndex];
    glm::vec3 dir = target - currentPos;

    glm::vec3 dirFlat = { dir.x, 0.0f, dir.z };
    float dist = glm::length(dirFlat);

    if (dist <= threshold)
    {
        pathIndex++;

        if (pathIndex >= (int)path.size())
        {
            moving = false;
            path.clear();
            pathIndex = 0;
            return;
        }

        target = path[pathIndex];
        dir = target - currentPos;
    }

    dirFlat = glm::normalize(glm::vec3(dir.x, 0.0f, dir.z));

    dx = dirFlat.x;
    dz = dirFlat.z;
}

bool ComponentNavigation::GetRandomPoint(float& x, float& y, float& z)
{
    // Si no tenemos superficie vinculada, busca la más cercana primero
    if (!linkedSurface) {
        // Intenta vincular buscando en todas las superficies
        glm::vec3 dummy;
        Transform* t = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
        glm::vec3 pos = t->GetGlobalPosition();
        std::vector<glm::vec3> tmp;
        std::function<void(GameObject*)> collect = [&](GameObject* obj) {
            if (!obj) return;
            ComponentNavigation* nav = (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);
            if (nav && nav->type == NavType::SURFACE)
                if (Application::GetInstance().navMesh->FindPath(obj, pos, pos, tmp))
                    linkedSurface = obj;
            for (auto* c : obj->GetChildren()) collect(c);
            };
        collect(Application::GetInstance().scene->GetRoot());
    }
    if (!linkedSurface) return false;

    glm::vec3 pt;
    if (!Application::GetInstance().navMesh->GetRandomPoint(linkedSurface, pt)) return false;
    x = pt.x; y = pt.y; z = pt.z;
    return true;
}