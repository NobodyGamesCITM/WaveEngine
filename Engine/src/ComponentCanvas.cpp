#include "ComponentCanvas.h"
#include <glad/glad.h>
#include "GLRenderDevice.h"
#include "Application.h"
#include "Time.h"
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
#include <NsApp/GamepadTrigger.h>
#include "UIManager.h"
#include <NsGui/VisualTreeHelper.h>
#include <NsGui/Button.h>


ComponentCanvas::ComponentCanvas(GameObject* owner) : Component(owner, ComponentType::CANVAS)
{
    name = "Canvas";
    opacity = 1.0f;
    GenerateFramebuffer(width, height);
    Application::GetInstance().ui->RegisterCanvas(this);
    Application::GetInstance().renderer->AddCanvas(this);
    UIManager::GetInstance().RegisterCanvas(this);
}

ComponentCanvas::~ComponentCanvas()
{
    Application::GetInstance().ui->UnregisterCanvas(this); 
    Application::GetInstance().renderer->RemoveCanvas(this);
    UIManager::GetInstance().UnregisterCanvas(this); ;
    ShutdownView();               
    device.Reset();

    if (fbo)       glDeleteFramebuffers(1, &fbo);
    if (textureID) glDeleteTextures(1, &textureID);
    if (rbo)       glDeleteRenderbuffers(1, &rbo);
}

void ComponentCanvas::ShutdownView()
{
    if (!view) return;
    view->GetRenderer()->Shutdown();
    view.Reset();
    needsHookEvents = false;
    GLint prevFBO = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
}

void ComponentCanvas::CleanUp()
{
    ShutdownView();
    device.Reset();
}

static void HookEvents(Noesis::Visual* element) {

    if (!element) return;
    

    if (auto button = Noesis::DynamicCast<Noesis::Button*>(element)) {
        const char* name = button->GetName();
        
        if (name && strlen(name) > 0) {
            UIManager::GetInstance().RegisterButton(name);
            button->Click() += [](Noesis::BaseComponent* sender, const Noesis::RoutedEventArgs& args)
            {
                if (auto btn = Noesis::DynamicCast<Noesis::Button*>(sender)) {
                    //LOG_CONSOLE("[Canvas] Button Clicked: %s", btn->GetName());
                    UIManager::GetInstance().RegisterClickedButton(btn->GetName());
                }
            };
            
            button->GotFocus() += [](Noesis::BaseComponent* sender, const Noesis::RoutedEventArgs& args) {

                if (auto btn = Noesis::DynamicCast<Noesis::Button*>(sender)) {
                    //LOG_CONSOLE("[Canvas] Button Focused: %s", btn->GetName());
                    UIManager::GetInstance().RegisterFocusedButton(btn->GetName());
                }
            };
            
        }
    }

    uint32_t childCount = Noesis::VisualTreeHelper::GetChildrenCount(element);
    for (uint32_t i = 0; i < childCount; ++i) {
        Noesis::Visual* child = Noesis::VisualTreeHelper::GetChild(element, i);
        HookEvents(child);
    }
}

bool ComponentCanvas::LoadXAML(const char* filename)
{
    if (currentXAML == filename)
        return true;

    Noesis::Ptr<Noesis::FrameworkElement> xaml =
        Noesis::GUI::LoadXaml<Noesis::FrameworkElement>(filename);

    if (!xaml)
    {
        LOG_CONSOLE("[Canvas] '%s' is not a valid FrameworkElement XAML", filename);
        return false;
    }

    ShutdownView();
    view = Noesis::GUI::CreateView(xaml);

    if (!view)
    {
        LOG_CONSOLE("[Canvas] Failed to create view from: %s", filename);
        return false;
    }

    view->SetFlags(Noesis::RenderFlags_PPAA | Noesis::RenderFlags_LCD);
    view->SetSize(width, height);
    device = Application::GetInstance().ui->GetRenderDevice();
    view->GetRenderer()->Init(device);
    currentXAML = filename;
    view->Activate();
    UIManager::GetInstance().ClearCanvasButtons();
    needsHookEvents = true;
    return true;
}

void ComponentCanvas::Update()
{
    if (!view) return;
    double dt = Application::GetInstance().time->GetRealDeltaTime();
    view->Update(Application::GetInstance().time->GetTotalTime());

    if (needsHookEvents)
    {
        needsHookEvents = false;
        Noesis::FrameworkElement* root = view->GetContent();
        if (root) HookEvents(root);
    }

    const bool stickActive =
        (fabs(stickX) >= STICK_THRESHOLD || fabs(stickY) >= STICK_THRESHOLD);

    if (stickActive)
    {
        if (!stickInitialFired)
        {
            TryNavigateStick(stickX, stickY);
            stickInitialFired = true;
            stickRepeatTimer = 0.0;
        }
        else if (stickRepeatTimer < STICK_INITIAL_DELAY)
        {
            stickRepeatTimer += dt;
        }
        else
        {
            stickRepeatTimer += dt;
            // Fire repeat ticks for every elapsed STICK_REPEAT_RATE interval
            while (stickRepeatTimer >= STICK_INITIAL_DELAY + STICK_REPEAT_RATE)
            {
                TryNavigateStick(stickX, stickY);
                stickRepeatTimer -= STICK_REPEAT_RATE;
            }
        }
    }
    else
    {
        stickInitialFired = false;
        stickRepeatTimer = 0.0;
    }
}

