#include "Application.h"
#include "ModuleScene.h"
#include "GameObject.h"
#include "ComponentMesh.h"
#include "Transform.h"
#include "Log.h"
#include "NavMeshManager.h"
#include "ComponentNavigation.h"
#include <cstdlib>
#include <functional>

#include "DetourNavMesh.h"
#include "DetourNavMeshBuilder.h"
#include "DetourNavMeshQuery.h"


static float NavRand() { return static_cast<float>(rand()) / static_cast<float>(RAND_MAX); }


ModuleNavMesh::ModuleNavMesh() : Module() {
    name = "ModuleNavMesh";
    baked = false;
}

ModuleNavMesh::~ModuleNavMesh() {
    CleanUp();
}

bool ModuleNavMesh::Start() {
    LOG_CONSOLE("NavMesh Manager Started");
    return true;
}

bool ModuleNavMesh::Update() {

    Application::PlayState currentState = Application::GetInstance().GetPlayState();

    if (currentState == Application::PlayState::PLAYING && !baked) {
        GameObject* root = Application::GetInstance().scene->GetRoot();
        if (root) {
            Bake(root);
            baked = true;
        }
    }

    if (currentState == Application::PlayState::EDITING && baked) {
        baked = false;
    }

    DrawDebug();
    return true;
}

// ---------------------------------------------------------------------------
// RecollectGeometry
// ---------------------------------------------------------------------------
// When isTopLevel is false and the object has its own NavType::SURFACE
// component, the recursion stops – that surface is baked as its own entity.
// ---------------------------------------------------------------------------
void ModuleNavMesh::RecollectGeometry(GameObject* obj,
    std::vector<float>& vertices,
    std::vector<int>& indices,
    bool isTopLevel)
{
    if (obj == nullptr || !obj->IsActive()) return;

    // If this is NOT the root surface being collected and it owns a SURFACE
    // component, skip it entirely (it will be collected separately).
    if (!isTopLevel)
    {
        ComponentNavigation* nav =
            (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);
        if (nav && nav->type == NavType::SURFACE) return;
    }

    ComponentMesh* mesh = (ComponentMesh*)obj->GetComponent(ComponentType::MESH);
    if (mesh) {
        LOG_CONSOLE("Checking mesh for object: %s, HasMesh: %d, Vertices: %d, Indices: %d",
            obj->GetName().c_str(),
            mesh->HasMesh(),
            (int)mesh->GetMesh().vertices.size(),
            (int)mesh->GetMesh().indices.size());
        if (mesh->HasMesh())
            ExtractVertices(mesh, vertices, indices);
    }

    for (GameObject* child : obj->GetChildren())
        RecollectGeometry(child, vertices, indices, false);  // children are never top-level
}

void ModuleNavMesh::ExtractVertices(ComponentMesh* mesh,
    std::vector<float>& vertices,
    std::vector<int>& indices)
{
    if (mesh == nullptr || !mesh->HasMesh()) return;

    const Mesh& meshData = mesh->GetMesh();
    GameObject* owner = mesh->owner;
    if (!owner) return;

    Transform* trans = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
    if (!trans) return;

    glm::mat4 globalMat = trans->GetGlobalMatrix();

    int vertexOffset = (int)vertices.size() / 3;

    for (const auto& vertex : meshData.vertices)
    {
        glm::vec4 worldPos = globalMat *
            glm::vec4(vertex.position.x, vertex.position.y, vertex.position.z, 1.0f);
        vertices.push_back(worldPos.x);
        vertices.push_back(worldPos.y);
        vertices.push_back(worldPos.z);
    }

    for (unsigned int idx : meshData.indices)
        indices.push_back(vertexOffset + (int)idx);
}

