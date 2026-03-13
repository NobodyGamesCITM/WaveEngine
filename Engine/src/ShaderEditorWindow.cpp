#include "ShaderEditorWindow.h"
#include <imgui.h>
#include "Application.h"
#include "ModuleResources.h"
#include "ResourceShader.h"
#include "Log.h"
#include <fstream>

ShaderEditorWindow::ShaderEditorWindow()
    : EditorWindow("Shader Editor")
{
    isOpen = false;
    memset(shaderEditBuffer, 0, sizeof(shaderEditBuffer));
}

ShaderEditorWindow::~ShaderEditorWindow()
{
}

void ShaderEditorWindow::Draw()
{
    if (!isOpen) return;

    ImGui::SetNextWindowSize(ImVec2(700, 500), ImGuiCond_FirstUseEver);
    if (ImGui::Begin(name.c_str(), &isOpen, ImGuiWindowFlags_MenuBar))
    {
        if (ImGui::BeginMenuBar())
        {
            if (ImGui::BeginMenu("File"))
            {
                if (ImGui::MenuItem("Save & Compile", "Ctrl+S", false, selectedShaderUID != 0))
                {
                    CompileAndSave();
                }
                ImGui::EndMenu();
            }
            ImGui::EndMenuBar();
        }

        // Shader Selection
        ImGui::Text("Active Shader:");
        ImGui::SameLine();

        std::string currentShaderName = "None";
        if (selectedShaderUID != 0)
        {
            ResourceShader* res = static_cast<ResourceShader*>(Application::GetInstance().resources->GetResourceDirect(selectedShaderUID));
            if (res)
            {
                currentShaderName = res->GetAssetFile();
                size_t lastSlash = currentShaderName.find_last_of("/\\");
                if (lastSlash != std::string::npos)
                    currentShaderName = currentShaderName.substr(lastSlash + 1);
            }
        }

        ImGui::SetNextItemWidth(300);
        if (ImGui::BeginCombo("##ShaderSelect", currentShaderName.c_str()))
        {
            const auto& allResources = Application::GetInstance().resources->GetAllResources();
            for (const auto& pair : allResources)
            {
                if (pair.second->GetType() == Resource::SHADER)
                {
                    std::string name = pair.second->GetAssetFile();
                    size_t lastSlash = name.find_last_of("/\\");
                    if (lastSlash != std::string::npos) name = name.substr(lastSlash + 1);

                    if (ImGui::Selectable(name.c_str(), selectedShaderUID == pair.first))
                    {
                        LoadShaderResource(pair.first);
                    }
                }
            }
            ImGui::EndCombo();
        }

        ImGui::Separator();

        // Editing Area
        if (selectedShaderUID != 0)
        {
            ImVec2 availableSpace = ImGui::GetContentRegionAvail();
            if (showCompilationError)
                availableSpace.y -= 100;

            ImGui::InputTextMultiline("##ShaderCode", shaderEditBuffer, sizeof(shaderEditBuffer), 
                                      ImVec2(-1, availableSpace.y), 
                                      ImGuiInputTextFlags_AllowTabInput);
            
            // Handle Ctrl+S for quick save/compile
            if (ImGui::IsWindowFocused(ImGuiFocusedFlags_RootAndChildWindows) && 
                ImGui::GetIO().KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_S))
            {
                CompileAndSave();
            }
        }
        else
        {
            ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "Select a shader from the list above to start editing.");
        }

        // Error log
        if (showCompilationError)
        {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Compilation Error Log:");
            ImGui::BeginChild("ErrorLog", ImVec2(-1, 0), true);
            ImGui::TextWrapped("%s", compilationError.c_str());
            ImGui::EndChild();
        }
    }
    ImGui::End();
}

void ShaderEditorWindow::LoadShaderResource(UID uid)
{
    selectedShaderUID = uid;
    ResourceShader* res = static_cast<ResourceShader*>(Application::GetInstance().resources->RequestResource(uid));
    if (res)
    {
        strncpy(shaderEditBuffer, res->GetSourceCode().c_str(), sizeof(shaderEditBuffer) - 1);
        showCompilationError = false;
        compilationError = "";
    }
}

void ShaderEditorWindow::CompileAndSave()
{
    if (selectedShaderUID == 0) return;

    ResourceShader* res = static_cast<ResourceShader*>(Application::GetInstance().resources->GetResourceDirect(selectedShaderUID));
    if (!res) return;

    // Update resource code
    std::string newSource = shaderEditBuffer;
    res->SetSourceCode(newSource);

    // Recompile
    if (res->Compile())
    {
        LOG_CONSOLE("[ShaderEditor] Shader %s compiled and applied successfully!", res->GetAssetFile());
        showCompilationError = false;
        
        // Persist to file
        std::ofstream file(res->GetAssetFile());
        if (file.is_open())
        {
            file << newSource;
            file.close();
        }
    }
    else
    {
        LOG_CONSOLE("[ShaderEditor] COMPILATION FAILED: %s", res->GetAssetFile());
        showCompilationError = true;
        compilationError = "Compilation failed. Check the console for OpenGL error details.";
    }
}
