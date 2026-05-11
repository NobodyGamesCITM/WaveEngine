#include "UI.h"
#include "ComponentCanvas.h"
#include <glad/glad.h>
#include "GLRenderDevice.h"
#include "Application.h"
#include "Time.h"
#include "ModuleEditor.h"
#include "imgui.h"
#include "NoesisPCH.h"
#include "NsCore/Noesis.h"
#include <NsCore/RegisterComponent.h>
#include <NsCore/Package.h>
#include "NsApp/LocalFontProvider.h"
#include "NsApp/LocalXamlProvider.h"
#include "NsApp/LocalTextureProvider.h"
#include <NsApp/EventTrigger.h>
#include <NsApp/GoToStateAction.h>
#include <NsApp/InvokeCommandAction.h>
#include <NsApp/Interaction.h>
#include "NsGui/IView.h"
#include "NsGui/FrameworkElement.h"
#include "NsGui/IntegrationAPI.h"
#include "NsGui/InputEnums.h"

extern "C" void NsRegisterReflectionAppInteractivity();
extern "C" void NsInitPackageAppInteractivity();
extern "C" void NsShutdownPackageAppInteractivity();

UI::UI() { LOG_DEBUG("UI Constructor"); }
UI::~UI() {}

bool UI::Start()
{
    Noesis::SetLogHandler([](const char*, uint32_t, uint32_t level, const char*, const char* msg)
        {
            const char* prefixes[] = { "T", "D", "I", "W", "E" };
            LOG_DEBUG("[NOESIS/%s] %s\n", prefixes[level], msg);
        });

    Noesis::GUI::SetLicense(NS_LICENSE_NAME, NS_LICENSE_KEY);
    Noesis::GUI::Init();
    NsRegisterReflectionAppInteractivity();
    NsInitPackageAppInteractivity();

    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    std::filesystem::path exeDir = std::filesystem::path(buffer).parent_path();

    auto assetsDir = exeDir / "Assets";
    if (!std::filesystem::exists(assetsDir))
        assetsDir = exeDir / "../../Assets";

    std::string xamlPath = (assetsDir / "UI").string();
    std::string fontPath = (assetsDir / "Fonts").string();
    std::string texturePath = (assetsDir / "UI").string();
    LOG_DEBUG("[UI] Font path: %s", fontPath.c_str());
    LOG_DEBUG("[UI] Texture path: %s", texturePath.c_str());

    Noesis::GUI::SetXamlProvider(Noesis::MakePtr<NoesisApp::LocalXamlProvider>(xamlPath.c_str()));
    Noesis::GUI::SetFontProvider(Noesis::MakePtr<NoesisApp::LocalFontProvider>(fontPath.c_str()));
    Noesis::GUI::SetTextureProvider(Noesis::MakePtr<NoesisApp::LocalTextureProvider>(texturePath.c_str()));

    renderDevice = Noesis::MakePtr<NoesisApp::GLRenderDevice>(false);

    return true;
}

bool UI::CleanUp()
{
    for (ComponentCanvas* c : canvas)
        c->CleanUp();
    canvas.clear();

    NsShutdownPackageAppInteractivity();
    Noesis::GUI::Shutdown();
    renderDevice.Reset();

    return true;
}

//Mouse input handling

void UI::SetMousePosition(int x, int y)
{
    mouseX = x;
    mouseY = y;
    for (ComponentCanvas* c : canvas)
        c->OnMouseMove(x, y);
}

static Noesis::MouseButton SDLMouseButtonToNoesis(int sdlButton)
{
    switch (sdlButton)
    {
    case SDL_BUTTON_LEFT:   return Noesis::MouseButton_Left;
    case SDL_BUTTON_RIGHT:  return Noesis::MouseButton_Right;
    case SDL_BUTTON_MIDDLE: return Noesis::MouseButton_Middle;
    default:                return Noesis::MouseButton_Left;
    }
}

void UI::OnMouseButtonDown(int x, int y, int sdlButton)
{
    for (ComponentCanvas* c : canvas)
        c->OnMouseButtonDown(x, y, SDLMouseButtonToNoesis(sdlButton));
}

void UI::OnMouseButtonUp(int x, int y, int sdlButton)
{
    for (ComponentCanvas* c : canvas)
        c->OnMouseButtonUp(x, y, SDLMouseButtonToNoesis(sdlButton));
}

void UI::OnMouseWheel(int x, int y, int delta)
{
    for (ComponentCanvas* c : canvas)
        c->OnMouseWheel(x, y, delta);
}

void UI::OnResize(uint32_t width, uint32_t height)
{
    for (ComponentCanvas* c : canvas)
        c->Resize((int)width, (int)height);
}


//Gamepad input handling
static Noesis::Key SDLGamepadButtonToNoesisKey(int sdlButton)
{
    switch (sdlButton)
    {
    case SDL_GAMEPAD_BUTTON_SOUTH:          return Noesis::Key_GamepadAccept;
    case SDL_GAMEPAD_BUTTON_EAST:           return Noesis::Key_GamepadCancel;
    case SDL_GAMEPAD_BUTTON_WEST:           return Noesis::Key_GamepadMenu;
    case SDL_GAMEPAD_BUTTON_NORTH:          return Noesis::Key_GamepadView;
    case SDL_GAMEPAD_BUTTON_DPAD_UP:        return Noesis::Key_GamepadUp;
    case SDL_GAMEPAD_BUTTON_DPAD_DOWN:      return Noesis::Key_GamepadDown;
    case SDL_GAMEPAD_BUTTON_DPAD_LEFT:      return Noesis::Key_GamepadLeft;
    case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:     return Noesis::Key_GamepadRight;
    case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:  return Noesis::Key_GamepadPageLeft;
    case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: return Noesis::Key_GamepadPageRight;
    case SDL_GAMEPAD_BUTTON_LEFT_STICK:     return Noesis::Key_GamepadPageUp;
    case SDL_GAMEPAD_BUTTON_RIGHT_STICK:    return Noesis::Key_GamepadPageDown;
    case SDL_GAMEPAD_BUTTON_START:          return Noesis::Key_GamepadContext1;
    case SDL_GAMEPAD_BUTTON_BACK:           return Noesis::Key_GamepadContext2;
    default:                                return Noesis::Key_None;
    }
}

void UI::OnGamepadButtonDown(int sdlButton)
{
    Noesis::Key key = SDLGamepadButtonToNoesisKey(sdlButton);
    if (key == Noesis::Key_None) return;
    for (ComponentCanvas* c : canvas)
        c->OnGamepadButtonDown(key);
}

void UI::OnGamepadButtonUp(int sdlButton)
{
    Noesis::Key key = SDLGamepadButtonToNoesisKey(sdlButton);
    if (key == Noesis::Key_None) return;
    for (ComponentCanvas* c : canvas)
        c->OnGamepadButtonUp(key);
}

void UI::OnGamepadLeftStick(float x, float y)
{
    for (ComponentCanvas* c : canvas)
        c->OnGamepadLeftStick(x, y);
}

void UI::OnGamepadRightStick(float x, float y)
{
    for (ComponentCanvas* c : canvas)
        c->OnGamepadRightStick(x, y);
}

void UI::OnGamepadTrigger(float left, float right)
{
    for (ComponentCanvas* c : canvas)
        c->OnGamepadTrigger(left, right);
}