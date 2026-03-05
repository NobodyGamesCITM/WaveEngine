#pragma once

#include "EditorWindow.h"
#include <imgui.h>

class GameWindow : public EditorWindow
{
public:
    GameWindow();

    void Draw() override;

    ImVec2 GetViewportPos() const { return gameViewportPos; }
    ImVec2 GetViewportSize() const { return gameViewportSize; }

private:
    void DispatchInputToCanvases();
    ImVec2 gameViewportPos;
    ImVec2 gameViewportSize;
};