#pragma once

#include "EditorWindow.h" 

class ConsoleWindow : public EditorWindow
{
public:
    ConsoleWindow();
    ~ConsoleWindow() override = default;

    void Draw() override;
    void FlashError();

private:

    bool showErrors = true;
    bool showWarnings = true;
    bool showInfo = true;

    bool autoScroll = true;
    bool scrollToBottom = false;

    float errorFlashTimer = 0.0f;
    static constexpr float FLASH_DURATION = 2.0f;
};