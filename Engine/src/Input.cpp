#include "Input.h"
#include "Application.h"
#include "Globals.h"
#include "ModuleEvents.h"

#include "Log.h"
#include "glm/glm.hpp"

#include <algorithm>
#include <SDL3/SDL_scancode.h>

#include "ComponentCanvas.h"
#include "GameObject.h"
#include "ModuleScene.h"
#include "NsGui/InputEnums.h"
#include <SDL3/SDL_mouse.h>

#ifndef WAVE_GAME
#include "ModuleEditor.h"
#include "GameWindow.h"
#include <imgui.h>
#endif

Input::Input() : Module()
{
    name = "input";
    keyboard = new KeyState[MAX_KEYS];
    memset(keyboard, KEY_IDLE, sizeof(KeyState) * MAX_KEYS);
    memset(mouseButtons, KEY_IDLE, sizeof(KeyState) * NUM_MOUSE_BUTTONS);
}

Input::~Input()
{
    // keyboard is now deleted in CleanUp()
}

bool Input::Awake()
{
    return true;
}

bool Input::Start()
{
    if (SDL_InitSubSystem(SDL_INIT_EVENTS) == false)
    {
        LOG_DEBUG("SDL_INIT_EVENTS failed: %s", SDL_GetError());
        return false;
    }

    if (SDL_InitSubSystem(SDL_INIT_GAMEPAD) == false)
    {
        LOG_DEBUG("[Input] WARNING: SDL_INIT_GAMEPAD failed: %s � gamepad support disabled", SDL_GetError());
        // Prevent crash: Keyboard and mouse still work
    }
    else
    {
        // list gamepads already connected before the engine started
        int count = 0;
        SDL_JoystickID* ids = SDL_GetGamepads(&count);
        if (ids)
        {
            for (int i = 0; i < count; ++i)
                OnGamepadAdded(ids[i]);
            SDL_free(ids);
        }
        LOG_DEBUG("[Input] Gamepad subsystem ready. Controllers connected: %d", static_cast<int>(gamepads.size()));
    }

    scale = 1;
    return true;
}

