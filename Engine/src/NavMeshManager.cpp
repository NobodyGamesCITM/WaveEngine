#include "Application.h"
#include "ModuleScene.h"
#include "GameObject.h"
#include "ComponentMesh.h"
#include "Transform.h"
#include "Log.h"
#include "NavMeshManager.h"
#include "ComponentNavigation.h"

#include "DetourNavMesh.h"
#include "DetourNavMeshBuilder.h"
#include "DetourNavMeshQuery.h"
ModuleNavMesh::ModuleNavMesh() : Module() {
    name = "ModuleNavMesh";
}

ModuleNavMesh::~ModuleNavMesh() {
    CleanUp();
}

bool ModuleNavMesh::Start() {
    LOG_CONSOLE("NavMesh Manager Started");
    return true;
}

bool ModuleNavMesh::Update() {
    DrawDebug(); // Llamamos a la función de dibujo
    return true;
}

void ModuleNavMesh::RecollectGeometry(GameObject* obj, std::vector<float>& vertices, std::vector<int>& indices)
{
    if (obj == nullptr || !obj->IsActive()) return;

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

  /*  if (mesh != nullptr && mesh->HasMesh())
        ExtractVertices(mesh, vertices, indices);*/

    for (GameObject* child : obj->GetChildren())
        RecollectGeometry(child, vertices, indices);
}

