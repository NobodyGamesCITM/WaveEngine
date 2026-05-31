#pragma once

#include <SDL3/SDL_init.h>       // SDL_Init, SDL_Quit
#include <SDL3/SDL_error.h>      // SDL_GetError
#include <SDL3/SDL.H>
#include "Module.h"
#include "EventListener.h"

class Window : public Module, public EventListener
{
public:
    Window();
    ~Window();

    bool Start() override; 

    // Clear screen and present
    void Render();

    bool PostUpdate() override;

    // Clean up resources
    bool CleanUp() override;

    // Getters
    void GetWindowSize(int& width, int& height) const;
    int GetScale() const;
    void SetResolution(int width, int height);
    void SetFullscreen(bool enabled);

    SDL_Window* GetWindow() const { return window; }

    void OnEvent(const Event& event);

private:
    SDL_Window* window;
    //SDL_Renderer* renderer;

    int width;
    int height;
    int scale;
};