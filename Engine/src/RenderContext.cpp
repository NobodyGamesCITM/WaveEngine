#include "RenderContext.h"
#include "RenderContext.h"
#include "Application.h"
#include <SDL3/SDL.h>
#include <glad/glad.h>
#include <iostream>

RenderContext::RenderContext() : glContext(nullptr)
{
    LOG_CONSOLE("RenderContext Constructor");
}

RenderContext::~RenderContext()
{
}

bool RenderContext::Start()
{
    LOG_CONSOLE("Init OpenGL Context & GLAD");

    SDL_Window* window = Application::GetInstance().window->GetWindow();
    glContext = SDL_GL_CreateContext(window);

    if (!glContext)
    {
        std::cerr << "Failed to create OpenGL context" << std::endl;
        return false;
    }
    
    if (SDL_GL_SetSwapInterval(0) != 0) {
        LOG_CONSOLE("Fallo al desactivar VSync: %s", SDL_GetError());
    }


    if (SDL_GL_SetSwapInterval(0) < 0)
    {
        LOG_DEBUG("Warning: No se pudo establecer el Swap Interval: %s", SDL_GetError());
    }

    if (!gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress))
    {
        std::cerr << "Failed to initialize GLAD" << std::endl;
        return false;
    }

    // Enable depth test
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    // Enable culling
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);

    return true;
}

bool RenderContext::PreUpdate()
{
    ZoneScopedNC("RenderContext::PreUpdate", 0x5B2C6F);
    // Clear buffers
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    return true;
}

bool RenderContext::Update()
{
    return true;
}

bool RenderContext::CleanUp()
{
    LOG_CONSOLE("Destroying OpenGL Context");

    if (glContext != nullptr)
    {
        SDL_GL_DestroyContext(glContext);
        glContext = nullptr;
    }

    return true;
}