void ModuleNavMesh::ExtractVertices(ComponentMesh* mesh, std::vector<float>& vertices, std::vector<int>& indices)
{
    if (mesh == nullptr || !mesh->HasMesh()) return;

    const Mesh& meshData = mesh->GetMesh();
    GameObject* owner = mesh->owner;
    if (!owner) return;

    Transform* trans = (Transform*)owner->GetComponent(ComponentType::TRANSFORM);
    if (!trans) return;

    glm::mat4 globalMat = trans->GetGlobalMatrix();

    // Offset para que los índices apunten correctamente al buffer global
    int vertexOffset = vertices.size() / 3;

    for (const auto& vertex : meshData.vertices)
    {
        glm::vec4 worldPos = globalMat * glm::vec4(vertex.position.x, vertex.position.y, vertex.position.z, 1.0f);
        vertices.push_back(worldPos.x);
        vertices.push_back(worldPos.y);
        vertices.push_back(worldPos.z);
    }

    // Usar los índices reales del mesh
    for (unsigned int idx : meshData.indices)
        indices.push_back(vertexOffset + (int)idx);
}
void ModuleNavMesh::Bake(GameObject* root)
{
    std::function<GameObject* (GameObject*)> FindSurface = [&](GameObject* obj) -> GameObject*
        {
            if (!obj || !obj->IsActive()) return nullptr;

            ComponentNavigation* nav = (ComponentNavigation*)obj->GetComponent(ComponentType::NAVIGATION);
            if (nav && nav->type == NavType::SURFACE)
                return obj;

            for (auto* child : obj->GetChildren())
                if (auto* found = FindSurface(child))
                    return found;

            return nullptr;
        };

    GameObject* surface = FindSurface(root);
    if (!surface)
    {
        LOG_CONSOLE("NavMesh Error: No hay ningun objeto con NavType::SURFACE en la escena.");
        return;
    }

    LOG_CONSOLE("NavMesh: Bakeando superficie -> %s", surface->GetName().c_str());

    RemoveNavMeshRecursive(surface);
    navObstacles.clear();
    RecollectObstacles(Application::GetInstance().scene->GetRoot()); // ← escena entera, no solo el surface

    std::vector<float> allVertices;
    std::vector<int>   allIndices;
    RecollectGeometry(surface, allVertices, allIndices);

    if (allVertices.empty() || allIndices.empty())
    {
        LOG_CONSOLE("NavMesh Error: No geometry found to bake!");
        return;
    }

    ComponentNavigation* navComp = static_cast<ComponentNavigation*>(surface->GetComponent(ComponentType::NAVIGATION));

    float bmin[3], bmax[3];
    CalculateAABB(allVertices, bmin, bmax);

    rcConfig cfg = CreateDefaultConfig(bmin, bmax);
    cfg.walkableSlopeAngle = navComp->maxSlopeAngle;

    rcContext ctx;

    rcHeightfield* hf = rcAllocHeightfield();
    if (!rcCreateHeightfield(&ctx, *hf, cfg.width, cfg.height, cfg.bmin, cfg.bmax, cfg.cs, cfg.ch))
    {
        LOG_CONSOLE("NavMesh Error: Could not create heightfield.");
        return;
    }

    int nVerts = allVertices.size() / 3;
    int nTris = allIndices.size() / 3;

    std::vector<unsigned char> areas(nTris, RC_WALKABLE_AREA);
    rcRasterizeTriangles(&ctx, allVertices.data(), nVerts, allIndices.data(), areas.data(), nTris, *hf, cfg.walkableClimb);

    rcFilterLowHangingWalkableObstacles(&ctx, cfg.walkableClimb, *hf);
    rcFilterLedgeSpans(&ctx, cfg.walkableHeight, cfg.walkableClimb, *hf);
    rcFilterWalkableLowHeightSpans(&ctx, cfg.walkableHeight, *hf);

    rcCompactHeightfield* chf = rcAllocCompactHeightfield();
    if (!rcBuildCompactHeightfield(&ctx, cfg.walkableHeight, cfg.walkableClimb, *hf, *chf))
    {
        LOG_CONSOLE("NavMesh Error: compact heightfield"); return;
    }

    // ── Marcar obstáculos como RC_NULL_AREA ───────────────────────────────────
    for (GameObject* obs : navObstacles)
    {
        if (!obs || !obs->IsActive()) continue;

        ComponentMesh* meshComp = static_cast<ComponentMesh*>(obs->GetComponent(ComponentType::MESH));
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

    //solo walkable los polys que NO son obstáculo
    for (int i = 0; i < pmesh->npolys; ++i)
    {
        if (pmesh->areas[i] == RC_WALKABLE_AREA)
            pmesh->flags[i] = 1;
        else
            pmesh->flags[i] = 0;
    }

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

    dtNavMesh* navMesh = dtAllocNavMesh();
    navMesh->init(navData, navDataSize, DT_TILE_FREE_DATA);

    dtNavMeshQuery* navQuery = dtAllocNavMeshQuery();
    navQuery->init(navMesh, 2048);

    rcFreeContourSet(cset);
    rcFreePolyMesh(pmesh);
    rcFreePolyMeshDetail(dmesh);

    NavMeshData meshData;
    meshData.heightfield = hf;
    meshData.chf = chf;
    meshData.navMesh = navMesh;
    meshData.navQuery = navQuery;
    meshData.owner = surface;
    meshData.tileRef = navMesh->getTileRefAt(0, 0, 0);

    if (meshData.tileRef == 0)
        LOG_CONSOLE("NavMesh Warning: tileRef es 0 para %s!", surface->GetName().c_str());

    navMeshes.push_back(meshData);

    LOG_CONSOLE("NavMesh Bake exitoso: %s. Vertices: %d Triangulos: %d", surface->GetName().c_str(), nVerts, nTris);
}

void ModuleNavMesh::CalculateAABB(const std::vector<float>& verts, float* minBounds, float* maxBounds) {
    minBounds[0] = maxBounds[0] = verts[0];
    minBounds[1] = maxBounds[1] = verts[1];
    minBounds[2] = maxBounds[2] = verts[2];

    for (size_t i = 3; i < verts.size(); i += 3) {
        rcVmin(minBounds, &verts[i]);
        rcVmax(maxBounds, &verts[i]);
    }
}

rcConfig ModuleNavMesh::CreateDefaultConfig(const float* minBounds, const float* maxBounds) {
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

void ModuleNavMesh::DrawDebug()
{
    glm::vec4 colorWalkable = { 0.0f, 0.75f, 1.0f, 1.0f };
    glm::vec4 colorEdge = { 0.0f, 0.4f,  0.9f, 1.0f };

    for (auto& meshData : navMeshes)
    {
        // getTile(int) es privado en esta versión de Detour — usamos getTileByRef
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
                const unsigned char* tri = &tile->detailTris[(detail->triBase + t) * 4];

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
                        const float* vert = &tile->detailVerts[(detail->vertBase + tri[k] - poly->vertCount) * 3];
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


bool ModuleNavMesh::IsBlockedByObstacle(const glm::vec3& min, const glm::vec3& max)
{
    for (auto* obs : navObstacles)
    {
        if (!obs->IsActive()) continue;

        ComponentMesh* meshComp = static_cast<ComponentMesh*>(obs->GetComponent(ComponentType::MESH));
        if (!meshComp || !meshComp->HasMesh()) continue;

        // Use GetGlobalAABB instead of the non-existent GetWorldAABB
        const AABB& globalAABB = meshComp->GetGlobalAABB();

        // Assuming your AABB class uses 'minPoint' and 'maxPoint' or 'min' and 'max'
        // Adjust these member names to match your AABB.h definition
        glm::vec3 obsMin = globalAABB.min;
        glm::vec3 obsMax = globalAABB.max;

        // AABB Collision check
        if ((min.x <= obsMax.x && max.x >= obsMin.x) &&
            (min.y <= obsMax.y && max.y >= obsMin.y) &&
            (min.z <= obsMax.z && max.z >= obsMin.z))
        {
            return true;
        }
    }
    return false;
}

void ModuleNavMesh::RemoveNavMesh(GameObject* obj)
{
    if (!obj) return;

    for (auto it = navMeshes.begin(); it != navMeshes.end(); ++it)
    {
        if (it->owner == obj)
        {
            if (it->heightfield) rcFreeHeightField(it->heightfield);
            if (it->navMesh) dtFreeNavMesh(it->navMesh);
            if (it->navQuery) dtFreeNavMeshQuery(it->navQuery);
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

    for (auto& data : navMeshes)
    {
        if (data.owner == obj)
        {
            RemoveNavMesh(obj);
            break;
        }
    }

    for (auto* child : obj->GetChildren())
        RemoveNavMeshRecursive(child);
}


ModuleNavMesh::NavMeshData* ModuleNavMesh::GetNavMeshData(GameObject* owner) {
    for (auto& data : navMeshes)
    {
        if (data.owner == owner)
            return &data;
    }
    return nullptr;
}


bool ModuleNavMesh::CleanUp() {

    // Es vital liberar la memoria de Recast/Detour para evitar memory leaks
    for (auto& mesh : navMeshes)
    {
        if (mesh.heightfield) rcFreeHeightField(mesh.heightfield);
        if (mesh.navMesh) dtFreeNavMesh(mesh.navMesh);
        if (mesh.navQuery) dtFreeNavMeshQuery(mesh.navQuery);
        if (mesh.chf) rcFreeCompactHeightfield(mesh.chf);
    }

    navMeshes.clear();
 
    

    return true;
}

bool ModuleNavMesh::FindPath(GameObject* surface,
    const glm::vec3& start,
    const glm::vec3& end,
    std::vector<glm::vec3>& outPath)
{
    outPath.clear();
    NavMeshData* data = GetNavMeshData(surface);
    if (!data || !data->navQuery) return false;

    float extents[3] = { 2.f, 4.f, 2.f }; // margen de búsqueda del poly más cercano
    dtQueryFilter filter;
    filter.setIncludeFlags(0xFFFF);

    float startF[3] = { start.x, start.y, start.z };
    float endF[3] = { end.x,   end.y,   end.z };

    dtPolyRef startRef, endRef;
    float nearestStart[3], nearestEnd[3];

    // Encuentra el polígono más cercano a cada punto
    data->navQuery->findNearestPoly(startF, extents, &filter, &startRef, nearestStart);
    data->navQuery->findNearestPoly(endF, extents, &filter, &endRef, nearestEnd);

    if (!startRef || !endRef) return false;

    // Busca el camino como lista de polígonos
    static const int MAX_POLYS = 256;
    dtPolyRef polys[MAX_POLYS];
    int nPolys = 0;
    data->navQuery->findPath(startRef, endRef, nearestStart, nearestEnd,
        &filter, polys, &nPolys, MAX_POLYS);
    if (nPolys == 0) return false;

    // Convierte la lista de polígonos en puntos suavizados en world-space
    float straightPath[MAX_POLYS * 3];
    unsigned char flags[MAX_POLYS];
    dtPolyRef pathPolys[MAX_POLYS];
    int nStraight = 0;
    data->navQuery->findStraightPath(nearestStart, nearestEnd, polys, nPolys,
        straightPath, flags, pathPolys,
        &nStraight, MAX_POLYS);
    if (nStraight == 0) return false;

    for (int i = 0; i < nStraight; ++i)
        outPath.emplace_back(straightPath[i * 3], straightPath[i * 3 + 1], straightPath[i * 3 + 2]);

    return true;
}

bool ModuleNavMesh::SaveNavMesh(const char* path, GameObject* owner) {
    NavMeshData* data = GetNavMeshData(owner);
    if (!data || !data->navMesh) return false;

    FILE* fp = fopen(path, "wb");
    if (!fp) return false;

    // 1. Guardar la configuración (header)
    const dtNavMesh* mesh = data->navMesh;
    for (int i = 0; i < mesh->getMaxTiles(); ++i) {
        const dtMeshTile* tile = mesh->getTile(i);
        if (!tile || !tile->header || !tile->dataSize) continue;

        // Escribimos el tile ref y el tamaño de los datos
        dtPolyRef tileRef = mesh->getTileRef(tile);
        fwrite(&tileRef, sizeof(dtPolyRef), 1, fp);
        fwrite(&tile->dataSize, sizeof(int), 1, fp);
        fwrite(tile->data, 1, tile->dataSize, fp);
    }
    fclose(fp);
    return true;
}

bool ModuleNavMesh::LoadNavMesh(const char* path, GameObject* owner) {
    FILE* fp = fopen(path, "rb");
    if (!fp) return false;

    RemoveNavMesh(owner);

    dtNavMesh* navMesh = dtAllocNavMesh();
    fclose(fp);
    return true;
}