static Noesis::Key SDLScancodeToNoesisKey(SDL_Scancode sc)
{
    switch (sc)
    {
        // Navigation / UI keys
    case SDL_SCANCODE_RETURN:       return Noesis::Key_Return;
    case SDL_SCANCODE_RETURN2:      return Noesis::Key_Return;
    case SDL_SCANCODE_KP_ENTER:     return Noesis::Key_Return;
    case SDL_SCANCODE_ESCAPE:       return Noesis::Key_Escape;
    case SDL_SCANCODE_SPACE:        return Noesis::Key_Space;
    case SDL_SCANCODE_BACKSPACE:    return Noesis::Key_Back;
    case SDL_SCANCODE_DELETE:       return Noesis::Key_Delete;
    case SDL_SCANCODE_TAB:          return Noesis::Key_Tab;

        // Arrow keys
    case SDL_SCANCODE_UP:           return Noesis::Key_Up;
    case SDL_SCANCODE_DOWN:         return Noesis::Key_Down;
    case SDL_SCANCODE_LEFT:         return Noesis::Key_Left;
    case SDL_SCANCODE_RIGHT:        return Noesis::Key_Right;

        // Page / Home / End
    case SDL_SCANCODE_HOME:         return Noesis::Key_Home;
    case SDL_SCANCODE_END:          return Noesis::Key_End;
    case SDL_SCANCODE_PAGEUP:       return Noesis::Key_PageUp;
    case SDL_SCANCODE_PAGEDOWN:     return Noesis::Key_PageDown;

        // Modifiers
    case SDL_SCANCODE_LSHIFT:       return Noesis::Key_LeftShift;
    case SDL_SCANCODE_RSHIFT:       return Noesis::Key_RightShift;
    case SDL_SCANCODE_LCTRL:        return Noesis::Key_LeftCtrl;
    case SDL_SCANCODE_RCTRL:        return Noesis::Key_RightCtrl;
    case SDL_SCANCODE_LALT:         return Noesis::Key_LeftAlt;
    case SDL_SCANCODE_RALT:         return Noesis::Key_RightAlt;

        // Alphabet
    case SDL_SCANCODE_A: return Noesis::Key_A; case SDL_SCANCODE_B: return Noesis::Key_B;
    case SDL_SCANCODE_C: return Noesis::Key_C; case SDL_SCANCODE_D: return Noesis::Key_D;
    case SDL_SCANCODE_E: return Noesis::Key_E; case SDL_SCANCODE_F: return Noesis::Key_F;
    case SDL_SCANCODE_G: return Noesis::Key_G; case SDL_SCANCODE_H: return Noesis::Key_H;
    case SDL_SCANCODE_I: return Noesis::Key_I; case SDL_SCANCODE_J: return Noesis::Key_J;
    case SDL_SCANCODE_K: return Noesis::Key_K; case SDL_SCANCODE_L: return Noesis::Key_L;
    case SDL_SCANCODE_M: return Noesis::Key_M; case SDL_SCANCODE_N: return Noesis::Key_N;
    case SDL_SCANCODE_O: return Noesis::Key_O; case SDL_SCANCODE_P: return Noesis::Key_P;
    case SDL_SCANCODE_Q: return Noesis::Key_Q; case SDL_SCANCODE_R: return Noesis::Key_R;
    case SDL_SCANCODE_S: return Noesis::Key_S; case SDL_SCANCODE_T: return Noesis::Key_T;
    case SDL_SCANCODE_U: return Noesis::Key_U; case SDL_SCANCODE_V: return Noesis::Key_V;
    case SDL_SCANCODE_W: return Noesis::Key_W; case SDL_SCANCODE_X: return Noesis::Key_X;
    case SDL_SCANCODE_Y: return Noesis::Key_Y; case SDL_SCANCODE_Z: return Noesis::Key_Z;

        // Numbers
    case SDL_SCANCODE_0: return Noesis::Key_D0; case SDL_SCANCODE_1: return Noesis::Key_D1;
    case SDL_SCANCODE_2: return Noesis::Key_D2; case SDL_SCANCODE_3: return Noesis::Key_D3;
    case SDL_SCANCODE_4: return Noesis::Key_D4; case SDL_SCANCODE_5: return Noesis::Key_D5;
    case SDL_SCANCODE_6: return Noesis::Key_D6; case SDL_SCANCODE_7: return Noesis::Key_D7;
    case SDL_SCANCODE_8: return Noesis::Key_D8; case SDL_SCANCODE_9: return Noesis::Key_D9;

        // Function keys
    case SDL_SCANCODE_F1:  return Noesis::Key_F1;  case SDL_SCANCODE_F2:  return Noesis::Key_F2;
    case SDL_SCANCODE_F3:  return Noesis::Key_F3;  case SDL_SCANCODE_F4:  return Noesis::Key_F4;
    case SDL_SCANCODE_F5:  return Noesis::Key_F5;  case SDL_SCANCODE_F6:  return Noesis::Key_F6;
    case SDL_SCANCODE_F7:  return Noesis::Key_F7;  case SDL_SCANCODE_F8:  return Noesis::Key_F8;
    case SDL_SCANCODE_F9:  return Noesis::Key_F9;  case SDL_SCANCODE_F10: return Noesis::Key_F10;
    case SDL_SCANCODE_F11: return Noesis::Key_F11; case SDL_SCANCODE_F12: return Noesis::Key_F12;

    default: return Noesis::Key_None;
    }
}

static Noesis::MouseButton SDLMouseButtonToNoesis(Uint8 sdlBtn)
{
    switch (sdlBtn)
    {
    case SDL_BUTTON_LEFT:   return Noesis::MouseButton_Left;
    case SDL_BUTTON_RIGHT:  return Noesis::MouseButton_Right;
    case SDL_BUTTON_MIDDLE: return Noesis::MouseButton_Middle;
    case SDL_BUTTON_X1:     return Noesis::MouseButton_XButton1;
    case SDL_BUTTON_X2:     return Noesis::MouseButton_XButton2;
    default:                return Noesis::MouseButton_Left;
    }
}

