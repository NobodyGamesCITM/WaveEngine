#include "MaterialImporter.h"
#include "MaterialStandard.h"
#include "LibraryManager.h"
#include "Application.h"
#include "ModuleResources.h"
#include "Globals.h"
#include <fstream>
#include "nlohmann/json.hpp"

MaterialImporter::MaterialImporter() {}
MaterialImporter::~MaterialImporter() {}

bool MaterialImporter::ImportMaterial(const std::string& path, const UID& uid)
{
    std::ifstream file(path);
    if (!file.is_open()) return false;

    nlohmann::json j;
    try {
        file >> j;
    }
    catch (nlohmann::json::parse_error& e) {
        return false;
    }

    MaterialType type = (MaterialType)j.value("Type", (int)MaterialType::STANDARD);

    Material* mat = nullptr;
    switch (type) {
    case MaterialType::STANDARD: mat = new MaterialStandard(type); break;
    }

    if (mat) {
        mat->SetOpacity(j.value("Opacity", 1.0f));
        mat->LoadFromJson(j);

        bool succes = SaveToCustomFormat(*mat, uid);

        delete mat;
        return succes;
    }

    return false;
}

bool MaterialImporter::SaveToCustomFormat(const Material& mat, const UID& uid)
{
    std::string fullPath = LibraryManager::GetLibraryPathFromUID(uid);
    std::ofstream file(fullPath, std::ios::binary);

    if (!file.is_open()) return false;
    MaterialType type = mat.GetType();
    file.write((char*)&type, sizeof(MaterialType));

    float opacity = mat.GetOpacity();
    file.write((char*)&opacity, sizeof(float));

    mat.SaveCustomData(file);

    file.close();
    return true;
}

Material* MaterialImporter::LoadFromCustomFormat(const UID& uid)
{
    std::string fullPath = LibraryManager::GetLibraryPathFromUID(uid);
    std::ifstream file(fullPath, std::ios::binary);

    if (!file.is_open()) return nullptr;

    MaterialType type;
    file.read((char*)&type, sizeof(MaterialType));

    Material* mat = nullptr;

    switch (type) {
    case MaterialType::STANDARD:
        mat = new MaterialStandard(type);
        break;
    }

    if (mat) {
        float opacity;
        file.read((char*)&opacity, sizeof(float));
        mat->SetOpacity(opacity);

        mat->LoadCustomData(file);
    }

    file.close();
    return mat;
}

UID MaterialImporter::CreateNewMaterial(const std::string& directory, const std::string& name) {
    
    MaterialStandard* defaultMat = new MaterialStandard(MaterialType::STANDARD);
    UID newUID = GenerateUID();
    std::string fileName = "";
    if (name.size()!=0)
        fileName = directory + "/" + name + ".mat";
    else
        fileName = directory + "/NewMaterial_" + std::to_string(newUID) + ".mat";

    nlohmann::json j;
    j["Type"] = (int)defaultMat->GetType();
    j["Opacity"] = defaultMat->GetOpacity();
    defaultMat->SaveToJson(j);

    bool success = false;
    std::ofstream file(fileName);
    if (file.is_open()) {
        file << j.dump(4);
        file.close();
        success = true;
    }

    Application::GetInstance().resources.get()->ImportFile(fileName.c_str(), true);

    delete defaultMat;
    return success ? newUID : 0;
}

Material* MaterialImporter::CloneMaterial(const Material* source) {
    if (!source) return nullptr;

    nlohmann::json tmp;
    tmp["Type"] = (int)source->GetType();
    tmp["Opacity"] = source->GetOpacity();
    source->SaveToJson(tmp);

    Material* copy = nullptr;
    switch (source->GetType()) {
    case MaterialType::STANDARD: copy = new MaterialStandard(MaterialType::STANDARD); break;
    }

    if (copy) {
        copy->LoadFromJson(tmp);
    }

    return copy;
}