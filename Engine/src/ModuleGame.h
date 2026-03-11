#pragma once
#include "Module.h"
#include "EventListener.h"
#include <glad/glad.h>

class ModuleGame : public Module, public EventListener
{
public:
    ModuleGame();
    ~ModuleGame();

    bool Start() override;
    bool PostUpdate() override;
    bool CleanUp() override;

    void OnEvent(const Event& event) override;

private:
    void HandleViewportResize(int width, int height);
};