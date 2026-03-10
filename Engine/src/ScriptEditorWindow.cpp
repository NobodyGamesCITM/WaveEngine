#include "ScriptEditorWindow.h"
#include <imgui.h>
#include <fstream>
#include <sstream>
#include <cctype>
#include <filesystem>
#include "Log.h"

ScriptEditorWindow::ScriptEditorWindow()
    : EditorWindow("Script Editor")
{
    isOpen = false;
    InitializeLuaKeywords();

    colorKeyword = ImVec4(0.98f, 0.45f, 0.45f, 1.0f);
    colorFunction = ImVec4(0.4f, 0.85f, 0.94f, 1.0f);
    colorString = ImVec4(0.9f, 0.87f, 0.44f, 1.0f);
    colorNumber = ImVec4(0.68f, 0.51f, 0.82f, 1.0f);
    colorComment = ImVec4(0.45f, 0.52f, 0.45f, 1.0f);
    colorOperator = ImVec4(0.98f, 0.45f, 0.45f, 1.0f);
    colorIdentifier = ImVec4(0.85f, 0.85f, 0.85f, 1.0f);
    colorError = ImVec4(1.0f, 0.3f, 0.3f, 1.0f);
    colorLineNumber = ImVec4(0.5f, 0.5f, 0.5f, 1.0f);
    colorBackground = ImVec4(0.15f, 0.15f, 0.15f, 1.0f);

    auto lang = TextEditor::LanguageDefinition::Lua();
    editor.SetLanguageDefinition(lang);
    editor.SetPalette(TextEditor::GetDarkPalette());
    editor.SetShowWhitespaces(false); // Removes whitespace indicators
    editor.SetReadOnly(false);
}

ScriptEditorWindow::~ScriptEditorWindow()
{
    openTabs.clear();
}

void ScriptEditorWindow::InitializeLuaKeywords()
{
    luaKeywords = {
        "and", "break", "do", "else", "elseif", "end", "false",
        "for", "function", "if", "in", "local", "nil", "not",
        "or", "repeat", "return", "then", "true", "until", "while"
    };

    luaBuiltinFunctions = {
        "print", "type", "tonumber", "tostring", "pairs", "ipairs",
        "next", "select", "table", "string", "math",
        "assert", "error", "pcall", "xpcall", "require",
        "setmetatable", "getmetatable",
        "Start", "Update", "Engine", "Input", "Time"
    };
}

ScriptTab* ScriptEditorWindow::GetActiveTab()
{
    if (activeTabIndex >= 0 && activeTabIndex < static_cast<int>(openTabs.size()))
    {
        return &openTabs[activeTabIndex];
    }
    return nullptr;
}

int ScriptEditorWindow::FindTabByPath(const std::string& path) const
{
    for (size_t i = 0; i < openTabs.size(); ++i)
    {
        if (openTabs[i].filePath == path)
        {
            return static_cast<int>(i);
        }
    }
    return -1;
}

