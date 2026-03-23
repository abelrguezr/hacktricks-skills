-- Extract iMessage attachments with message context
-- Usage: sqlite3 sms.db < extract_imessage_attachments.sql
-- Output: CSV with attachment paths, dates, and chat info

.mode csv
.headers on

-- Basic attachment listing with message linkage
SELECT
    m.ROWID AS message_rowid,
    a.ROWID AS attachment_rowid,
    a.filename AS attachment_path,
    a.totalBytes AS file_size_bytes,
    a.uniformTypeIdentifier AS uti,
    datetime(m.date + 978307200, 'unixepoch') AS message_date,
    CASE m.isFromMe WHEN 1 THEN 'outgoing' ELSE 'incoming' END AS direction,
    h.handle AS contact_handle
FROM message m
JOIN message_attachment_join maj ON maj.message_id = m.ROWID
JOIN attachment a ON a.ROWID = maj.attachment_id
LEFT JOIN handle h ON h.ROWID = m.handle_id
ORDER BY m.date DESC;

-- Extended query with chat names (for group chats)
-- Uncomment if you need chat context:
-- SELECT
--     c.display_name AS chat_name,
--     h.handle AS contact_handle,
--     a.filename AS attachment_path,
--     a.totalBytes AS file_size_bytes,
--     datetime(m.date + 978307200, 'unixepoch') AS message_date,
--     CASE m.isFromMe WHEN 1 THEN 'outgoing' ELSE 'incoming' END AS direction
-- FROM chat c
-- JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
-- JOIN message m ON m.ROWID = cmj.message_id
-- JOIN message_attachment_join maj ON maj.message_id = m.ROWID
-- JOIN attachment a ON a.ROWID = maj.attachment_id
-- LEFT JOIN handle h ON h.ROWID = m.handle_id
-- ORDER BY m.date DESC;