static Noesis::Key GamepadButtonToNoesisKey(GamepadButton btn)
{
    switch (btn)
    {
    case GP_SOUTH:          return Noesis::Key_GamepadAccept;
    case GP_EAST:           return Noesis::Key_GamepadCancel;
    case GP_WEST:           return Noesis::Key_GamepadView;
    case GP_NORTH:          return Noesis::Key_GamepadMenu;
    case GP_START:          return Noesis::Key_GamepadMenu;
    case GP_BACK:           return Noesis::Key_GamepadView;
    case GP_DPAD_UP:        return Noesis::Key_GamepadUp;
    case GP_DPAD_DOWN:      return Noesis::Key_GamepadDown;
    case GP_DPAD_LEFT:      return Noesis::Key_GamepadLeft;
    case GP_DPAD_RIGHT:     return Noesis::Key_GamepadRight;
    case GP_LEFT_SHOULDER:  return Noesis::Key_GamepadPageLeft;
    case GP_RIGHT_SHOULDER: return Noesis::Key_GamepadPageRight;
    default:                return Noesis::Key_None;
    }
}

static void DispatchInputToCanvases(Input* input)
{
    if (!Application::GetInstance().scene) return;
    GameObject* root = Application::GetInstance().scene->GetRoot();
    if (!root) return;

    std::vector<Component*> canvasComps;
    root->GetComponentsInChildren(ComponentType::CANVAS, canvasComps);

    std::vector<ComponentCanvas*> canvases;
    for (Component* c : canvasComps)
    {
        ComponentCanvas* canvas = static_cast<ComponentCanvas*>(c);
        if (canvas && canvas->IsActive() && canvas->GetOwner()->IsActive())
            canvases.push_back(canvas);
    }

    if (canvases.empty()) return;

    // Mouse
    glm::vec2 mPos = input->GetMousePosition();
    int mx = static_cast<int>(mPos.x);
    int my = static_cast<int>(mPos.y);

#ifndef WAVE_GAME
    if (Application::GetInstance().editor)
    {
        GameWindow* gw = Application::GetInstance().editor->GetGameWindow();
        if (gw)
        {
            ImVec2 vPos = gw->GetViewportPos();
            mx -= static_cast<int>(vPos.x);
            my -= static_cast<int>(vPos.y);
        }
    }
#endif

    for (ComponentCanvas* canvas : canvases)
    {
        canvas->OnMouseMove(mx, my);
    }

    for (int btn = 1; btn <= NUM_MOUSE_BUTTONS; ++btn)
    {
        KeyState state = input->GetMouseButtonDown(btn);
        Noesis::MouseButton nsBtn = SDLMouseButtonToNoesis(static_cast<Uint8>(btn));

        if (state == KEY_DOWN)
            for (ComponentCanvas* canvas : canvases)
                canvas->OnMouseButtonDown(mx, my, nsBtn);
        else if (state == KEY_UP)
            for (ComponentCanvas* canvas : canvases)
                canvas->OnMouseButtonUp(mx, my, nsBtn);
    }

    // Mouse wheel
    float wheel = input->GetMouseWheelY();
    if (wheel != 0.0f)
    {
        int delta = static_cast<int>(wheel * 120);
        for (ComponentCanvas* canvas : canvases)
            canvas->OnMouseWheel(mx, my, delta);
    }

    // Keyboard
    for (int sc = 0; sc < MAX_KEYS; ++sc)
    {
        KeyState ks = input->GetKey(sc);
        if (ks == KEY_IDLE || ks == KEY_REPEAT) continue;

        Noesis::Key nsKey = SDLScancodeToNoesisKey(static_cast<SDL_Scancode>(sc));
        if (nsKey == Noesis::Key_None) continue;

        if (ks == KEY_DOWN)
            for (ComponentCanvas* canvas : canvases)
                canvas->OnKeyDown(nsKey);
        else if (ks == KEY_UP)
            for (ComponentCanvas* canvas : canvases)
                canvas->OnKeyUp(nsKey);
    }

    // Gamepad
    if (input->HasGamepad())
    {
        const GamepadButton allButtons[] = {
            GP_SOUTH, GP_EAST, GP_WEST, GP_NORTH,
            GP_BACK, GP_START,
            GP_LEFT_SHOULDER, GP_RIGHT_SHOULDER,
            GP_DPAD_UP, GP_DPAD_DOWN, GP_DPAD_LEFT, GP_DPAD_RIGHT
        };

        for (GamepadButton btn : allButtons)
        {
            KeyState ks = input->GetGamepadButton(btn, 0);
            Noesis::Key nsKey = GamepadButtonToNoesisKey(btn);
            if (nsKey == Noesis::Key_None) continue;

            if (ks == KEY_DOWN)
                for (ComponentCanvas* canvas : canvases)
                    canvas->OnKeyDown(nsKey);
            else if (ks == KEY_UP)
                for (ComponentCanvas* canvas : canvases)
                    canvas->OnKeyUp(nsKey);
        }

        glm::vec2 ls = input->GetLeftStick(0);
        for (ComponentCanvas* canvas : canvases)
            canvas->OnGamepadLeftStick(ls.x, ls.y);

        glm::vec2 rs = input->GetRightStick(0);
        for (ComponentCanvas* canvas : canvases)
            canvas->OnGamepadRightStick(rs.x, rs.y);

        float lt = input->GetGamepadAxis(GP_AXIS_LEFT_TRIGGER, 0);
        float rt = input->GetGamepadAxis(GP_AXIS_RIGHT_TRIGGER, 0);
        for (ComponentCanvas* canvas : canvases)
            canvas->OnGamepadTrigger(lt, rt);
    }
}

