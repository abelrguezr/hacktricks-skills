-- Extract WhatsApp attachments from ChatStorage.sqlite
-- Usage: sqlite3 ChatStorage.sqlite < extract_whatsapp_attachments.sql
-- Output: CSV with media paths, dates, and message direction

.mode csv
.headers on

SELECT
    m.Z_PK AS message_pk,
    mi.ZMEDIALOCALPATH AS media_path,
    mi.ZMEDIATYPE AS media_type,
    mi.ZMEDIAFILENAME AS media_filename,
    mi.ZMEDIAWIDTH AS width,
    mi.ZMEDIAHEIGHT AS height,
    datetime(m.ZMESSAGEDATE + 978307200, 'unixepoch') AS message_date,
    CASE m.ZISFROMME WHEN 1 THEN 'outgoing' ELSE 'incoming' END AS direction,
    m.ZTEXT AS message_text,
    h.ZWAADDRESS AS contact_address,
    h.ZWAFIRSTNAME AS contact_first_name,
    h.ZWALASTNAME AS contact_last_name
FROM ZWAMESSAGE m
LEFT JOIN ZWAMEDIAITEM mi ON mi.Z_PK = m.ZMEDIAITEM
LEFT JOIN ZWACHATCONTACTS zcc ON zcc.Z_PK = m.ZCHAT
LEFT JOIN ZWAPARTICIPANT zp ON zp.Z_PK = zcc.ZPARTICIPANT
LEFT JOIN ZWACONTACT h ON h.Z_PK = zp.ZCONTACT
WHERE mi.ZMEDIALOCALPATH IS NOT NULL
ORDER BY m.ZMESSAGEDATE DESC;

-- Alternative: List all media items regardless of message linkage
-- SELECT
--     mi.Z_PK AS media_pk,
--     mi.ZMEDIALOCALPATH AS media_path,
--     mi.ZMEDIATYPE AS media_type,
--     mi.ZMEDIAFILENAME AS media_filename,
--     mi.ZMEDIAWIDTH AS width,
--     mi.ZMEDIAHEIGHT AS height,
--     mi.ZMEDIAHEIGHT AS duration
-- FROM ZWAMEDIAITEM mi
-- WHERE mi.ZMEDIALOCALPATH IS NOT NULL
-- ORDER BY mi.Z_PK DESC;
