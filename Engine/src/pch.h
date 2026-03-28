#pragma once

// Standard
#include <string>
#include <vector>
#include <iostream>
#include <list>
#include <memory>
#include <functional>
#include <algorithm>
#include <limits>
#include <unordered_map>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <ctime>
#include <cwchar>
#include <windows.h>

// glad
#include <glad/glad.h>

// assimp
#include <assimp/scene.h>        
#include <assimp/Importer.hpp>
#include <assimp/postprocess.h>
#include <assimp/cimport.h>
#include <assimp/mesh.h>

// glm
#define GLM_ENABLE_EXPERIMENTAL
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/matrix_access.hpp>
#include <glm/gtx/matrix_decompose.hpp>
#include <glm/gtc/quaternion.hpp>

// ImGui
#include <imgui.h>
#include <ImGuizmo.h>

// nlohmann json
#include <nlohmann/json.hpp>

// Wwise SDK
#include <AK/SoundEngine/Common/AkTypes.h>
#include <AK/SoundEngine/Common/AkMemoryMgr.h>
#include <AK/SoundEngine/Common/AkMemoryMgrModule.h>
#include <AK/SoundEngine/Common/IAkStreamMgr.h>
#include <AK/Tools/Common/AkPlatformFuncs.h>
#include <AK/SoundEngine/Common/AkSoundEngine.h>
#include <AK/SpatialAudio/Common/AkSpatialAudio.h>

#ifndef AK_OPTIMIZED
#include <AK/Comm/AkCommunication.h>
#endif