void ComponentCanvas::RenderToTexture()
{
    if (!view) return;

    glPushAttrib(GL_ALL_ATTRIB_BITS);

    view->GetRenderer()->UpdateRenderTree();
    view->GetRenderer()->RenderOffscreen();

    GLint prevFBO = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);
    GLint prevViewport[4];
    glGetIntegerv(GL_VIEWPORT, prevViewport);

    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glViewport(0, 0, width, height);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

    view->GetRenderer()->Render();

    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
    glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3]);

    glPopAttrib();
}

void ComponentCanvas::Resize(int newWidth, int newHeight)
{
    if (width == newWidth && height == newHeight) return;

    width = newWidth;
    height = newHeight;

    if (view) view->SetSize(width, height);
    GenerateFramebuffer(width, height);
}

void ComponentCanvas::GenerateFramebuffer(int w, int h)
{
    if (fbo)       glDeleteFramebuffers(1, &fbo);
    if (textureID) glDeleteTextures(1, &textureID);
    if (rbo)       glDeleteRenderbuffers(1, &rbo);

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureID, 0);

    glGenRenderbuffers(1, &rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, w, h);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void ComponentCanvas::OnMouseMove(int x, int y)
{
    if (!view) return;
    view->MouseMove(x, y);
}

void ComponentCanvas::OnMouseButtonDown(int x, int y, Noesis::MouseButton button)
{
    if (!view) return;
    view->MouseButtonDown(x, y, button);
}

void ComponentCanvas::OnMouseButtonUp(int x, int y, Noesis::MouseButton button)
{
    if (!view) return;
    view->MouseButtonUp(x, y, button);
}

void ComponentCanvas::OnMouseWheel(int x, int y, int delta)
{
    if (!view) return;
    view->MouseWheel(x, y, delta);
}

void ComponentCanvas::OnGamepadButtonDown(Noesis::Key key)
{
    if (!view) return;
    view->KeyDown(key);
}

void ComponentCanvas::OnGamepadButtonUp(Noesis::Key key)
{
    if (!view) return;
    view->KeyUp(key);
}

void ComponentCanvas::OnGamepadLeftStick(float x, float y)
{
    stickX = x;
    stickY = y;

    const bool active = (fabs(x) >= STICK_THRESHOLD || fabs(y) >= STICK_THRESHOLD);
    if (!active)
    {
        stickInitialFired = false;
        stickRepeatTimer = 0.0;
    }
}

void ComponentCanvas::TryNavigateStick(float x, float y)
{
    if (!view) return;

    if (fabs(y) >= fabs(x))
    {
        if (y > STICK_THRESHOLD)
            view->KeyDown(Noesis::Key_GamepadDown);
        else
            view->KeyDown(Noesis::Key_GamepadUp);
    }
    else
    {
        if (x > STICK_THRESHOLD)
            view->KeyDown(Noesis::Key_GamepadRight);
        else
            view->KeyDown(Noesis::Key_GamepadLeft);
    }
}

void ComponentCanvas::OnGamepadRightStick(float x, float y)
{
    (void)x; (void)y;
}

void ComponentCanvas::OnGamepadTrigger(float left, float right)
{
    if (!view) return;

    static bool ltWasDown = false;
    static bool rtWasDown = false;

    const float TRIGGER_THRESHOLD = 0.5f;

    if (left >= TRIGGER_THRESHOLD && !ltWasDown)
    {
        view->KeyDown(Noesis::Key_GamepadPageLeft);
        ltWasDown = true;
    }
    else if (left < TRIGGER_THRESHOLD && ltWasDown)
    {
        view->KeyUp(Noesis::Key_GamepadPageLeft);
        ltWasDown = false;
    }

    if (right >= TRIGGER_THRESHOLD && !rtWasDown)
    {
        view->KeyDown(Noesis::Key_GamepadPageRight);
        rtWasDown = true;
    }
    else if (right < TRIGGER_THRESHOLD && rtWasDown)
    {
        view->KeyUp(Noesis::Key_GamepadPageRight);
        rtWasDown = false;
    }
}

void ComponentCanvas::Serialize(nlohmann::json& componentObj) const
{
    componentObj["xamlPath"] = currentXAML;
    componentObj["opacity"] = opacity;
    componentObj["uiLayer"] = uiLayer;

}

void ComponentCanvas::Deserialize(const nlohmann::json& componentObj)
{
    if (componentObj.contains("opacity"))
        opacity = componentObj["opacity"];

    if (componentObj.contains("xamlPath"))
    {
        std::string path = componentObj["xamlPath"];
        if (!path.empty())
            LoadXAML(path.c_str());
    }

    uiLayer = componentObj.value("uiLayer", 0);
}

void ComponentCanvas::UnloadXAML()
{
    ShutdownView();
    currentXAML = "";
}

void ComponentCanvas::SetOpacity(float alpha)
{
    opacity = std::clamp(alpha, 0.0f, 1.0f);
}

float ComponentCanvas::GetOpacity() const
{
    return opacity;

}