void ScriptEditorWindow::Draw()
{
    if (!isOpen) return;

    ImGui::SetNextWindowSizeConstraints(ImVec2(800, 600), ImVec2(FLT_MAX, FLT_MAX));

    if (ImGui::Begin(name.c_str(), &isOpen, ImGuiWindowFlags_MenuBar))
    {
        DrawMenuBar();

        if (!openTabs.empty())
        {
            DrawTabs();

            if (showSearchReplace)
            {
                ImGui::Separator();
                ImGui::Text("Search:");
                ImGui::SameLine();
                ImGui::SetNextItemWidth(200);
                ImGui::InputText("##search", searchText, sizeof(searchText));

                ImGui::SameLine();
                ImGui::Text("Replace:");
                ImGui::SameLine();
                ImGui::SetNextItemWidth(200);
                ImGui::InputText("##replace", replaceText, sizeof(replaceText));

                ImGui::SameLine();
                if (ImGui::Button("Replace All"))
                {
                    ScriptTab* tab = GetActiveTab();
                    if (tab && tab->textBuffer)
                    {
                        std::string content = tab->textBuffer;
                        std::string search = searchText;
                        std::string replace = replaceText;

                        size_t pos = 0;
                        int count = 0;
                        while ((pos = content.find(search, pos)) != std::string::npos)
                        {
                            content.replace(pos, search.length(), replace);
                            pos += replace.length();
                            count++;
                        }

                        strncpy_s(tab->textBuffer, bufferSize, content.c_str(), _TRUNCATE);
                        MarkCurrentTabAsModified();
                    }
                }

                ImGui::Separator();
            }

            DrawTextEditor();

            ScriptTab* tab = GetActiveTab();
            
            if (tab && !tab->syntaxErrors.empty())
            {
                DrawErrorPanel();
            }

            DrawStatusBar();
        }
        else
        {
			// Message when no scripts are open
            ImVec2 center = ImGui::GetContentRegionAvail();
            ImGui::SetCursorPosY(center.y / 2);

            const char* msg = "No scripts open";
            float textWidth = ImGui::CalcTextSize(msg).x;
            ImGui::SetCursorPosX((ImGui::GetContentRegionAvail().x - textWidth) / 2);
            ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "%s", msg);

            const char* hint = "Double-click a .lua file in Assets to open it";
            textWidth = ImGui::CalcTextSize(hint).x;
            ImGui::SetCursorPosX((ImGui::GetContentRegionAvail().x - textWidth) / 2);
            ImGui::TextColored(ImVec4(0.4f, 0.4f, 0.4f, 1.0f), "%s", hint);
        }
    }
    ImGui::End();

	// Popup to confirm tab closure with unsaved changes
    if (tabPendingClose >= 0)
    {
        ImGui::OpenPopup("Close Tab?##ScriptEditor");
    }

    if (ImGui::BeginPopupModal("Close Tab?##ScriptEditor", nullptr, ImGuiWindowFlags_AlwaysAutoResize))
    {
        if (tabPendingClose >= 0 && tabPendingClose < static_cast<int>(openTabs.size()))
        {
            ImGui::Text("'%s' has unsaved changes!", openTabs[tabPendingClose].fileName.c_str());
            ImGui::Text("Do you want to save before closing?");
            ImGui::Separator();

            if (ImGui::Button("Save", ImVec2(100, 0)))
            {
                SaveTab(tabPendingClose);
                CloseTab(tabPendingClose);
                tabPendingClose = -1;
                ImGui::CloseCurrentPopup();
            }

            ImGui::SameLine();

            if (ImGui::Button("Don't Save", ImVec2(100, 0)))
            {
                CloseTab(tabPendingClose);
                tabPendingClose = -1;
                ImGui::CloseCurrentPopup();
            }

            ImGui::SameLine();

            if (ImGui::Button("Cancel", ImVec2(100, 0)))
            {
                tabPendingClose = -1;
                ImGui::CloseCurrentPopup();
            }
        }
        else
        {
            tabPendingClose = -1;
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }

	// Manage popup for unsaved changes when closing the entire window
    if (!isOpen && HasUnsavedChanges())
    {
        ImGui::OpenPopup("Unsaved Changes##ScriptEditorWindow");
        isOpen = true;
    }

    if (ImGui::BeginPopupModal("Unsaved Changes##ScriptEditorWindow", nullptr, ImGuiWindowFlags_AlwaysAutoResize))
    {
        ImGui::Text("You have unsaved changes in one or more scripts!");
        ImGui::Text("Do you want to save all before closing?");
        ImGui::Separator();

        if (ImGui::Button("Save All", ImVec2(120, 0)))
        {
            for (size_t i = 0; i < openTabs.size(); ++i)
            {
                if (openTabs[i].hasUnsavedChanges)
                {
                    SaveTab(static_cast<int>(i));
                }
            }
            isOpen = false;
            ImGui::CloseCurrentPopup();
        }

        ImGui::SameLine();

        if (ImGui::Button("Discard All", ImVec2(120, 0)))
        {
            for (auto& tab : openTabs)
            {
                tab.hasUnsavedChanges = false;
            }
            isOpen = false;
            ImGui::CloseCurrentPopup();
        }

        ImGui::SameLine();

        if (ImGui::Button("Cancel", ImVec2(120, 0)))
        {
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }
}

void ScriptEditorWindow::DrawTabs()
{
    ImGuiTabBarFlags tabBarFlags = ImGuiTabBarFlags_Reorderable |
                                    ImGuiTabBarFlags_AutoSelectNewTabs |
                                    ImGuiTabBarFlags_FittingPolicyScroll;

	// Tab colors
    ImGui::PushStyleColor(ImGuiCol_TabActive, ImVec4(0.5f, 0.2f, 0.7f, 1.0f));           // Purple
	ImGui::PushStyleColor(ImGuiCol_TabHovered, ImVec4(0.6f, 0.3f, 0.8f, 1.0f));          // Light purple
    ImGui::PushStyleColor(ImGuiCol_Tab, ImVec4(0.25f, 0.25f, 0.3f, 1.0f));               // Gray
    ImGui::PushStyleColor(ImGuiCol_TabUnfocusedActive, ImVec4(0.4f, 0.15f, 0.55f, 1.0f)); // Dark purple

    if (ImGui::BeginTabBar("ScriptTabs", tabBarFlags))
    {
        for (int i = 0; i < static_cast<int>(openTabs.size()); ++i)
        {
            ScriptTab& tab = openTabs[i];

			// Add * if there are unsaved changes
            std::string tabName = tab.fileName;
            if (tab.hasUnsavedChanges)
            {
                tabName += " *";
            }
            tabName += "##" + std::to_string(i);  

            bool tabOpen = true;

			// BeginTabItem returns true if the tab is selected
            if (ImGui::BeginTabItem(tabName.c_str(), &tabOpen))
            {
				// Update active tab index
                if (activeTabIndex != i)
                {
                    activeTabIndex = i;
                    //ParseTextIntoLinesForTab(tab);

                    //Update text to edit
                    editor.SetText(tab.originalContent);
                }
                ImGui::EndTabItem();
            }

            // Click on X
            if (!tabOpen)
            {
                if (tab.hasUnsavedChanges)
                {
					// Show popup to confirm
                    tabPendingClose = i;
                }
                else
                {
                    CloseTab(i);
					--i;  // Adjust index after closing
                }
            }
        }

        ImGui::EndTabBar();
    }

    ImGui::PopStyleColor(4);
}

void ScriptEditorWindow::DrawMenuBar()
{
    if (ImGui::BeginMenuBar())
    {
        if (ImGui::BeginMenu("File"))
        {
            ScriptTab* tab = GetActiveTab();
            bool hasActiveTab = (tab != nullptr);

            if (ImGui::MenuItem("Save", "Ctrl+S", false, hasActiveTab))
            {
                SaveScript();
            }

            if (ImGui::MenuItem("Save All", "Ctrl+Shift+S", false, !openTabs.empty()))
            {
                for (size_t i = 0; i < openTabs.size(); ++i)
                {
                    SaveTab(static_cast<int>(i));
                }
            }

            ImGui::Separator();

            if (ImGui::MenuItem("Close Tab", "Ctrl+W", false, hasActiveTab))
            {
                if (tab->hasUnsavedChanges)
                {
                    tabPendingClose = activeTabIndex;
                }
                else
                {
                    CloseTab(activeTabIndex);
                }
            }

            if (ImGui::MenuItem("Close All", nullptr, false, !openTabs.empty()))
            {
				// Close all tabs and check for unsaved changes
                bool hasChanges = HasUnsavedChanges();
                if (hasChanges)
                {
                    isOpen = false;
                }
                else
                {
                    openTabs.clear();
                    activeTabIndex = -1;
                }
            }

            ImGui::Separator();

            if (ImGui::MenuItem("Close Window"))
            {
                isOpen = false;
            }

            ImGui::EndMenu();
        }

        if (ImGui::BeginMenu("Edit"))
        {
            if (ImGui::MenuItem("Find & Replace", "Ctrl+F"))
            {
                showSearchReplace = !showSearchReplace;
            }

            ImGui::Separator();

            ImGui::MenuItem("Line Numbers", nullptr, &showLineNumbers);
            ImGui::MenuItem("Syntax Highlighting", nullptr, &enableSyntaxHighlighting);
            ImGui::MenuItem("Auto Check Syntax", nullptr, &autoCheckSyntax);

            ImGui::EndMenu();
        }

        if (ImGui::BeginMenu("View"))
        {
            ImGui::SliderFloat("Font Size", &fontSize, 10.0f, 24.0f, "%.0f");
            ImGui::EndMenu();
        }

        if (ImGui::BeginMenu("Tools"))
        {
            if (ImGui::MenuItem("Check Syntax Now", nullptr, false, GetActiveTab() != nullptr))
            {
                CheckSyntaxErrors();
            }

            ImGui::EndMenu();
        }

        ImGui::EndMenuBar();
    }

	// Keyword shortcuts
    if (ImGui::IsKeyDown(ImGuiKey_LeftCtrl) || ImGui::IsKeyDown(ImGuiKey_RightCtrl))
    {
        if (ImGui::IsKeyPressed(ImGuiKey_S))
        {
            if (ImGui::IsKeyDown(ImGuiKey_LeftShift) || ImGui::IsKeyDown(ImGuiKey_RightShift))
            {
                // Ctrl+Shift+S: Save All
                for (size_t i = 0; i < openTabs.size(); ++i)
                {
                    SaveTab(static_cast<int>(i));
                }
            }
            else
            {
                // Ctrl+S: Save current
                SaveScript();
            }
        }

        if (ImGui::IsKeyPressed(ImGuiKey_W))
        {
            ScriptTab* tab = GetActiveTab();
            if (tab)
            {
                if (tab->hasUnsavedChanges)
                {
                    tabPendingClose = activeTabIndex;
                }
                else
                {
                    CloseTab(activeTabIndex);
                }
            }
        }

        if (ImGui::IsKeyPressed(ImGuiKey_F))
        {
            showSearchReplace = !showSearchReplace;
        }

        if (ImGui::IsKeyPressed(ImGuiKey_H))
        {
            enableSyntaxHighlighting = !enableSyntaxHighlighting;
            LOG_CONSOLE("[ScriptEditor] Syntax highlighting: %s",
                enableSyntaxHighlighting ? "ON" : "OFF");
        }
    }
}

void ScriptEditorWindow::DrawTextEditor()
{
    ScriptTab* tab = GetActiveTab();
    if (!tab || !tab->textBuffer) return;

    ParseTextIntoLinesForTab(*tab);

    float lineNumberWidth = showLineNumbers ? 60.0f : 0.0f;
    ImVec2 editorSize = ImGui::GetContentRegionAvail();
    editorSize.y -= (!tab->syntaxErrors.empty() ? 80.0f : 20.0f);

    if (enableSyntaxHighlighting)
    {
        DrawColoredReadOnlyView(editorSize, lineNumberWidth);
    }
    else
    {   //Old text editor
        //DrawEditableView(editorSize, lineNumberWidth);
        //Show posible errors
        if (showErrorPopup) {
            ImGui::BeginChild("ErrorConsole", ImVec2(0, 60), true);
            ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.4f, 0.4f, 1.0f));

            ImGui::BulletText("LUA ERROR:");
            ImGui::SameLine();
            if (ImGui::SmallButton("Clear")) {
                showErrorPopup = false;
                editor.SetErrorMarkers(TextEditor::ErrorMarkers());
            }

            ImGui::TextWrapped("%s", errorMessage.c_str());

            ImGui::PopStyleColor();
            ImGui::EndChild();
            ImGui::Separator();
        }
        //New text editor
        editor.Render("TextEditorInstance");
    }
}
int ScriptEditorWindow::ExtractLineFromError(const std::string& error) {
    size_t firstColon = error.find(':');
    if (firstColon != std::string::npos) {
        size_t secondColon = error.find(':', firstColon + 1);
        if (secondColon != std::string::npos) {
            std::string lineStr = error.substr(firstColon + 1, secondColon - firstColon - 1);
            try {
                return std::stoi(lineStr);
            }
            catch (...) { return -1; }
        }
    }
    return -1;
}
void ScriptEditorWindow::DrawColoredReadOnlyView(ImVec2 editorSize, float lineNumberWidth)
{
    ScriptTab* tab = GetActiveTab();
    if (!tab) return;

    ImGui::BeginChild("ColoredEditor", editorSize, true);

    ImDrawList* drawList = ImGui::GetWindowDrawList();
    ImVec2 screenPos = ImGui::GetCursorScreenPos();
    float lineHeight = ImGui::GetTextLineHeight();

    // Background
    drawList->AddRectFilled(screenPos,
        ImVec2(screenPos.x + editorSize.x, screenPos.y + editorSize.y),
        ImGui::ColorConvertFloat4ToU32(colorBackground));

    // Line numbers background
    if (showLineNumbers)
    {
        drawList->AddRectFilled(screenPos,
            ImVec2(screenPos.x + lineNumberWidth, screenPos.y + editorSize.y),
            ImGui::ColorConvertFloat4ToU32(ImVec4(0.1f, 0.1f, 0.1f, 1.0f)));

        drawList->AddLine(
            ImVec2(screenPos.x + lineNumberWidth, screenPos.y),
            ImVec2(screenPos.x + lineNumberWidth, screenPos.y + editorSize.y),
            ImGui::ColorConvertFloat4ToU32(ImVec4(0.3f, 0.3f, 0.3f, 1.0f)), 2.0f);
    }

    // Render lines
    float scrollY = ImGui::GetScrollY();
    int firstLine = static_cast<int>(scrollY / lineHeight);
    int lastLine = firstLine + static_cast<int>(editorSize.y / lineHeight) + 2;

    for (int i = firstLine; i < lastLine && i < static_cast<int>(tab->lines.size()); ++i)
    {
        float yPos = screenPos.y + (i * lineHeight) - scrollY;

        // Line number
        if (showLineNumbers)
        {
            char lineNum[16];
            snprintf(lineNum, sizeof(lineNum), "%4d", i + 1);
            ImVec4 numColor = tab->lines[i].hasError ? colorError : colorLineNumber;

            drawList->AddText(ImVec2(screenPos.x + 10, yPos),
                ImGui::ColorConvertFloat4ToU32(numColor), lineNum);
        }

        // Colored text
        RenderTextWithSyntaxHighlighting(tab->lines[i].content, i,
            ImVec2(screenPos.x + lineNumberWidth + 10, yPos));
    }

    // Dummy for scrolling
    ImGui::Dummy(ImVec2(1000.0f, tab->lines.size() * lineHeight));

    // Double-click to edit
    if (ImGui::IsWindowHovered() && ImGui::IsMouseDoubleClicked(0))
    {
        enableSyntaxHighlighting = false;
        LOG_CONSOLE("[ScriptEditor] Edit mode");
    }

    ImGui::EndChild();

    ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f),
        "Double-click to edit | Ctrl+H to toggle highlighting");
}

