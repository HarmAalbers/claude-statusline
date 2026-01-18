-- Claude Copy URL Handler
-- Handles claude-copy:// URLs to copy text to clipboard
--
-- URL Format: claude-copy://<type>/<base64-encoded-data>
-- Types:
--   - session: Copy session UUID
--   - path: Copy transcript file path
--
-- The base64 payload is decoded and copied to the system clipboard.
-- A macOS notification provides feedback to the user.

on open location theURL
    try
        -- URL format: claude-copy://type/base64data
        -- theURL arrives as: "claude-copy://session/ABC123=="

        -- Use shell to parse and decode (more reliable than AppleScript string handling)
        set shellScript to "
            URL=" & quoted form of theURL & "
            # Remove scheme
            URL_CONTENT=\"${URL#claude-copy://}\"
            # Extract type (before /)
            TYPE=\"${URL_CONTENT%%/*}\"
            # Extract encoded data (after /)
            ENCODED=\"${URL_CONTENT#*/}\"
            # Decode base64
            DECODED=$(printf '%s' \"$ENCODED\" | base64 -d 2>/dev/null)
            # Output as tab-separated: type<tab>decoded
            printf '%s\\t%s' \"$TYPE\" \"$DECODED\"
        "

        set parseResult to do shell script shellScript

        -- Split result by tab
        set AppleScript's text item delimiters to tab
        set resultParts to text items of parseResult
        set AppleScript's text item delimiters to ""

        if (count of resultParts) < 2 then
            display notification "Failed to parse URL" with title "Claude Copy" subtitle "Error"
            return
        end if

        set copyType to item 1 of resultParts
        set decodedText to item 2 of resultParts

        if decodedText is "" then
            display notification "No data to copy" with title "Claude Copy" subtitle "Error"
            return
        end if

        -- Copy to clipboard using pbcopy
        do shell script "printf '%s' " & quoted form of decodedText & " | pbcopy"

        -- Show notification based on type
        if copyType is "session" then
            -- Truncate for display if too long
            if (length of decodedText) > 20 then
                set displayText to (text 1 thru 8 of decodedText) & "..."
            else
                set displayText to decodedText
            end if
            display notification displayText with title "Session ID Copied" subtitle "Full UUID in clipboard"
        else if copyType is "path" then
            -- Show just filename for path
            set AppleScript's text item delimiters to "/"
            set pathParts to text items of decodedText
            set AppleScript's text item delimiters to ""
            set fileName to last item of pathParts
            display notification fileName with title "Path Copied" subtitle "Full path in clipboard"
        else
            display notification "Copied to clipboard" with title "Claude Copy"
        end if

    on error errMsg
        display notification errMsg with title "Claude Copy" subtitle "Error"
    end try
end open location