bool Input::PreUpdate()
{
    static SDL_Event event;
    int numKeys;
    const bool* keys = SDL_GetKeyboardState(&numKeys);
    mouseWheelY = 0;

    for (int i = 0; i < MAX_KEYS && i < numKeys; ++i)
    {
        if (keys[i] == 1)
        {
            if (keyboard[i] == KEY_IDLE)
                keyboard[i] = KEY_DOWN;
            else
                keyboard[i] = KEY_REPEAT;
        }
        else
        {
            if (keyboard[i] == KEY_REPEAT || keyboard[i] == KEY_DOWN)
                keyboard[i] = KEY_UP;
            else
                keyboard[i] = KEY_IDLE;
        }
    }

    for (int i = 0; i < NUM_MOUSE_BUTTONS; ++i)
    {
        if (mouseButtons[i] == KEY_DOWN)
            mouseButtons[i] = KEY_REPEAT;

        if (mouseButtons[i] == KEY_UP)
            mouseButtons[i] = KEY_IDLE;
    }

    SDL_StartTextInput(Application::GetInstance().window->GetWindow());

    while (SDL_PollEvent(&event) != 0)
    {
        Application::GetInstance().events->PublishImmediate(Event(Event::Type::EventSDL, &event));

        switch (event.type)
        {
        case SDL_EVENT_QUIT:
            windowEvents[WE_QUIT] = true;
            break;

        case SDL_EVENT_WINDOW_HIDDEN:
        case SDL_EVENT_WINDOW_MINIMIZED:
        case SDL_EVENT_WINDOW_FOCUS_LOST:
            windowEvents[WE_HIDE] = true;
            break;

        case SDL_EVENT_WINDOW_SHOWN:
        case SDL_EVENT_WINDOW_FOCUS_GAINED:
        case SDL_EVENT_WINDOW_MAXIMIZED:
            break;
        case SDL_EVENT_WINDOW_RESTORED:
            windowEvents[WE_SHOW] = true;
            break;
        case SDL_EVENT_WINDOW_RESIZED:
            Application::GetInstance().events->PublishImmediate(Event(Event::Type::WindowResize, event.window.data1, event.window.data2));
            windowEvents[WE_SHOW] = true;
            break;

        case SDL_EVENT_MOUSE_BUTTON_DOWN:
            mouseButtons[event.button.button - 1] = KEY_DOWN;
            break;

        case SDL_EVENT_MOUSE_BUTTON_UP:
            mouseButtons[event.button.button - 1] = KEY_UP;
            break;

        case SDL_EVENT_MOUSE_MOTION:
        {
            mouseMotionX = event.motion.xrel / scale;
            mouseMotionY = event.motion.yrel / scale;
            mouseX = event.motion.x / scale;
            mouseY = event.motion.y / scale;
        }
        break;

        case SDL_EVENT_MOUSE_WHEEL:
            mouseWheelY = event.wheel.y;
            break;

        case SDL_EVENT_DROP_FILE:
        {
            const char* filePath = event.drop.data;
            LOG_DEBUG("File dropped in window: %s", filePath);

            std::string filePathStr(filePath);
            std::string extension = filePathStr.substr(filePathStr.find_last_of(".") + 1);

            Application::GetInstance().events->PublishImmediate(Event(Event::Type::FileDropped, filePath));
        }
        break;

        // Gamepad hot-plug while running
        case SDL_EVENT_GAMEPAD_ADDED:
            OnGamepadAdded(event.gdevice.which);
            break;

        case SDL_EVENT_GAMEPAD_REMOVED:
            OnGamepadRemoved(event.gdevice.which);
            break;
        }
    }

    UpdateGamepadStates();

    DispatchInputToCanvases(this);

    return true;
}