// ---------------------------------------------------------------------------
// Bake  –  bakes every Surface in the scene, merging touching ones.
// ---------------------------------------------------------------------------
void ModuleNavMesh::Bake(GameObject* /*triggerObj*/)
{
    // ── 1. Collect ALL active Surface objects from the whole scene ──────────
    std::vector<GameObject*> allSurfaces;
    std::function<void(GameObject*)> collectSurfaces = [&](GameObject* obj)
        {
            if (!obj || !obj->IsActive()) return;
            ComponentNavigation* nav =
                (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);
            if (nav && nav->type == NavType::SURFACE)
                allSurfaces.push_back(obj);
            for (auto* child : obj->GetChildren())
                collectSurfaces(child);
        };
    collectSurfaces(Application::GetInstance().scene->GetRoot());

    if (allSurfaces.empty())
    {
        LOG_CONSOLE("NavMesh Error: No objects with NavType::SURFACE found in the scene.");
        return;
    }

    LOG_CONSOLE("NavMesh: Found %d Surface object(s). Baking all...", (int)allSurfaces.size());

    // ── 2. Remove every existing NavMesh that belongs to any of these surfaces
    //       (checking both owner and members so merged groups are fully cleared)
    for (auto it = navMeshes.begin(); it != navMeshes.end(); )
    {
        bool belongs = false;
        for (auto* s : allSurfaces)
        {
            if (it->owner == s) { belongs = true; break; }
            for (auto* m : it->members)
                if (m == s) { belongs = true; break; }
        }

        if (belongs)
        {
            if (it->heightfield) rcFreeHeightField(it->heightfield);
            if (it->navMesh)     dtFreeNavMesh(it->navMesh);
            if (it->navQuery)    dtFreeNavMeshQuery(it->navQuery);
            if (it->chf)         rcFreeCompactHeightfield(it->chf);
            it = navMeshes.erase(it);
        }
        else ++it;
    }

    // ── 3. Collect obstacles ─────────────────────────────────────────────────
    navObstacles.clear();
    RecollectObstacles(Application::GetInstance().scene->GetRoot());

    // ── 4. Gather geometry and world-space AABB per surface individually ─────
    struct SurfaceInfo
    {
        GameObject* obj = nullptr;
        std::vector<float> verts;
        std::vector<int>   indices;
        float              bmin[3] = {};
        float              bmax[3] = {};
        bool               hasGeometry = false;
    };

    int n = (int)allSurfaces.size();
    std::vector<SurfaceInfo> infos(n);

    for (int i = 0; i < n; ++i)
    {
        infos[i].obj = allSurfaces[i];
        // Collect geometry only for this surface (RecollectGeometry stops
        // recursing into children that are themselves Surface objects).
        RecollectGeometry(allSurfaces[i], infos[i].verts, infos[i].indices, true);

        if (!infos[i].verts.empty())
        {
            CalculateAABB(infos[i].verts, infos[i].bmin, infos[i].bmax);
            infos[i].hasGeometry = true;
        }
        else
        {
            LOG_CONSOLE("NavMesh Warning: Surface '%s' has no geometry, skipping.",
                allSurfaces[i]->GetName().c_str());
        }
    }

    // ── 5. Group surfaces whose AABBs touch or overlap (BFS) ─────────────────
    // Two surfaces are considered "touching" when their AABBs overlap or are
    // within contactEpsilon units of each other on every axis.
    const float contactEpsilon = 0.05f;

    auto touches = [&](int a, int b) -> bool
        {
            if (!infos[a].hasGeometry || !infos[b].hasGeometry) return false;
            for (int k = 0; k < 3; ++k)
            {
                if (infos[a].bmax[k] + contactEpsilon < infos[b].bmin[k]) return false;
                if (infos[b].bmax[k] + contactEpsilon < infos[a].bmin[k]) return false;
            }
            return true;
        };

    std::vector<int> groupId(n, -1);
    int numGroups = 0;

    for (int i = 0; i < n; ++i)
    {
        if (groupId[i] != -1) continue;

        groupId[i] = numGroups;
        // BFS to propagate the group label to all connected surfaces.
        std::vector<int> frontier = { i };
        while (!frontier.empty())
        {
            std::vector<int> next;
            for (int cur : frontier)
                for (int j = 0; j < n; ++j)
                    if (groupId[j] == -1 && touches(cur, j))
                    {
                        groupId[j] = numGroups;
                        next.push_back(j);
                    }
            frontier = std::move(next);
        }
        ++numGroups;
    }

    // ── 6. Bake each group ───────────────────────────────────────────────────
    for (int g = 0; g < numGroups; ++g)
    {
        std::vector<float>        mergedVerts;
        std::vector<int>          mergedIndices;
        GameObject* primary = nullptr;
        std::vector<GameObject*>  members;
        float                     slopeAngle = 45.0f;

        for (int i = 0; i < n; ++i)
        {
            if (groupId[i] != g || !infos[i].hasGeometry) continue;

            if (!primary)
            {
                primary = allSurfaces[i];
                ComponentNavigation* nav =
                    (ComponentNavigation*)primary->GetComponent(ComponentType::NAVIGATION);
                if (nav) slopeAngle = nav->maxSlopeAngle;
            }
            else
            {
                members.push_back(allSurfaces[i]);
            }

            // Merge geometry: offset indices by the current vertex count.
            int vertOffset = (int)mergedVerts.size() / 3;
            mergedVerts.insert(mergedVerts.end(),
                infos[i].verts.begin(), infos[i].verts.end());
            for (int idx : infos[i].indices)
                mergedIndices.push_back(vertOffset + idx);
        }

        if (!primary || mergedVerts.empty()) continue;

        if (!members.empty())
        {
            LOG_CONSOLE("NavMesh: Merging %d touching surface(s) into group (primary: '%s')",
                (int)members.size() + 1, primary->GetName().c_str());
            for (auto* m : members)
                LOG_CONSOLE("  + merged: '%s'", m->GetName().c_str());
        }
        else
        {
            LOG_CONSOLE("NavMesh: Baking standalone surface '%s'", primary->GetName().c_str());
        }

        BakeSurfaceGroup(primary, members, mergedVerts, mergedIndices, slopeAngle);
    }
}

