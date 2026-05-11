#include "SceneImporter.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include <fstream>
#include <sstream>


bool SceneImporter::ImportFromFile(const std::string& file_path, const MetaFile& meta)
{
    Scene scene;

    std::ifstream file(file_path);
    if (!file.is_open()) {
        LOG_DEBUG("[SceneImporter] ERROR: Could not open file: %s", file_path.c_str());
        return false;
    }

    try {
        nlohmann::json j;
        file >> j;
        scene.sceneJson = j;
        LOG_DEBUG("[SceneImporter] Scene imported successfully: %s", file_path.c_str());
    }
    catch (nlohmann::json::parse_error& e) {
        LOG_DEBUG("[SceneImporter] JSON Parse Error: %s", e.what());
    }

    return SaveToCustomFormat(scene, meta.uid);
}

bool SceneImporter::SaveToCustomFormat(const Scene& scene, const UID& uid)
{
    std::string fullPath = LibraryManager::GetLibraryPath(uid);
    std::ofstream file(fullPath, std::ios::out | std::ios::binary);

    if (file.is_open())
    {
        try
        {
            std::vector<uint8_t> msgpackData = nlohmann::json::to_msgpack(scene.sceneJson);

            file.write(reinterpret_cast<const char*>(msgpackData.data()), msgpackData.size());
            file.close();

            LOG_CONSOLE("[SceneImporter] Guardado modelo binario: %s", fullPath.c_str());
            return true;
        }
        catch (const nlohmann::json::exception& e)
        {
            LOG_CONSOLE("[SceneImporter] ERROR crítico guardando MsgPack en %s: %s", fullPath.c_str(), e.what());
            file.close();
            return false;
        }
    }

    LOG_CONSOLE("[SceneImporter] ERROR: No se pudo abrir para escribir: %s", fullPath.c_str());
    return false;
}

Scene SceneImporter::LoadFromCustomFormat(const UID& uid)
{
    Scene scene;
    std::string fullPath = LibraryManager::GetLibraryPath(uid);

    std::ifstream file(fullPath, std::ios::in | std::ios::binary | std::ios::ate);

    if (file.is_open())
    {
        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);

        if (size > 0)
        {
            std::vector<uint8_t> msgpackData(size);
            file.read(reinterpret_cast<char*>(msgpackData.data()), size);

            try
            {
                scene.sceneJson = nlohmann::json::from_msgpack(msgpackData);
                LOG_CONSOLE("[SceneImporter] Modelo binario cargado: %s", fullPath.c_str());
            }
            catch (const nlohmann::json::parse_error& e)
            {
                LOG_CONSOLE("[SceneImporter] ERROR parseando MsgPack en %s: %s", fullPath.c_str(), e.what());
            }
        }

        file.close();
    }
    else
    {
        LOG_CONSOLE("[SceneImporter] ERROR: No se pudo abrir para leer: %s", fullPath.c_str());
    }

    return scene;
}