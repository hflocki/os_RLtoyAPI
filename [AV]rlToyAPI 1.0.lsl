//[[AV]rlToyAPI 1.0.lsl
// =============================================================================================================================================
/*
Copyright © 2025 Josch Wolf
==================================================
Dieses Skript sowie alle zugehörigen Teile sind das geistige Eigentum des Autors. Ohne ausdrückliche schriftliche Genehmigung des Autors ist es verboten, das Skript oder Teile davon zu kopieren, zu modifizieren, zu verbreiten, zu dekompilieren oder in irgendeiner Weise zu verändern oder weiterzugeben.
Das Skript unterliegt der **CCreative Commons Attribution-NonCommercial-NoDerivatives 4.0 International Lizenz (CC BY-NC-ND 4.0)**. Diese Lizenz erlaubt die Nutzung des Skripts nur in unveränderter Form und unter Nennung des Urhebers für nicht kommerzielle Nutzung.
Jede unautorisierte Nutzung oder Änderung stellt eine Verletzung des Urheberrechts dar und kann rechtliche Konsequenzen nach sich ziehen.

Weitere Informationen zur Lizenz:  
[https://creativecommons.org/licenses/by-nc-nd/4.0/deed.de](https://creativecommons.org/licenses/by-nc-nd/4.0/deed.de)

Kontakt für Genehmigungen: Josch Wolf - adult-life.de
*/
// Based on : https://github.com/natc0d3s/love_connect

// =============================================================================================================================================
integer NC_LINE = 0;
key AVATAR_UUID;
list PoseData;
string NotecardName = "[AV]pattern";
string LastPose = "";
integer Running = FALSE;
string dev_token = "<your-token-here>";
string api_url = "https://api.lovense-api.com/api/lan/v2/command";
string qr_url = "https://api.lovense-api.com/api/lan/getQrCode";
key qrRequestId;
key comRequestId;
key keyConfigQueryhandle;
key keyConfigUUID;
list gHttpParams = [
    HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/json",
    HTTP_VERIFY_CERT, FALSE
];

// Funktion zum Anfordern des QR-Codes
request_qr(key avatarID) {
    string json = llList2Json(JSON_OBJECT, [
        "token", dev_token,
        "uid", (string)avatarID,
        "uname", llGetUsername(avatarID),
        "v", "2"
    ]);
    
    qrRequestId = llHTTPRequest(qr_url, gHttpParams, json);
}

// Funktion zur Umwandlung des Pattern-Formats
string convertPatternFormat(string patternData) {
    list parts = llParseStringKeepNulls(patternData, ["|"], []);
    integer len = llGetListLength(parts);
    string actions = "";
    integer timeSec = 0;
    
    integer i;
    for (i = 0; i < len; i += 3) {
        string actionType = llList2String(parts, i);
        string intensity = llList2String(parts, i+1);
        string duration = llList2String(parts, i+2);
        
        string action = "";
        if (actionType == "v") { action = "Vibrate:" + intensity; }
        else if (actionType == "b") { action = "Pump:" + intensity; }
        
        if (action != "") {
            actions += action + ",";
        }
        
        if ((integer)duration > timeSec) {
            timeSec = (integer)duration;
        }
    }
    
    if (llSubStringIndex(actions, ",") != -1) {
        actions = llDeleteSubString(actions, -1, -1);
    }
    
    return llList2Json(JSON_OBJECT, [
        "token", dev_token,
        "uid", (string)AVATAR_UUID,
        "command", "Function",
        "action", actions,
        "timeSec", timeSec,
        "apiVer", 1
    ]);
}

send_vibration(string apiCommand) {
    string jsonPayload = convertPatternFormat(apiCommand);
    comRequestId = llHTTPRequest(api_url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"], jsonPayload);
}

vibe_off() {
    string jsonPayload = llList2Json(JSON_OBJECT, [
        "token", dev_token,
        "uid", (string)AVATAR_UUID,
        "command", "Function",
        "action", "Stop",
        "timeSec", 0,
        "apiVer", 1
    ]);
    comRequestId = llHTTPRequest(api_url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"], jsonPayload);
    Running = FALSE;
}

default {
    state_entry() {
        if (llGetInventoryType(NotecardName) == INVENTORY_NONE) {
            return;
        }
        keyConfigQueryhandle = llGetNotecardLine(NotecardName, NC_LINE);
        keyConfigUUID = llGetInventoryKey(NotecardName);
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
    
    dataserver(key keyQueryId, string strData) {
        if (keyQueryId == keyConfigQueryhandle) {
            if (strData == EOF) return;
            keyConfigQueryhandle = llGetNotecardLine(NotecardName, ++NC_LINE);
            strData = llStringTrim(strData, STRING_TRIM_HEAD);
            if (llGetSubString(strData, 0, 0) != "#") {
                PoseData += [strData];
            }
        }
    }
    
    link_message(integer sender, integer num, string msg, key id) {
        if (num == 74355 && msg == "Login") {
           AVATAR_UUID = id;
           request_qr(id);
           }
        
                        
        if (num == 90045) { 
            AVATAR_UUID = id;
            list data = llParseStringKeepNulls(msg, ["|"], []);
            string pose = llList2String(data, 1);
            
            if (pose != LastPose) {
                vibe_off();
                LastPose = pose;
            }
            
            integer found = FALSE;
            integer i;
            for (i = 0; i < llGetListLength(PoseData); i++) {
                list entry = llParseStringKeepNulls(llList2String(PoseData, i), ["|"], []);
                if (llList2String(entry, 0) == pose) {
                    found = TRUE;
                    string apiCommand = llDumpList2String(llList2List(entry, 1, -1), "|");
                    send_vibration(apiCommand);
                    break;
                }
            }
            if (!found) {
                vibe_off();
            }
        }
        if (num == 90065) { 
            vibe_off();
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id == qrRequestId) {
            string qr_url_data = llJsonGetValue(body, ["data", "qr"]);
            llLoadURL(AVATAR_UUID, "[Lovense] Scanne diesen QR-Code für dein Gerät:", qr_url_data);
        }
    }
}