void ScriptEditorWindow::DrawEditableView(ImVec2 editorSize, float lineNumberWidth)
{
    ScriptTab* tab = GetActiveTab();
    if (!tab || !tab->textBuffer) return;

    ImGui::BeginChild("EditableEditor", editorSize, true);

    ImVec2 framePadding = ImGui::GetStyle().FramePadding;

    if (showLineNumbers)
    {
        ImGui::BeginChild("LineNums", ImVec2(lineNumberWidth, 0), false, ImGuiWindowFlags_NoScrollbar);
        ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.1f, 0.1f, 0.1f, 1.0f));

        ImGui::SetCursorPosY(ImGui::GetCursorPosY() + framePadding.y);

        ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(0, 0));

        for (size_t i = 0; i < tab->lines.size(); ++i)
        {
            ImVec4 numColor = tab->lines[i].hasError ? colorError : colorLineNumber;
            ImGui::TextColored(numColor, "%4zu", i + 1);
        }

        ImGui::PopStyleVar();
        ImGui::PopStyleColor();
        ImGui::EndChild();
        ImGui::SameLine();
    }

    ImGui::BeginChild("TextArea", ImVec2(0, 0), false);

    ImGui::PushStyleColor(ImGuiCol_FrameBg, colorBackground);

    bool textChanged = ImGui::InputTextMultiline(
        "##text",
        tab->textBuffer,
        bufferSize,
        ImVec2(-1, -1),
        ImGuiInputTextFlags_AllowTabInput | ImGuiInputTextFlags_CallbackAlways,
        [](ImGuiInputTextCallbackData* data) -> int {
            ScriptEditorWindow* editor = (ScriptEditorWindow*)data->UserData;
            editor->MarkCurrentTabAsModified();
            return 0;
        },
        this
    );

    ImGui::PopStyleColor();

    if (textChanged && autoCheckSyntax)
    {
        CheckSyntaxErrors();
    }

    ImGui::EndChild();
    ImGui::EndChild();

    ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f),
        "Ctrl+H to enable syntax highlighting");
}