// ---------------------------------------------------------------------------
// BakeSurfaceGroup  –  core Recast/Detour pipeline for one group.
// ---------------------------------------------------------------------------
void ModuleNavMesh::BakeSurfaceGroup(GameObject* surface,
    const std::vector<GameObject*>& groupMembers,
    const std::vector<float>& allVertices,
    const std::vector<int>& allIndices,
    float                           slopeAngle)
{
    float bmin[3], bmax[3];
    CalculateAABB(allVertices, bmin, bmax);

    rcConfig cfg = CreateDefaultConfig(bmin, bmax);
    cfg.walkableSlopeAngle = slopeAngle;

    rcContext ctx;

    rcHeightfield* hf = rcAllocHeightfield();
    if (!rcCreateHeightfield(&ctx, *hf, cfg.width, cfg.height,
        cfg.bmin, cfg.bmax, cfg.cs, cfg.ch))
    {
        LOG_CONSOLE("NavMesh Error: Could not create heightfield for '%s'.",
            surface->GetName().c_str());
        rcFreeHeightField(hf);
        return;
    }

    int nVerts = (int)allVertices.size() / 3;
    int nTris = (int)allIndices.size() / 3;

    std::vector<unsigned char> areas(nTris, RC_WALKABLE_AREA);
    rcRasterizeTriangles(&ctx, allVertices.data(), nVerts,
        allIndices.data(), areas.data(), nTris,
        *hf, cfg.walkableClimb);

    rcFilterLowHangingWalkableObstacles(&ctx, cfg.walkableClimb, *hf);
    rcFilterLedgeSpans(&ctx, cfg.walkableHeight, cfg.walkableClimb, *hf);
    rcFilterWalkableLowHeightSpans(&ctx, cfg.walkableHeight, *hf);

    rcCompactHeightfield* chf = rcAllocCompactHeightfield();
    if (!rcBuildCompactHeightfield(&ctx, cfg.walkableHeight, cfg.walkableClimb, *hf, *chf))
    {
        LOG_CONSOLE("NavMesh Error: compact heightfield for '%s'.",
            surface->GetName().c_str());
        rcFreeHeightField(hf);
        rcFreeCompactHeightfield(chf);
        return;
    }

    // ── Mark obstacles as RC_NULL_AREA ───────────────────────────────────────
    for (GameObject* obs : navObstacles)
    {
        if (!obs || !obs->IsActive()) continue;

        ComponentMesh* meshComp =
            static_cast<ComponentMesh*>(obs->GetComponent(ComponentType::MESH));
        if (!meshComp || !meshComp->HasMesh()) continue;

        const AABB& aabb = meshComp->GetGlobalAABB();
        float obsMin[3] = { aabb.min.x, aabb.min.y, aabb.min.z };
        float obsMax[3] = { aabb.max.x, aabb.max.y, aabb.max.z };

        rcMarkBoxArea(&ctx, obsMin, obsMax, RC_NULL_AREA, *chf);
        LOG_CONSOLE("NavMesh: Obstacle baked -> %s", obs->GetName().c_str());
    }

    rcErodeWalkableArea(&ctx, cfg.walkableRadius, *chf);
    rcBuildDistanceField(&ctx, *chf);
    rcBuildRegions(&ctx, *chf, 0, cfg.minRegionArea, cfg.mergeRegionArea);

    rcContourSet* cset = rcAllocContourSet();
    rcBuildContours(&ctx, *chf, cfg.maxSimplificationError, cfg.maxEdgeLen, *cset);

    rcPolyMesh* pmesh = rcAllocPolyMesh();
    rcBuildPolyMesh(&ctx, *cset, cfg.maxVertsPerPoly, *pmesh);

    rcPolyMeshDetail* dmesh = rcAllocPolyMeshDetail();
    rcBuildPolyMeshDetail(&ctx, *pmesh, *chf, sampleDist, sampleMaxError, *dmesh);

    for (int i = 0; i < pmesh->npolys; ++i)
        pmesh->flags[i] = (pmesh->areas[i] == RC_WALKABLE_AREA) ? 1 : 0;

    LOG_CONSOLE("AABB: min=(%.1f,%.1f,%.1f) max=(%.1f,%.1f,%.1f)",
        bmin[0], bmin[1], bmin[2], bmax[0], bmax[1], bmax[2]);
    LOG_CONSOLE("NavMesh stats: polys=%d, verts=%d", pmesh->npolys, pmesh->nverts);

    dtNavMeshCreateParams params;
    memset(&params, 0, sizeof(params));
    params.verts = pmesh->verts;
    params.vertCount = pmesh->nverts;
    params.polys = pmesh->polys;
    params.polyAreas = pmesh->areas;
    params.polyFlags = pmesh->flags;
    params.polyCount = pmesh->npolys;
    params.nvp = pmesh->nvp;
    params.detailMeshes = dmesh->meshes;
    params.detailVerts = dmesh->verts;
    params.detailVertsCount = dmesh->nverts;
    params.detailTris = dmesh->tris;
    params.detailTriCount = dmesh->ntris;
    params.walkableHeight = cfg.walkableHeight * cfg.ch;
    params.walkableRadius = cfg.walkableRadius * cfg.cs;
    params.walkableClimb = cfg.walkableClimb * cfg.ch;
    memcpy(params.bmin, pmesh->bmin, sizeof(params.bmin));
    memcpy(params.bmax, pmesh->bmax, sizeof(params.bmax));
    params.cs = cfg.cs;
    params.ch = cfg.ch;
    params.buildBvTree = true;

    unsigned char* navData = nullptr;
    int            navDataSize = 0;
    dtCreateNavMeshData(&params, &navData, &navDataSize);

    rcFreeContourSet(cset);
    rcFreePolyMesh(pmesh);
    rcFreePolyMeshDetail(dmesh);

    if (navData == nullptr || navDataSize == 0)
    {
        LOG_CONSOLE("NavMesh Error: dtCreateNavMeshData failed for '%s'.",
            surface->GetName().c_str());
        rcFreeHeightField(hf);
        rcFreeCompactHeightfield(chf);
        return;
    }

    dtNavMesh* navMesh = dtAllocNavMesh();
    navMesh->init(navData, navDataSize, DT_TILE_FREE_DATA);

    dtNavMeshQuery* navQuery = dtAllocNavMeshQuery();
    navQuery->init(navMesh, 2048);

    NavMeshData meshData;
    meshData.heightfield = hf;
    meshData.chf = chf;
    meshData.navMesh = navMesh;
    meshData.navQuery = navQuery;
    meshData.owner = surface;
    meshData.members = groupMembers;   // ← store merged surfaces
    meshData.tileRef = navMesh->getTileRefAt(0, 0, 0);

    if (meshData.tileRef == 0)
        LOG_CONSOLE("NavMesh Warning: tileRef is 0 for '%s'!", surface->GetName().c_str());

    navMeshes.push_back(meshData);

    LOG_CONSOLE("NavMesh Bake OK: '%s'. Verts: %d  Tris: %d  Members: %d",
        surface->GetName().c_str(), nVerts, nTris, (int)groupMembers.size());
}

