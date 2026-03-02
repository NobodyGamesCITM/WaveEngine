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
    if (ImGui::CollapsingHeader("Navigation & AI", ImGuiTreeNodeFlags_DefaultOpen))
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

            ImGui::Text("NavMesh Surface:");
            ImGui::SameLine();

            const char* surfaceName = linkedSurface ?
                linkedSurface->GetName().c_str() :
                "None (Drag Surface Here)";

            ImGui::Button(surfaceName, ImVec2(-1, 25));

            // --- Drag Target ---
            if (ImGui::BeginDragDropTarget())
            {
                if (const ImGuiPayload* payload =
                    ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT"))
                {
                    GameObject* dropped =
                        *(GameObject**)payload->Data;

                    if (dropped)
                    {
                        ComponentNavigation* nav =
                            (ComponentNavigation*)dropped->GetComponent(ComponentType::NAVIGATION);

                        if (nav && nav->type == NavType::SURFACE)
                        {
                            linkedSurface = dropped;
                            LOG_CONSOLE("Agent linked to surface: %s", dropped->GetName().c_str());
                        }
                        else
                        {
                            LOG_CONSOLE("Dropped object is not a NavMesh Surface!");
                        }
                    }
                }
                ImGui::EndDragDropTarget();
            }

            if (linkedSurface)
            {
                if (ImGui::Button("Clear Surface"))
                {
                    linkedSurface = nullptr;
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
}

bool ComponentNavigation::SetDestination(const glm::vec3& target)
{
    if (!linkedSurface) { LOG_CONSOLE("Sin superficie enlazada"); return false; }

    Transform* t = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
    glm::vec3 start = t->GetGlobalPosition();

    std::vector<glm::vec3> newPath;
    bool found = Application::GetInstance().navMesh->FindPath(linkedSurface, start, target, newPath);

    if (!found) { LOG_CONSOLE("No se encontró camino"); return false; }

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

    float extents[3] = { 2.f, 4.f, 2.f };
    float posF[3] = { position.x, position.y, position.z };

    dtPolyRef nearestRef;
    float nearestPt[3];
    dtStatus status = navData->navQuery->findNearestPoly(posF, extents, &filter, &nearestRef, nearestPt);

    if (dtStatusFailed(status) || nearestRef == 0) return false;

    // Snap solo la Y para no corregir X/Z bruscamente
    position.y = nearestPt[1];
    return true;
}

void ComponentNavigation::Update(float dt)
{
    if (type != NavType::AGENT || !moving || path.empty()) return;

    Transform* t = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
    glm::vec3 currentPos = t->GetGlobalPosition();
    glm::vec3 target = path[pathIndex];
    glm::vec3 dir = target - currentPos;

    // Ignorar diferencia en Y para calcular distancia horizontal
    glm::vec3 dirFlat = { dir.x, 0.0f, dir.z };
    float dist = glm::length(dirFlat);

    if (dist <= arrivalThreshold)
    {
        t->SetGlobalPosition(target);
        ++pathIndex;

        if (pathIndex >= (int)path.size())
        {
            moving = false;
            path.clear();
            pathIndex = 0;
        }
        return;
    }

    // Mover hacia el waypoint
    glm::vec3 step = (dir / glm::length(dir)) * moveSpeed * dt;
    glm::vec3 newPos = currentPos + step;

    // Anclar al navmesh — corrige la Y y valida que sigue en superficie
    if (!SnapPositionToNavMesh(newPos))
    {
        // Si sale del navmesh, no mover
        LOG_CONSOLE("Agente fuera del navmesh, movimiento bloqueado.");
        moving = false;
        return;
    }

    t->SetGlobalPosition(newPos);
}

void ComponentNavigation::StopMovement()
{
    moving = false; path.clear(); pathIndex = 0;
}