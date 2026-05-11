#pragma once

#include <string>

// Base class for all editor windows
class EditorWindow
{
public:
    EditorWindow(const std::string& windowName)
        : name(windowName), isOpen(true), isHovered(false) {
    }

    virtual ~EditorWindow() = default;

    virtual void Draw() = 0;

    void SetOpen(bool open) { isOpen = open; }
    bool IsOpen() const { return isOpen; }
    const std::string& GetName() const { return name; }
    bool IsHovered() const { return isHovered; }
    bool IsFocused() const { return isFocused; }

protected:
    std::string name;
    bool isOpen;
    bool isHovered;
    bool isFocused;
};