// ---------------------------------------------------------------------------
// CalculateAABB / CreateDefaultConfig
// ---------------------------------------------------------------------------
void ModuleNavMesh::CalculateAABB(const std::vector<float>& verts,
    float* minBounds, float* maxBounds)
{
    minBounds[0] = maxBounds[0] = verts[0];
    minBounds[1] = maxBounds[1] = verts[1];
    minBounds[2] = maxBounds[2] = verts[2];

    for (size_t i = 3; i < verts.size(); i += 3) {
        rcVmin(minBounds, &verts[i]);
        rcVmax(maxBounds, &verts[i]);
    }
}

rcConfig ModuleNavMesh::CreateDefaultConfig(const float* minBounds, const float* maxBounds)
{
    rcConfig cfg;
    memset(&cfg, 0, sizeof(cfg));

    cfg.cs = 0.3f;
    cfg.ch = 0.2f;
    cfg.walkableSlopeAngle = 45.0f;
    cfg.walkableHeight = 10;
    cfg.walkableClimb = 2;
    cfg.walkableRadius = 3;
    cfg.maxEdgeLen = 12;
    cfg.maxSimplificationError = 1.3f;
    cfg.minRegionArea = 8;
    cfg.mergeRegionArea = 20;
    cfg.maxVertsPerPoly = 6;
    cfg.detailSampleDist = cfg.cs * sampleDist;
    cfg.detailSampleMaxError = cfg.ch * sampleMaxError;

    rcVcopy(cfg.bmin, minBounds);
    rcVcopy(cfg.bmax, maxBounds);
    rcCalcGridSize(cfg.bmin, cfg.bmax, cfg.cs, &cfg.width, &cfg.height);

    return cfg;
}