void ScriptEditorWindow::DrawLineNumbers()
{

}

void ScriptEditorWindow::DrawErrorPanel()
{
    ScriptTab* tab = GetActiveTab();
    if (!tab) return;

    ImGui::Separator();

    if (ImGui::BeginChild("ErrorPanel", ImVec2(0, 60), true))
    {
        ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Syntax Errors:");
        ImGui::Separator();

        for (const auto& error : tab->syntaxErrors)
        {
            ImGui::TextColored(colorError, "Line %d: %s", error.lineNumber, error.message.c_str());
        }
    }
    ImGui::EndChild();
}

void ScriptEditorWindow::DrawStatusBar()
{
    ScriptTab* tab = GetActiveTab();
    if (!tab) return;

    ImGui::Separator();

    std::string status = tab->filePath;

    if (tab->hasUnsavedChanges)
    {
        status += " *";
    }

    ImGui::Text("%s", status.c_str());

    ImGui::SameLine(ImGui::GetWindowWidth() - 400);

	// Show number of open tabs
    ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "[%zu tabs]", openTabs.size());
    ImGui::SameLine();

    if (enableSyntaxHighlighting)
    {
        ImGui::TextColored(ImVec4(0.4f, 0.85f, 0.94f, 1.0f), "[VIEW]");
    }
    else
    {
        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "[EDIT]");
    }

    ImGui::SameLine();

    if (!tab->syntaxErrors.empty())
    {
        ImGui::TextColored(colorError, "%zu error(s)", tab->syntaxErrors.size());
        ImGui::SameLine();
    }
    else if (!tab->filePath.empty())
    {
        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "OK");
        ImGui::SameLine();
    }

    ImGui::Text("Lines: %zu", tab->lines.size());
}

