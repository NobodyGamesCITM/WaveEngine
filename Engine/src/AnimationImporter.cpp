#include "AnimationImporter.h"
#include "ResourceAnimation.h"
#include "LibraryManager.h"
#include "Log.h"
#include <assimp/scene.h>
#include <fstream>

AnimationImporter::AnimationImporter() {}
AnimationImporter::~AnimationImporter() {}

// IMPORT: Assimp -> Our AnimationData Structure
Animation AnimationImporter::ImportFromAssimp(const aiAnimation* assimpAnim) {
    
    Animation animData;

    if (!assimpAnim) {
        LOG_CONSOLE("[AnimationImporter] ERROR: assimpAnim is nullptr");
        return animData;
    }

    animData.duration = assimpAnim->mDuration;
    animData.ticksPerSecond = assimpAnim->mTicksPerSecond;

    // Si Assimp no nos da los ticks, por defecto a 24 fps (estándar cine)
    if (animData.ticksPerSecond == 0) {
        animData.ticksPerSecond = 24.0;
    }

    if (assimpAnim->mChannels[0]->mNumPositionKeys < (unsigned int)animData.duration) {
        LOG_CONSOLE("[AnimationImporter] WARNING: Animation %s seems NOT baked. Runtime glitches expected.", assimpAnim->mName.C_Str());
    }

    animData.channels.reserve(assimpAnim->mNumChannels);

    for (unsigned int i = 0; i < assimpAnim->mNumChannels; i++)
    {
        aiNodeAnim* aiChannel = assimpAnim->mChannels[i];
        Channel ourChannel;

        ourChannel.name = aiChannel->mNodeName.C_Str();

        // Extraer Posiciones
        ourChannel.positionKeys.reserve(aiChannel->mNumPositionKeys);
        for (unsigned int k = 0; k < aiChannel->mNumPositionKeys; k++) {
            aiVectorKey aiKey = aiChannel->mPositionKeys[k];
            ourChannel.positionKeys.push_back(glm::vec3(aiKey.mValue.x, aiKey.mValue.y, aiKey.mValue.z));
        }

        // Extraer Rotaciones
        ourChannel.rotationKeys.reserve(aiChannel->mNumRotationKeys);
        for (unsigned int k = 0; k < aiChannel->mNumRotationKeys; k++) {
            aiQuatKey aiKey = aiChannel->mRotationKeys[k];
            ourChannel.rotationKeys.push_back(glm::quat(aiKey.mValue.w, aiKey.mValue.x, aiKey.mValue.y, aiKey.mValue.z));
        }

        // Extraer Escalas
        ourChannel.scaleKeys.reserve(aiChannel->mNumScalingKeys);
        for (unsigned int k = 0; k < aiChannel->mNumScalingKeys; k++) {
            aiVectorKey aiKey = aiChannel->mScalingKeys[k];
            ourChannel.scaleKeys.push_back(glm::vec3(aiKey.mValue.x, aiKey.mValue.y, aiKey.mValue.z));
        }

        animData.channels.push_back(ourChannel);
    }

    return animData;
}

// SAVE: Our AnimationData -> Custom Binary Format
bool AnimationImporter::SaveToCustomFormat(const Animation& animData, const UID& uid) {

    std::string fullPath = LibraryManager::GetLibraryPath(uid);

    std::ofstream file(fullPath, std::ios::out | std::ios::binary);
    if (!file.is_open()) {
        LOG_CONSOLE("[AnimationImporter] ERROR: Could not open file for writing: %s", fullPath.c_str());
        return false;
    }

    file.write(reinterpret_cast<const char*>(&animData.duration), sizeof(double));
    file.write(reinterpret_cast<const char*>(&animData.ticksPerSecond), sizeof(double));

    uint32_t numChannels = static_cast<uint32_t>(animData.channels.size());
    file.write(reinterpret_cast<const char*>(&numChannels), sizeof(uint32_t));

    for (const auto& channel : animData.channels)
    {
        uint32_t nameSize = static_cast<uint32_t>(channel.name.size());
        file.write(reinterpret_cast<const char*>(&nameSize), sizeof(uint32_t));
        file.write(channel.name.c_str(), nameSize);

        uint32_t numPos = static_cast<uint32_t>(channel.positionKeys.size());
        uint32_t numRot = static_cast<uint32_t>(channel.rotationKeys.size());
        uint32_t numScl = static_cast<uint32_t>(channel.scaleKeys.size());

        file.write(reinterpret_cast<const char*>(&numPos), sizeof(uint32_t));
        file.write(reinterpret_cast<const char*>(&numRot), sizeof(uint32_t));
        file.write(reinterpret_cast<const char*>(&numScl), sizeof(uint32_t));

        if (numPos > 0)
            file.write(reinterpret_cast<const char*>(channel.positionKeys.data()), numPos * sizeof(glm::vec3));

        if (numRot > 0)
            file.write(reinterpret_cast<const char*>(channel.rotationKeys.data()), numRot * sizeof(glm::quat));

        if (numScl > 0)
            file.write(reinterpret_cast<const char*>(channel.scaleKeys.data()), numScl * sizeof(glm::vec3));
    }

    file.close();
    LOG_CONSOLE("[AnimationImporter] Saved animation binary: %s", fullPath.c_str());
    return true;
}

Animation AnimationImporter::LoadFromCustomFormat(const UID& uid) {

    Animation animData;
    std::string fullPath = LibraryManager::GetLibraryPath(uid);

    std::ifstream file(fullPath, std::ios::in | std::ios::binary);
    if (!file.is_open()) {
        LOG_CONSOLE("[AnimationImporter] ERROR: Could not open file for reading: %s", fullPath.c_str());
        return animData;
    }

    file.read(reinterpret_cast<char*>(&animData.duration), sizeof(double));
    file.read(reinterpret_cast<char*>(&animData.ticksPerSecond), sizeof(double));

    uint32_t numChannels = 0;
    file.read(reinterpret_cast<char*>(&numChannels), sizeof(uint32_t));

    animData.channels.reserve(numChannels);

    for (uint32_t i = 0; i < numChannels; ++i)
    {
        Channel channel;

        uint32_t nameSize = 0;
        file.read(reinterpret_cast<char*>(&nameSize), sizeof(uint32_t));
        if (nameSize > 0) {
            channel.name.resize(nameSize);
            file.read(&channel.name[0], nameSize);
        }

        uint32_t numPos = 0, numRot = 0, numScl = 0;
        file.read(reinterpret_cast<char*>(&numPos), sizeof(uint32_t));
        file.read(reinterpret_cast<char*>(&numRot), sizeof(uint32_t));
        file.read(reinterpret_cast<char*>(&numScl), sizeof(uint32_t));

        if (numPos > 0) {
            channel.positionKeys.resize(numPos);
            file.read(reinterpret_cast<char*>(channel.positionKeys.data()), numPos * sizeof(glm::vec3));
        }
        if (numRot > 0) {
            channel.rotationKeys.resize(numRot);
            file.read(reinterpret_cast<char*>(channel.rotationKeys.data()), numRot * sizeof(glm::quat));
        }
        if (numScl > 0) {
            channel.scaleKeys.resize(numScl);
            file.read(reinterpret_cast<char*>(channel.scaleKeys.data()), numScl * sizeof(glm::vec3));
        }

        animData.channels.push_back(channel);
    }

    file.close();
    return animData;
}