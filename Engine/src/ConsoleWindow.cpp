#include "Application.h"
#include "Time.h"
#include "ConsoleWindow.h"
#include <imgui.h>
#include "Log.h"
#include <cmath> // Para std::sin
// Asumo que tienes una clase Time o similar. Si no, usa tu método habitual.
// #include "Time.h" 

ConsoleWindow::ConsoleWindow()
    : EditorWindow("Console") // O UIWindow, según lo tengas en tu arquitectura
{
}

void ConsoleWindow::FlashError()
{
    errorFlashTimer = FLASH_DURATION;
}

void ConsoleWindow::Draw()
{
    if (!isOpen) return;


    if (errorFlashTimer > 0.0f)
    {
        errorFlashTimer -= Time::GetDeltaTimeStatic();
        if (errorFlashTimer < 0.0f)
            errorFlashTimer = 0.0f;
    }

    bool hasError = errorFlashTimer > 0.0f;
    if (hasError)
    {
        float intensity = (std::sin(errorFlashTimer * 8.0f) * 0.5f + 0.5f) * 0.3f;
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0.5f + intensity, 0.1f, 0.1f, 1.0f));
    }

    ImGui::Begin(name.c_str(), &isOpen, ImGuiWindowFlags_MenuBar);

    if (hasError)
    {
        ImGui::PopStyleColor();
    }

    if (ImGui::Button("Clear"))
    {
        ConsoleLog::GetInstance().Clear();
        errorFlashTimer = 0.0f;
    }

    ImGui::SameLine();
    ImGui::Checkbox("Errors", &showErrors);
    ImGui::SameLine();
    ImGui::Checkbox("Warnings", &showWarnings);
    ImGui::SameLine();
    ImGui::Checkbox("Info", &showInfo);
    ImGui::SameLine();
    ImGui::Checkbox("Auto-scroll", &autoScroll);

    ImGui::Separator();

    ImVec2 availableSpace = ImGui::GetContentRegionAvail();
    ImGui::BeginChild("Scrolling", availableSpace, true, ImGuiWindowFlags_HorizontalScrollbar);

    if (ImGui::BeginTable("ConsoleTable", 2, ImGuiTableFlags_RowBg | ImGuiTableFlags_Resizable))
    {
        ImGui::TableSetupColumn("Message", ImGuiTableColumnFlags_WidthStretch);
        ImGui::TableSetupColumn("Count", ImGuiTableColumnFlags_WidthFixed, 40.0f);

        const std::vector<LogInfo>& logs = ConsoleLog::GetInstance().GetLogs();

        for (const auto& log : logs)
        {
            if (log.type == LogType::LOG_INFO && !showInfo) continue;
            if (log.type == LogType::LOG_WARNING && !showWarnings) continue;
            if (log.type == LogType::LOG_ERROR && !showErrors) continue;

            ImGui::TableNextRow();
            ImGui::TableSetColumnIndex(0);

            ImVec4 textColor = { 1.0f, 1.0f, 1.0f, 1.0f };
            if (log.type == LogType::LOG_WARNING) textColor = { 1.0f, 1.0f, 0.0f, 1.0f };
            if (log.type == LogType::LOG_ERROR)   textColor = { 1.0f, 0.4f, 0.4f, 1.0f };

            ImGui::PushStyleColor(ImGuiCol_Text, textColor);
            ImGui::TextWrapped("%s", log.message.c_str());
            ImGui::PopStyleColor();

            if (log.count > 1)
            {
                ImGui::TableSetColumnIndex(1);
                ImGui::TextDisabled("%d", log.count);
            }
        }

        ImGui::EndTable();
    }

    if (autoScroll && ImGui::GetScrollY() >= ImGui::GetScrollMaxY())
    {
        ImGui::SetScrollHereY(1.0f);
    }

    if (scrollToBottom)
    {
        ImGui::SetScrollHereY(1.0f);
        scrollToBottom = false;
    }

    ImGui::EndChild();
    ImGui::End();
}