void ScriptEditorWindow::RenderTextWithSyntaxHighlighting(const std::string& text, int lineNumber, ImVec2 startPos)
{
    ImDrawList* drawList = ImGui::GetWindowDrawList();

    std::string currentToken;
    bool inString = false;
    bool inComment = false;
    char stringChar = '\0';
    float currentX = startPos.x;

    auto flushToken = [&]() {
        if (currentToken.empty()) return;

        ScriptTokenType type = ScriptTokenType::IDENTIFIER;

        if (inComment)
            type = ScriptTokenType::COMMENT;
        else if (inString)
            type = ScriptTokenType::STRING;
        else
            type = IdentifyToken(currentToken);

        ImVec4 color = GetColorForToken(type);

        drawList->AddText(
            ImVec2(currentX, startPos.y),
            ImGui::ColorConvertFloat4ToU32(color),
            currentToken.c_str()
        );

        currentX += ImGui::CalcTextSize(currentToken.c_str()).x;
        currentToken.clear();
        };

    for (size_t i = 0; i < text.length(); ++i)
    {
        char c = text[i];
        char nextC = (i + 1 < text.length()) ? text[i + 1] : '\0';

        if (!inString && c == '-' && nextC == '-')
        {
            flushToken();
            inComment = true;
            currentToken += c;
            continue;
        }

        if (!inComment && (c == '"' || c == '\''))
        {
            if (!inString)
            {
                flushToken();
                inString = true;
                stringChar = c;
                currentToken += c;
            }
            else if (c == stringChar)
            {
                currentToken += c;
                flushToken();
                inString = false;
                stringChar = '\0';
            }
            else
            {
                currentToken += c;
            }
            continue;
        }

        if (inString || inComment)
        {
            currentToken += c;
            continue;
        }

        if (std::isspace(c) || c == '(' || c == ')' || c == '{' || c == '}' ||
            c == '[' || c == ']' || c == ',' || c == ';' || c == ':' ||
            c == '+' || c == '-' || c == '*' || c == '/' || c == '=' ||
            c == '<' || c == '>' || c == '~' || c == '.')
        {
            flushToken();

            if (!std::isspace(c))
            {
                currentToken += c;
                flushToken();
            }
            else
            {
                currentX += ImGui::CalcTextSize(" ").x;
            }
        }
        else
        {
            currentToken += c;
        }
    }

    flushToken();
}

