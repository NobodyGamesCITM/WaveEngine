#include "ScriptImporter.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include <fstream>
#include <sstream>

const char XOR_KEY = 0x5A;

bool ScriptImporter::ImportFromFile(const std::string& file_path, const MetaFile& meta)
{
    Script script;

    std::ifstream file(file_path);
    if (!file.is_open()) {
        LOG_DEBUG("[ScriptImporter] ERROR: Could not open lua file: %s", file_path.c_str());
        return false;
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    script.scriptContent = buffer.str();
    file.close();

    if (script.scriptContent.empty()) {
        LOG_DEBUG("[ScriptImporter] WARNING: Lua file is empty: %s", file_path.c_str());
    }

    LOG_DEBUG("[ScriptImporter] Script read successfully: %s", file_path.c_str());

    return SaveToCustomFormat(script, meta.uid);
}

bool ScriptImporter::SaveToCustomFormat(const Script& script, const UID& uid)
{
    std::string fullPath = LibraryManager::GetLibraryPathFromUID(uid);
    std::ofstream file(fullPath, std::ios::out | std::ios::binary);

    if (file.is_open())
    {
        size_t contentSize = script.scriptContent.size();
        file.write(reinterpret_cast<const char*>(&contentSize), sizeof(size_t));

        for (size_t i = 0; i < contentSize; ++i)
        {
            char encryptedChar = script.scriptContent[i] ^ XOR_KEY;
            file.write(&encryptedChar, 1);
        }

        file.close();
        LOG_CONSOLE("[ScriptImporter] Guardado script binario (cifrado): %s", fullPath.c_str());
        return true;
    }

    LOG_CONSOLE("[ScriptImporter] ERROR: No se pudo abrir para escribir: %s", fullPath.c_str());
    return false;
}

Script ScriptImporter::LoadFromCustomFormat(const UID& uid)
{
    Script script;
    std::string fullPath = LibraryManager::GetLibraryPathFromUID(uid);
    std::ifstream file(fullPath, std::ios::in | std::ios::binary);

    if (file.is_open())
    {
        size_t contentSize = 0;
        file.read(reinterpret_cast<char*>(&contentSize), sizeof(size_t));

        if (contentSize > 0)
        {
            script.scriptContent.resize(contentSize);
            file.read(&script.scriptContent[0], contentSize);


            for (size_t i = 0; i < contentSize; ++i)
            {
                script.scriptContent[i] ^= XOR_KEY;
            }
            LOG_CONSOLE("[ScriptImporter] Script binario descifrado y cargado");
        }

        file.close();
    }
    else
    {
        LOG_CONSOLE("[ScriptImporter] ERROR: No se pudo abrir Library file: %s", fullPath.c_str());
    }

    return script;
}