// ---------------------------------------------------------------------------
// DrawDebug
// ---------------------------------------------------------------------------
void ModuleNavMesh::DrawDebug()
{
    glm::vec4 colorWalkable = { 0.0f, 0.75f, 1.0f, 1.0f };
    glm::vec4 colorEdge = { 0.0f, 0.4f,  0.9f, 1.0f };

    for (auto& meshData : navMeshes)
    {
        if (!meshData.navMesh || meshData.tileRef == 0) continue;

        const dtMeshTile* tile = meshData.navMesh->getTileByRef(meshData.tileRef);
        if (!tile || !tile->header) continue;

        for (int p = 0; p < tile->header->polyCount; ++p)
        {
            const dtPoly* poly = &tile->polys[p];
            if (poly->getType() != DT_POLYTYPE_GROUND) continue;

            const dtPolyDetail* detail = &tile->detailMeshes[p];

            for (int t = 0; t < detail->triCount; ++t)
            {
                const unsigned char* tri =
                    &tile->detailTris[(detail->triBase + t) * 4];

                glm::vec3 v[3];
                for (int k = 0; k < 3; ++k)
                {
                    if (tri[k] < poly->vertCount)
                    {
                        const float* vert = &tile->verts[poly->verts[tri[k]] * 3];
                        v[k] = { vert[0], vert[1], vert[2] };
                    }
                    else
                    {
                        const float* vert =
                            &tile->detailVerts[
                                (detail->vertBase + tri[k] - poly->vertCount) * 3];
                        v[k] = { vert[0], vert[1], vert[2] };
                    }
                }

                v[0].y += 0.05f; v[1].y += 0.05f; v[2].y += 0.05f;

                Application::GetInstance().renderer->DrawLine(v[0], v[1], colorWalkable);
                Application::GetInstance().renderer->DrawLine(v[1], v[2], colorWalkable);
                Application::GetInstance().renderer->DrawLine(v[2], v[0], colorWalkable);
            }

            for (int e = 0; e < (int)poly->vertCount; ++e)
            {
                if (poly->neis[e] != 0) continue;

                const float* va = &tile->verts[poly->verts[e] * 3];
                const float* vb = &tile->verts[poly->verts[(e + 1) % poly->vertCount] * 3];

                Application::GetInstance().renderer->DrawLine(
                    { va[0], va[1] + 0.05f, va[2] },
                    { vb[0], vb[1] + 0.05f, vb[2] },
                    colorEdge);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// RecollectObstacles
// ---------------------------------------------------------------------------
void ModuleNavMesh::RecollectObstacles(GameObject* obj)
{
    if (!obj || !obj->IsActive()) return;

    ComponentNavigation* nav =
        (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);
    if (nav && nav->type == NavType::OBSTACLE)
        navObstacles.push_back(obj);

    for (auto* child : obj->GetChildren())
        RecollectObstacles(child);
}

// ---------------------------------------------------------------------------
// IsBlockedByObstacle
// ---------------------------------------------------------------------------
bool ModuleNavMesh::IsBlockedByObstacle(const glm::vec3& min, const glm::vec3& max)
{
    for (auto* obs : navObstacles)
    {
        if (!obs->IsActive()) continue;

        ComponentMesh* meshComp =
            static_cast<ComponentMesh*>(obs->GetComponent(ComponentType::MESH));
        if (!meshComp || !meshComp->HasMesh()) continue;

        const AABB& globalAABB = meshComp->GetGlobalAABB();
        glm::vec3   obsMin = globalAABB.min;
        glm::vec3   obsMax = globalAABB.max;

        if ((min.x <= obsMax.x && max.x >= obsMin.x) &&
            (min.y <= obsMax.y && max.y >= obsMin.y) &&
            (min.z <= obsMax.z && max.z >= obsMin.z))
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// RemoveNavMesh
// Removes the NavMesh entry that has 'obj' as its primary owner OR as a member.
// The entire merged group is removed in either case.
// ---------------------------------------------------------------------------
void ModuleNavMesh::RemoveNavMesh(GameObject* obj)
{
    if (!obj) return;

    for (auto it = navMeshes.begin(); it != navMeshes.end(); ++it)
    {
        bool match = (it->owner == obj);
        if (!match)
            for (auto* m : it->members)
                if (m == obj) { match = true; break; }

        if (match)
        {
            if (it->heightfield) rcFreeHeightField(it->heightfield);
            if (it->navMesh)     dtFreeNavMesh(it->navMesh);
            if (it->navQuery)    dtFreeNavMeshQuery(it->navQuery);
            if (it->chf)         rcFreeCompactHeightfield(it->chf);
            navMeshes.erase(it);
            LOG_CONSOLE("NavMesh removed for object: %s", obj->GetName().c_str());
            return;
        }
    }

    LOG_CONSOLE("NavMesh not found for object: %s", obj->GetName().c_str());
}

void ModuleNavMesh::RemoveNavMeshRecursive(GameObject* obj)
{
    if (!obj) return;

    // Check whether this object owns (or is a member of) a NavMesh entry.
    for (auto& data : navMeshes)
    {
        bool match = (data.owner == obj);
        if (!match)
            for (auto* m : data.members)
                if (m == obj) { match = true; break; }

        if (match) { RemoveNavMesh(obj); break; }
    }

    for (auto* child : obj->GetChildren())
        RemoveNavMeshRecursive(child);
}

// ---------------------------------------------------------------------------
// GetNavMeshData
// Returns the NavMeshData entry whose primary owner OR one of its members
// matches 'owner'. This allows agents linked to any surface in a merged
// group to correctly resolve their NavMesh.
// ---------------------------------------------------------------------------
ModuleNavMesh::NavMeshData* ModuleNavMesh::GetNavMeshData(GameObject* owner)
{
    for (auto& data : navMeshes)
    {
        if (data.owner == owner) return &data;
        for (auto* m : data.members)
            if (m == owner) return &data;
    }
    return nullptr;
}

// ---------------------------------------------------------------------------
// CleanUp
// ---------------------------------------------------------------------------
bool ModuleNavMesh::CleanUp()
{
   /* for (auto& mesh : navMeshes)
    {
        if (mesh.heightfield) rcFreeHeightField(mesh.heightfield);
        if (mesh.navMesh)     dtFreeNavMesh(mesh.navMesh);
        if (mesh.navQuery)    dtFreeNavMeshQuery(mesh.navQuery);
        if (mesh.chf)         rcFreeCompactHeightfield(mesh.chf);
    }
    navMeshes.clear();*/

    for (auto& mesh : navMeshes)
    {
        if (mesh.heightfield)
        {
            rcFreeHeightField(mesh.heightfield);
            mesh.heightfield = nullptr;
        }

        if (mesh.navMesh)
        {
            dtFreeNavMesh(mesh.navMesh);
            mesh.navMesh = nullptr;
        }

        if (mesh.navQuery)
        {
            dtFreeNavMeshQuery(mesh.navQuery);
            mesh.navQuery = nullptr;
        }

        if (mesh.chf)
        {
            rcFreeCompactHeightfield(mesh.chf);
            mesh.chf = nullptr;
        }
    }
    navMeshes.clear();
    navObstacles.clear();

    return true;
}

// ---------------------------------------------------------------------------
// FindPath
// ---------------------------------------------------------------------------
bool ModuleNavMesh::FindPath(GameObject* surface,
    const glm::vec3& start,
    const glm::vec3& end,
    std::vector<glm::vec3>& outPath)
{
    outPath.clear();
    NavMeshData* data = GetNavMeshData(surface);
    if (!data || !data->navQuery) return false;

    float extents[3] = { 2.f, 4.f, 2.f };
    dtQueryFilter filter;
    filter.setIncludeFlags(0xFFFF);

    float startF[3] = { start.x, start.y, start.z };
    float endF[3] = { end.x,   end.y,   end.z };

    dtPolyRef startRef, endRef;
    float nearestStart[3], nearestEnd[3];

    data->navQuery->findNearestPoly(startF, extents, &filter, &startRef, nearestStart);
    data->navQuery->findNearestPoly(endF, extents, &filter, &endRef, nearestEnd);

    if (!startRef || !endRef) return false;

    static const int MAX_POLYS = 256;
    dtPolyRef polys[MAX_POLYS];
    int nPolys = 0;
    data->navQuery->findPath(startRef, endRef, nearestStart, nearestEnd,
        &filter, polys, &nPolys, MAX_POLYS);
    if (nPolys == 0) return false;

    float         straightPath[MAX_POLYS * 3];
    unsigned char flags[MAX_POLYS];
    dtPolyRef     pathPolys[MAX_POLYS];
    int nStraight = 0;
    data->navQuery->findStraightPath(nearestStart, nearestEnd, polys, nPolys,
        straightPath, flags, pathPolys,
        &nStraight, MAX_POLYS);
    if (nStraight == 0) return false;

    for (int i = 0; i < nStraight; ++i)
        outPath.emplace_back(straightPath[i * 3],
            straightPath[i * 3 + 1],
            straightPath[i * 3 + 2]);
    return true;
}

// ---------------------------------------------------------------------------
// SaveNavMesh / LoadNavMesh
// ---------------------------------------------------------------------------
bool ModuleNavMesh::SaveNavMesh(const char* path, GameObject* owner)
{
    NavMeshData* data = GetNavMeshData(owner);
    if (!data || !data->navMesh) return false;

    FILE* fp = fopen(path, "wb");
    if (!fp) return false;

    const dtNavMesh* mesh = data->navMesh;
    for (int i = 0; i < mesh->getMaxTiles(); ++i)
    {
        const dtMeshTile* tile = mesh->getTile(i);
        if (!tile || !tile->header || !tile->dataSize) continue;

        dtPolyRef tileRef = mesh->getTileRef(tile);
        fwrite(&tileRef, sizeof(dtPolyRef), 1, fp);
        fwrite(&tile->dataSize, sizeof(int), 1, fp);
        fwrite(tile->data, 1, tile->dataSize, fp);
    }
    fclose(fp);
    return true;
}

bool ModuleNavMesh::LoadNavMesh(const char* path, GameObject* owner)
{
    FILE* fp = fopen(path, "rb");
    if (!fp) return false;

    RemoveNavMesh(owner);

    dtNavMesh* navMesh = dtAllocNavMesh();
    fclose(fp);
    return true;
}

// ---------------------------------------------------------------------------
// GetRandomPoint
// ---------------------------------------------------------------------------
bool ModuleNavMesh::GetRandomPoint(glm::vec3& outPoint)
{
    for (auto& data : navMeshes)
    {
        if (!data.navQuery) continue;

        dtQueryFilter filter;
        filter.setIncludeFlags(0xFFFF);

        dtPolyRef randomRef = 0;
        float     randomPt[3] = {};

        dtStatus status =
            data.navQuery->findRandomPoint(&filter, NavRand, &randomRef, randomPt);

        if (dtStatusSucceed(status))
        {
            outPoint = { randomPt[0], randomPt[1], randomPt[2] };
            return true;
        }
    }
    return false;
}