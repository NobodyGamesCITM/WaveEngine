#include "Application.h"
#include "ModuleEvents.h"
#include "Window.h"
#include "UI.h"
#include <iostream>
#include <glad/glad.h>
#include "Log.h"

Window::Window() : window(nullptr), width(1280), height(720), scale(1)
{
   LOG_CONSOLE("Window Constructor");
}

Window::~Window()
{
}

bool Window::Start()
{
    LOG_DEBUG("=== Initializing Window Module ===");
    LOG_CONSOLE("Initializing SDL3 and OpenGL...");

    // Initialize SDL3
    if (!SDL_Init(SDL_INIT_VIDEO))
    {
        LOG_DEBUG("ERROR: SDL_Init failed - %s", SDL_GetError());
        LOG_CONSOLE("ERROR: Failed to initialize SDL3");
        return false;
    }

    // Set OpenGL version to 4.6
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);

    // Use the core OpenGL profile (modern functions only)
    // Particles System RGSEngine changed to compatibility so it allows glBegin/glEnd wich is much more modern version
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);

    // Enable double buffering to prevent flickering
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    // Set depth buffer to 24 bits for proper 3D rendering
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    int sdlVersion = SDL_GetVersion();
    int major = SDL_VERSIONNUM_MAJOR(sdlVersion);
    int minor = SDL_VERSIONNUM_MINOR(sdlVersion);
    int patch = SDL_VERSIONNUM_MICRO(sdlVersion);
    LOG_CONSOLE("SDL3 initialized - Version: %d.%d.%d", major, minor, patch);

    // Create window WITH OpenGL flag
#ifdef WAVE_GAME
    const char* windowTitle = "Son of Ithaca";
#else
    const char* windowTitle = "Wave Engine";
#endif
    window = SDL_CreateWindow(
        windowTitle,
        width,
        height,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
    );


    if (window == nullptr)
    {
        LOG_DEBUG("ERROR: Window creation failed - %s", SDL_GetError());
        LOG_CONSOLE("ERROR: Failed to create window");
        return false;
    }

    LOG_DEBUG("Window created successfully");
    LOG_CONSOLE("Window created: %dx%d with OpenGL", width, height);

    Application::GetInstance().events->Subscribe(Event::Type::WindowResize, this);
    return true;
}


bool Window::PostUpdate()
{
    ZoneScopedNC("Window::SwapBuffers", 0x626567);
    Render();
    return true;
}

void Window::Render()
{
    SDL_GL_SwapWindow(window);
}

bool Window::CleanUp()
{
    Application::GetInstance().events->UnsubscribeAll(this);
    LOG_DEBUG("Destroying SDL window");
    if (window != nullptr)
    {
        SDL_DestroyWindow(window);
        window = nullptr;
    }

    SDL_Quit();

    LOG_CONSOLE("Window closed");
    return true;
}

void Window::GetWindowSize(int& width, int& height) const
{
    SDL_GetWindowSize(window, &width, &height);
}

int Window::GetScale() const
{
    return scale;
}

void Window::SetResolution(int w, int h)
{
    width = w;
    height = h;

#ifdef WAVE_GAME
    if (window) {
        SDL_SetWindowSize(window, w, h);
    }
#endif

    // Notificamos manualmente al UI Manager para que redimensione los Canvases y sus FBOs
    // Esto asegura que el cambio de resolución se aplique internamente aunque la ventana física no cambie (ej. en Fullscreen Desktop)
    Application::GetInstance().ui->OnResize((uint32_t)width, (uint32_t)height);
}

void Window::SetFullscreen(bool enabled)
{
#ifdef WAVE_GAME
    if (window) {
        SDL_SetWindowFullscreen(window, enabled);
    }
#endif
}

void Window::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::WindowResize:
        glViewport(0, 0, event.data.point.x, event.data.point.y);
        Application::GetInstance().ui->OnResize(event.data.point.x, event.data.point.y);
        break;
    default:
        break;
    }
}