ScriptTokenType ScriptEditorWindow::IdentifyToken(const std::string& token)
{
    if (token.empty()) return ScriptTokenType::NONE;

    if (IsLuaKeyword(token)) return ScriptTokenType::KEYWORD;
    if (IsLuaFunction(token)) return ScriptTokenType::FUNCTION;

    bool isNumber = true;
    bool hasDot = false;
    for (size_t i = 0; i < token.size(); ++i)
    {
        char c = token[i];
        if (i == 0 && (c == '-' || c == '+')) continue;
        if (c == '.' && !hasDot) { hasDot = true; continue; }
        if (!std::isdigit(c)) { isNumber = false; break; }
    }
    if (isNumber && token != "-" && token != "+") return ScriptTokenType::NUMBER;

    if (token.length() == 1 && std::ispunct(token[0])) return ScriptTokenType::OPERATOR;

    return ScriptTokenType::IDENTIFIER;
}

bool ScriptEditorWindow::IsLuaKeyword(const std::string& word)
{
    return luaKeywords.find(word) != luaKeywords.end();
}

bool ScriptEditorWindow::IsLuaFunction(const std::string& word)
{
    return luaBuiltinFunctions.find(word) != luaBuiltinFunctions.end();
}

ImVec4 ScriptEditorWindow::GetColorForToken(ScriptTokenType type)
{
    switch (type)
    {
    case ScriptTokenType::KEYWORD:    return colorKeyword;
    case ScriptTokenType::FUNCTION:   return colorFunction;
    case ScriptTokenType::STRING:     return colorString;
    case ScriptTokenType::NUMBER:     return colorNumber;
    case ScriptTokenType::COMMENT:    return colorComment;
    case ScriptTokenType::OPERATOR:   return colorOperator;
    default:                    return colorIdentifier;
    }
}