bool Input::CleanUp()
{
    LOG_DEBUG("Quitting SDL event subsystem");

    for (auto& gp : gamepads)
        if (gp.handle) SDL_CloseGamepad(gp.handle);
    gamepads.clear();

    SDL_QuitSubSystem(SDL_INIT_GAMEPAD);
    SDL_QuitSubSystem(SDL_INIT_EVENTS);

    delete[] keyboard;
    keyboard = nullptr;

    return true;
}

bool Input::GetWindowEvent(EventWindow ev)
{
    return windowEvents[ev];
}

glm::vec2 Input::GetMousePosition()
{
    return glm::vec2(mouseX, mouseY);
}

glm::vec2 Input::GetMouseMotion()
{
    return glm::vec2(mouseMotionX, mouseMotionY);
}

float Input::GetMouseWheelY()
{
    return mouseWheelY;
}

// Check how many gamepads connected and assign index
int Input::FindGamepadIndex(SDL_JoystickID id) const
{
    for (int i = 0; i < static_cast<int>(gamepads.size()); ++i)
        if (gamepads[i].instanceId == id) return i;
    return -1;
}

// Hot-plug gamepad behaviour
void Input::OnGamepadAdded(SDL_JoystickID id)
{
    if (FindGamepadIndex(id) != -1) return;

    SDL_Gamepad* handle = SDL_OpenGamepad(id);
    if (!handle)
    {
        LOG_DEBUG("[Input] WARNING: SDL_OpenGamepad(id=%d) failed: %s", id, SDL_GetError());
        return;
    }

    GamepadState gs;
    gs.handle = handle;
    gs.instanceId = id;
    gs.connected = true;

    const char* rawName = SDL_GetGamepadName(handle);
    gs.name = rawName ? rawName : "Unknown Gamepad";

    gamepads.push_back(gs);
    LOG_DEBUG("[Input] Gamepad connected [%d]: %s", static_cast<int>(gamepads.size()), gs.name.c_str());
}

void Input::OnGamepadRemoved(SDL_JoystickID id)
{
    int idx = FindGamepadIndex(id);
    if (idx == -1) return; // late or duplicate event, ignore and keep the index 1

    GamepadState& gp = gamepads[idx];
    gp.FlushToIdle(); // send scripts one frame of KEY_UP before removal of the gamepad to prevent false gamepads inputs
    gp.connected = false;

    LOG_DEBUG("[Input] Gamepad disconnected: %s (id=%d)", gp.name.c_str(), id);

    if (gp.handle) { SDL_CloseGamepad(gp.handle); gp.handle = nullptr; }

    if (idx != static_cast<int>(gamepads.size()) - 1)
        std::swap(gamepads[idx], gamepads.back());
    gamepads.pop_back();

    LOG_DEBUG("[Input] Gamepads remaining: %d", static_cast<int>(gamepads.size()));
}

void Input::PurgeInvalidGamepads()
{
    for (int i = static_cast<int>(gamepads.size()) - 1; i >= 0; --i)
    {
        GamepadState& gp = gamepads[i];
        bool invalid = !gp.handle || !SDL_GamepadConnected(gp.handle);

        if (invalid)
        {
            LOG_DEBUG("[Input] Purging stale gamepad: %s", gp.name.c_str());
            gp.FlushToIdle();
            if (gp.handle) { SDL_CloseGamepad(gp.handle); gp.handle = nullptr; }
            if (i != static_cast<int>(gamepads.size()) - 1)
                std::swap(gamepads[i], gamepads.back());
            gamepads.pop_back();
        }
    }
}

// Gamepad  dead zone to prevent drifting
float Input::ApplyDeadZone(float value) const
{
    if (value > -GAMEPAD_DEAD_ZONE && value < GAMEPAD_DEAD_ZONE) return 0.0f;
    float sign = value > 0.0f ? 1.0f : -1.0f;
    return sign * (std::abs(value) - GAMEPAD_DEAD_ZONE) / (1.0f - GAMEPAD_DEAD_ZONE);
}

