#include "ScriptImporter.h"
#include "LibraryManager.h"
#include "Application.h"
#include "ModuleResources.h"
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
    std::string fullPath = LibraryManager::GetLibraryPath(uid);
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
    std::string fullPath = LibraryManager::GetLibraryPath(uid);
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

UID ScriptImporter::CreateNewScript(const std::string& directory, const std::string& name)
{
    std::string filename = name;

    if (filename.find(".lua") == std::string::npos)
    {
        filename += ".lua";
    }

    fs::path scriptPath = fs::path(directory) / filename;

    if (fs::exists(scriptPath))
    {
        LOG_CONSOLE("[ScriptImporter] Script already exists: %s, generating unique name...", filename.c_str());
        int counter = 1;
        std::string baseName = name;
        do
        {
            filename = baseName + "_" + std::to_string(counter) + ".lua";
            scriptPath = fs::path(directory) / filename;
            counter++;
        } while (fs::exists(scriptPath));
    }

    std::ofstream scriptFile(scriptPath);
    if (!scriptFile.is_open())
    {
        LOG_CONSOLE("[ScriptImporter] ERROR: Cannot create script file at %s", scriptPath.string().c_str());
        return 0;
    }

    scriptFile << GetDefaultScriptTemplate();
    scriptFile.close();

    LOG_CONSOLE("[ScriptImporter] Created script: %s", scriptPath.string().c_str());

    UID importedUID = Application::GetInstance().resources.get()->ImportFile(scriptPath.generic_string().c_str(), true);

    return importedUID;
}

std::string ScriptImporter::GetDefaultScriptTemplate()
{
    return R"(-- Script Template
-- This script is attached to a GameObject
-- Access the GameObject through: self.gameObject
-- Access the Transform through: self.transform

function Start()
    -- Called once when the script is initialized
    Engine.Log("Script Started!")
    
    -- Example: Get initial position
    local pos = self.transform.position
    Engine.Log("Initial Position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
end

function Update(deltaTime)
    -- Called every frame
    -- deltaTime = time since last frame in seconds
    
    -- Example: Rotate object
    -- local rot = self.transform.rotation
    -- self.transform:SetRotation(rot.x, rot.y + 90 * deltaTime, rot.z)
    
    -- Example: Move with WASD
    -- local pos = self.transform.position
    -- local speed = 5.0
    -- 
    -- if Input.GetKey("W") then
    --     self.transform:SetPosition(pos.x, pos.y, pos.z - speed * deltaTime)
    -- end
    -- if Input.GetKey("S") then
    --     self.transform:SetPosition(pos.x, pos.y, pos.z + speed * deltaTime)
    -- end
    -- if Input.GetKey("A") then
    --     self.transform:SetPosition(pos.x - speed * deltaTime, pos.y, pos.z)
    -- end
    -- if Input.GetKey("D") then
    --     self.transform:SetPosition(pos.x + speed * deltaTime, pos.y, pos.z)
    -- end
end
)";
}