void ScriptEditorWindow::ParseTextIntoLines()
{
    ScriptTab* tab = GetActiveTab();
    if (tab)
    {
        ParseTextIntoLinesForTab(*tab);
    }
}

void ScriptEditorWindow::ParseTextIntoLinesForTab(ScriptTab& tab)
{
    tab.lines.clear();

    if (!tab.textBuffer) return;

    std::stringstream ss(tab.textBuffer);
    std::string line;

    while (std::getline(ss, line))
    {
        TextLine textLine;
        textLine.content = line;
        textLine.hasError = false;
        tab.lines.push_back(textLine);
    }

    if (tab.lines.empty())
    {
        TextLine empty;
        empty.content = "";
        empty.hasError = false;
        tab.lines.push_back(empty);
    }
}

void ScriptEditorWindow::CheckSyntaxErrors()
{
    ScriptTab* tab = GetActiveTab();
    if (tab)
    {
        CheckSyntaxErrorsForTab(*tab);
    }
}

void ScriptEditorWindow::CheckSyntaxErrorsForTab(ScriptTab& tab)
{
    tab.syntaxErrors.clear();

    for (auto& line : tab.lines)
    {
        line.hasError = false;
        line.errorMessage.clear();
    }

    if (!tab.textBuffer) return;

    lua_State* L = luaL_newstate();
    if (!L) return;

    int result = luaL_loadstring(L, tab.textBuffer);

    if (result != LUA_OK)
    {
        const char* error = lua_tostring(L, -1);
        std::string errorMsg = error ? error : "Unknown error";

        size_t colonPos = errorMsg.find("]:");
        if (colonPos != std::string::npos)
        {
            size_t lineStart = colonPos + 2;
            size_t lineEnd = errorMsg.find(":", lineStart);

            if (lineEnd != std::string::npos)
            {
                try
                {
                    std::string lineNumStr = errorMsg.substr(lineStart, lineEnd - lineStart);
                    int lineNum = std::stoi(lineNumStr);
                    std::string message = errorMsg.substr(lineEnd + 2);

                    SyntaxError syntaxError;
                    syntaxError.lineNumber = lineNum;
                    syntaxError.message = message;
                    tab.syntaxErrors.push_back(syntaxError);

                    if (lineNum > 0 && lineNum <= static_cast<int>(tab.lines.size()))
                    {
                        tab.lines[lineNum - 1].hasError = true;
                        tab.lines[lineNum - 1].errorMessage = message;
                    }
                }
                catch (...) {}
            }
        }

        lua_pop(L, 1);
    }

    lua_close(L);
}

void ScriptEditorWindow::OpenScript(const std::string& scriptPath)
{
	// Check if already open
    int existingIndex = FindTabByPath(scriptPath);
    if (existingIndex >= 0)
    {
		// Activate existing tab
        activeTabIndex = existingIndex;
        isOpen = true;
        return;
    }

	// Create new tab
    ScriptTab newTab;

    if (LoadScriptIntoTab(newTab, scriptPath))
    {
        openTabs.push_back(std::move(newTab));
        activeTabIndex = static_cast<int>(openTabs.size()) - 1;
        isOpen = true;

        ScriptTab& tab = openTabs[activeTabIndex];
        ParseTextIntoLinesForTab(tab);

        if (autoCheckSyntax)
        {
            CheckSyntaxErrorsForTab(tab);
        }
        editor.SetText(tab.originalContent);

    }
}