// Gamepad events update
void Input::UpdateGamepadStates()
{
    PurgeInvalidGamepads();

    for (auto& gp : gamepads)
    {
        if (!gp.handle || !gp.connected) continue;

        // Buttons work the same KEY_IDLE/DOWN/REPEAT/UP state event as keyboard
        for (int b = 0; b < GP_BUTTON_COUNT; ++b)
        {
            bool held = SDL_GetGamepadButton(gp.handle, static_cast<SDL_GamepadButton>(b));
            KeyState& s = gp.buttons[b];
            if (held)
                s = (s == KEY_IDLE || s == KEY_UP) ? KEY_DOWN : KEY_REPEAT;
            else
                s = (s == KEY_DOWN || s == KEY_REPEAT) ? KEY_UP : KEY_IDLE;
        }

        // Axes is different because SDL3 returns Sint16 number between -32768 and 32767
        // So its normalized by code to -1 and 1 then apply the dead zone
        for (int a = 0; a < GP_AXIS_COUNT; ++a)
        {
            Sint16 raw = SDL_GetGamepadAxis(gp.handle, static_cast<SDL_GamepadAxis>(a));
            float  norm = (raw < 0) ? (raw / 32768.0f) : (raw / 32767.0f);
            gp.axes[a] = ApplyDeadZone(norm);
        }
    }
}

// Gamepad api call
KeyState Input::GetGamepadButton(GamepadButton btn, int idx) const
{
    if (idx < 0 || idx >= static_cast<int>(gamepads.size())) return KEY_IDLE;
    int b = static_cast<int>(btn);
    if (b < 0 || b >= GP_BUTTON_COUNT) return KEY_IDLE;
    return gamepads[idx].buttons[b];
}

// Gamepad checks
bool Input::IsGamepadButtonPressed(GamepadButton btn, int idx) const
{
    KeyState s = GetGamepadButton(btn, idx);
    return s == KEY_DOWN || s == KEY_REPEAT;
}

bool Input::IsGamepadButtonDown(GamepadButton btn, int idx) const
{
    return GetGamepadButton(btn, idx) == KEY_DOWN;
}

bool Input::IsGamepadButtonUp(GamepadButton btn, int idx) const
{
    return GetGamepadButton(btn, idx) == KEY_UP;
}

float Input::GetGamepadAxis(GamepadAxis axis, int idx) const
{
    if (idx < 0 || idx >= static_cast<int>(gamepads.size())) return 0.0f;
    int a = static_cast<int>(axis);
    if (a < 0 || a >= GP_AXIS_COUNT) return 0.0f;
    return gamepads[idx].axes[a];
}

glm::vec2 Input::GetLeftStick(int idx) const
{
    return { GetGamepadAxis(GP_AXIS_LEFT_X, idx), GetGamepadAxis(GP_AXIS_LEFT_Y, idx) };
}

glm::vec2 Input::GetRightStick(int idx) const
{
    return { GetGamepadAxis(GP_AXIS_RIGHT_X, idx), GetGamepadAxis(GP_AXIS_RIGHT_Y, idx) };
}

// Gamepad rumble vibration
static Uint16 FloatToRumble(float v)
{
    if (v <= 0.0f) return 0;
    if (v >= 1.0f) return 65535;
    return static_cast<Uint16>(v * 65535.0f);
}

void Input::RumbleGamepad(float lowFreq, float highFreq, Uint32 durationMs, int idx)
{
    if (idx < 0 || idx >= static_cast<int>(gamepads.size())) return;
    GamepadState& gp = gamepads[idx];
    if (!gp.handle || !gp.connected) return;

    Uint16 low = FloatToRumble(lowFreq);
    Uint16 high = FloatToRumble(highFreq);

    if (!SDL_RumbleGamepad(gp.handle, low, high, durationMs))
        LOG_DEBUG("[Input] WARNING: Rumble not supported on '%s': %s", gp.name.c_str(), SDL_GetError());
}

void Input::StopRumble(int idx)
{
    if (idx < 0 || idx >= static_cast<int>(gamepads.size())) return;
    GamepadState& gp = gamepads[idx];
    if (!gp.handle || !gp.connected) return;
    SDL_RumbleGamepad(gp.handle, 0, 0, 0);
}