bool ScriptEditorWindow::LoadScriptIntoTab(ScriptTab& tab, const std::string& path)
{
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) return false;

    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string content = buffer.str();
    file.close();

	// Remove BOM if present
    if (content.size() >= 3 &&
        (unsigned char)content[0] == 0xEF &&
        (unsigned char)content[1] == 0xBB &&
        (unsigned char)content[2] == 0xBF)
    {
        content = content.substr(3);
    }

	// Config tab
    tab.filePath = path;
    tab.fileName = std::filesystem::path(path).filename().string();
    tab.originalContent = content;
    tab.hasUnsavedChanges = false;

	// Create buffer
    tab.textBuffer = new char[bufferSize];
    memset(tab.textBuffer, 0, bufferSize);
    strncpy_s(tab.textBuffer, bufferSize, content.c_str(), _TRUNCATE);
    return true;
}

bool ScriptEditorWindow::SaveScript()
{
    return SaveTab(activeTabIndex);
}

bool ScriptEditorWindow::SaveTab(int tabIndex)
{
    if (tabIndex < 0 || tabIndex >= static_cast<int>(openTabs.size()))
        return false;

    std::string textToSave = editor.GetText();
    lua_State* tempL = luaL_newstate();

    //Check if script have errors
    if (luaL_loadstring(tempL, textToSave.c_str()) != LUA_OK)
    {
        const char* err = lua_tostring(tempL, -1);
        errorMessage = err ? err : "Unknown syntax error";
        showErrorPopup = true;

        LOG_CONSOLE("[LUA SYNTAX ERROR] %s", errorMessage.c_str());

        int reportLine = ExtractLineFromError(errorMessage);
        if (reportLine != -1) {
            TextEditor::ErrorMarkers markers;

            auto allLines = editor.GetTextLines();
            int realErrorLine = reportLine;
            int check = reportLine - 2;
            while (check >= 0) {
                std::string content = allLines[check];
                content.erase(std::remove_if(content.begin(), content.end(), isspace), content.end());

                if (!content.empty()) {
                    realErrorLine = check + 1;
                    break;
                }
                check--;
            }

            markers.insert(std::make_pair(realErrorLine, errorMessage));
            editor.SetErrorMarkers(markers);
        }

        lua_close(tempL);
    }
    else {
        showErrorPopup = false;
        errorMessage.clear();
        editor.SetErrorMarkers(TextEditor::ErrorMarkers()); // Clear previous markers
    }

    ScriptTab& tab = openTabs[tabIndex];

    if (tab.filePath.empty() || !tab.textBuffer)
        return false;

    std::ofstream file(tab.filePath, std::ios::binary);
    if (!file.is_open()) return false;

    // Change tab for editor
    file << editor.GetText();
    file.close();

    tab.originalContent = editor.GetText();
    tab.hasUnsavedChanges = false;

    LOG_CONSOLE("[ScriptEditor] Saved: %s", tab.filePath.c_str());

    if (autoCheckSyntax)
    {
        CheckSyntaxErrorsForTab(tab);
    }

    return true;
}

void ScriptEditorWindow::CloseTab(int tabIndex)
{
    if (tabIndex < 0 || tabIndex >= static_cast<int>(openTabs.size()))
        return;

    openTabs.erase(openTabs.begin() + tabIndex);

	// Adjust active tab index
    if (openTabs.empty())
    {
        activeTabIndex = -1;
    }
    else if (activeTabIndex >= static_cast<int>(openTabs.size()))
    {
        activeTabIndex = static_cast<int>(openTabs.size()) - 1;
    }
    else if (activeTabIndex > tabIndex)
    {
        activeTabIndex--;
    }
}

bool ScriptEditorWindow::HasUnsavedChanges() const
{
    for (const auto& tab : openTabs)
    {
        if (tab.hasUnsavedChanges)
            return true;
    }
    return false;
}

void ScriptEditorWindow::MarkCurrentTabAsModified()
{
    ScriptTab* tab = GetActiveTab();
    if (tab && tab->textBuffer)
    {
        if (strcmp(tab->textBuffer, tab->originalContent.c_str()) != 0)
        {
            tab->hasUnsavedChanges = true;
        }
    }
}
